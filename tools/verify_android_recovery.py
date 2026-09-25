"""Destructive fault injection ONLY in com.blocktower.recovery.qa; never user app."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import re

ROOT = Path(__file__).resolve().parents[1]
PKG = 'com.blocktower.recovery.qa'
p = argparse.ArgumentParser()
p.add_argument('--adb', required=True)
p.add_argument('--serial', required=True)
p.add_argument('--guard-only', action='store_true')
p.add_argument('--output', help='Evidence directory; defaults to the original W5 evidence location')
a = p.parse_args()
E = Path(a.output).resolve() if a.output else ROOT / 'docs/implementation/w5_recovery_evidence_2026-09-21' / a.serial
E.mkdir(parents=True, exist_ok=True)
results = []
sequence = 0
run_id = str(time.time_ns())
completed = False

def adb(*args, check=True):
    result = subprocess.run([a.adb, '-s', a.serial, *args], capture_output=True, timeout=25)
    if check and result.returncode: raise RuntimeError(result.stderr.decode(errors='replace'))
    return result.stdout

def read(path):
    return adb('exec-out', 'run-as', PKG, 'cat', 'files/' + path, check=False)

def put(path, data):
    local = E / '_transfer'
    local.write_bytes(data if isinstance(data, bytes) else data.encode())
    adb('push', str(local), '/data/local/tmp/blocktower_recovery_qa_transfer')
    adb('shell', 'run-as', PKG, 'cp', '/data/local/tmp/blocktower_recovery_qa_transfer', 'files/' + path)

def stop():
    adb('shell', 'am', 'force-stop', PKG)

def begin(mode, folder, extra=(), stop_before=True):
    global sequence
    if stop_before: stop()
    sequence += 1
    report = f'report_{run_id}_{sequence}.json'
    command = {'args': [mode, 'user://' + folder, 'user://' + report, *extra]}
    put('command.json', json.dumps(command))
    adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    adb('shell', 'wm', 'dismiss-keyguard')
    adb('shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', '-p', PKG)
    return report

def wait_json(path):
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline:
        try:
            result = json.loads(read(path))
            (E / path.replace('/', '_')).write_text(json.dumps(result, indent=2), encoding='utf-8')
            return result
        except (ValueError, UnicodeDecodeError): time.sleep(.2)
    raise TimeoutError(path)

def probe(mode, folder):
    return wait_json(begin(mode, folder))

def check(name, condition):
    assert condition, name
    results.append({'check': name, 'passed': True})
    print('PASS', name, flush=True)

def clone(name):
    folder = f'cases_{run_id}/{name}'
    adb('shell', 'run-as', PKG, 'mkdir', '-p', 'files/' + folder)
    for file, data in original.items(): put(folder + '/' + file, data)
    return folder

def helper_command(folder, mode='try'):
    return [a.adb, '-s', a.serial, 'exec-out', 'run-as', PKG, 'env',
            'CLASSPATH=/data/user/0/' + PKG + '/files/classes.dex', 'app_process',
            '/system/bin', 'RecoveryLockProbe', '/data/user/0/' + PKG + '/files/' + folder + '/.writer.guard', mode]

def external_try(folder):
    result = subprocess.run(helper_command(folder), capture_output=True, timeout=15)
    assert result.returncode == 0, result.stderr
    return result.stdout.decode().strip()

try:
    # run-as can create files before the first launch.
    adb('shell', 'run-as', PKG, 'mkdir', '-p', 'files')
    guard = probe('guard', 'unused')
    check('JNI lock, canonical alias contention, release/reacquire, live/dead errno', guard['ok'])
    if not a.guard_only:
        base = f'cases_{run_id}/baseline'
        initial = probe('init', base)
        check('initial generation committed on Android', initial['ok'])
        before, after = initial['state_text'], initial['expected_clear_text']
        original = {f: read(base + '/' + f) for f in ('slot_a.json', 'slot_b.json')}
        dex = ROOT / 'tools/out/android_recovery_probe/classes.dex'
        adb('shell', 'run-as', PKG, 'chmod', '644', 'files/classes.dex', check=False)
        put('classes.dex', dex.read_bytes())
        adb('shell', 'run-as', PKG, 'chmod', '444', 'files/classes.dex')
        resumed = probe('inspect', base)
        check('fresh Android process restores exact snapshot', resumed['ok'] and resumed['state_text'] == before and resumed['pid'] != initial['pid'])
        for stage in ('before_write', 'after_write', 'after_verify', 'after_preserve', 'after_remove_target', 'after_publish'):
            folder = clone(stage)
            marker = folder + '/marker.json'
            begin('clear', folder, (stage, 'user://' + marker))
            marked = wait_json(marker)
            check(stage + ': real writer reached checkpoint', marked['stage'] == stage)
            if stage == 'before_write':
                check('unrelated Java process cannot acquire active Godot lock', external_try(folder).startswith('BUSY '))
            stop()
            restored = probe('inspect', folder)
            expected = after if stage == 'after_publish' else before
            check(stage + ': force-stop restores exact generation', restored['ok'] and restored['state_text'] == expected and restored['pid'] != marked['pid'])
            if stage != 'after_publish':
                retried = probe('clear', folder)
                check(stage + ': retry applies exact reward once', retried['ok'] and retried['state_text'] == after)
            duplicate = probe('duplicate', folder)
            check(stage + ': duplicate event rejected', not duplicate['ok'] and duplicate['error'] == 'ALREADY_APPLIED')
        folder = clone('external_owner')
        with (E / 'external_owner.txt').open('wb') as log:
            holder = subprocess.Popen(helper_command(folder, 'hold'), stdout=log, stderr=subprocess.STDOUT)
            holder_pid = None
            try:
                deadline = time.monotonic() + 15
                while time.monotonic() < deadline:
                    match = re.search(r'LOCKED (\d+)', (E / 'external_owner.txt').read_text(errors='replace'))
                    if match:
                        holder_pid = match[1]
                        break
                    time.sleep(.1)
                assert holder_pid is not None, 'external holder did not lock'
                blocked = wait_json(begin('inspect', folder, stop_before=False))
                check('Godot respects unrelated live Java writer', not blocked['ok'] and blocked['error'] == 'SAVE_BUSY')
            finally:
                if holder_pid: adb('shell', 'run-as', PKG, 'kill', '-9', holder_pid, check=False)
                holder.wait(timeout=10)
        restored = probe('inspect', folder)
        check('killed unrelated owner releases kernel lock', restored['ok'] and restored['state_text'] == before)
        folder = clone('legacy_dead')
        adb('shell', 'run-as', PKG, 'mkdir', 'files/' + folder + '/.writer_2147483647.lock')
        restored = probe('inspect', folder)
        check('legacy dead PID claim recovers exact state', restored['ok'] and restored['state_text'] == before)
        names = adb('shell', 'run-as', PKG, 'ls', '-a', 'files/' + folder).decode()
        check('legacy dead claim removed; stable guard retained', '.writer_2147483647.lock' not in names and '.writer.guard' in names)
        for name, claim, expected in [('legacy_live', '.writer_1.lock', 'SAVE_BUSY'), ('legacy_invalid', '.writer_invalid.lock', 'SAVE_LOCK_INVALID'), ('legacy_nonempty', '.writer_2147483647.lock', 'SAVE_LOCK_FAILED')]:
            folder = clone(name)
            adb('shell', 'run-as', PKG, 'mkdir', 'files/' + folder + '/' + claim)
            if name == 'legacy_nonempty': put(folder + '/' + claim + '/keep', b'preserve')
            restored = probe('inspect', folder)
            check(name + ': blocks unsafe recovery', not restored['ok'] and restored['error'] == expected)
            check(name + ': committed bytes untouched', all(read(folder + '/' + f) == data for f, data in original.items()))
        folder = clone('corruption')
        committed = probe('clear', folder)
        check('normal clear publishes expected full state', committed['ok'] and committed['state_text'] == after)
        broken = b'{truncated'
        put(folder + '/slot_a.json', broken)
        recovered = probe('inspect', folder)
        check('corrupt latest falls back with recovery metadata', recovered['ok'] and recovered['recovered'] and recovered['state_text'] == before)
        repaired = probe('clear', folder)
        check('recovered state can commit exactly once', repaired['ok'] and repaired['state_text'] == after)
        preserved = folder + '/preserved/slot_a.json.' + hashlib.sha256(broken).hexdigest() + '.bad'
        check('damaged original preserved byte for byte', read(preserved) == broken)
        for file in original: put(folder + '/' + file, broken)
        failed = probe('inspect', folder)
        check('both corrupt fail closed without resetting', not failed['ok'] and failed['error'] == 'SAVE_CORRUPT' and all(read(folder + '/' + f) == broken for f in original))
        folder = clone('future_format')
        future = json.loads(original['slot_b.json'])
        future['format'] = 'bt_save_envelope_v999'
        future_bytes = json.dumps(future).encode()
        put(folder + '/slot_b.json', future_bytes)
        failed = probe('inspect', folder)
        check('unsupported newer format blocks fallback and preserves bytes', not failed['ok'] and failed['error'] == 'UNSUPPORTED_FORMAT' and read(folder + '/slot_b.json') == future_bytes)
        folder = f'cases_{run_id}/pending_only'
        adb('shell', 'run-as', PKG, 'mkdir', '-p', 'files/' + folder)
        put(folder + '/pending.json', after)
        fresh = probe('init', folder)
        check('pending without committed generations is never resumed or rewarded', fresh['ok'] and fresh['state_text'] == before)
    completed = True
finally:
    (E / 'checks.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    (E / 'run.json').write_text(json.dumps({'run_id': run_id, 'serial': a.serial, 'package': PKG,
        'completed': completed, 'checks': len(results), 'apk_sha256': hashlib.sha256((ROOT / 'tools/out/android_recovery_probe/probe.apk').read_bytes()).hexdigest()}, indent=2), encoding='utf-8')
    try:
        stop()
        (E / 'logcat.txt').write_bytes(adb('logcat', '-d', '-s', 'godot:*'))
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        (E / 'connection_failure.txt').write_text(str(error), encoding='utf-8')
    (E / '_transfer').unlink(missing_ok=True)
print(f'{len(results)} Android checks passed')
