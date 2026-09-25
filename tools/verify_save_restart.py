"""W3: pinned Godot processes, real file reopen and forced termination checks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument("--godot", required=True)
a = p.parse_args()
godot = Path(a.godot).resolve()
provenance = json.loads((ROOT / "tools/engine_provenance.json").read_text(encoding="utf-8-sig"))
# 콘솔 래퍼 대신 실제 엔진 프로세스를 직접 실행해야 PID와 강제 종료 대상이 일치한다.
if godot.name == provenance["engine"]["console_exe_file"]:
    godot = godot.with_name(provenance["engine"]["exe_file"])
engine_hash = hashlib.sha256(godot.read_bytes()).hexdigest()
assert engine_hash in (provenance["engine"]["console_exe_sha256"], provenance["engine"]["exe_sha256"])
flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
version = subprocess.check_output([str(godot), "--version"], creationflags=flags, text=True).strip()
assert version == (ROOT / "engine_version.txt").read_text().strip()
run = ROOT / "tools/out" / ("w3_restart_" + uuid.uuid4().hex[:12])
run.mkdir(parents=True)
results = []
serial = 0

def command(mode, folder, report, extra=()):
    return [str(godot), "--headless", "--path", str(ROOT / "game"), "-s", "res://tests/integration/save_process_probe.gd", "--", mode, str(folder), str(report), *map(str, extra)]

def probe(mode, folder):
    global serial
    serial += 1
    report = run / f"{serial:02d}_{mode}.json"
    completed = subprocess.run(command(mode, folder, report), capture_output=True, timeout=45, creationflags=flags)
    log = completed.stdout.decode("utf-8", errors="replace") + completed.stderr.decode("utf-8", errors="replace")
    (run / f"{serial:02d}_{mode}.log").write_text(log, encoding="utf-8")
    assert completed.returncode == 0 and report.exists(), log
    assert not re.search(r"SCRIPT ERROR:|Parse Error:|^\s*ERROR:", log, re.M), log
    return json.loads(report.read_text(encoding="utf-8"))

def check(name, condition):
    assert condition, name
    results.append({"check": name, "passed": True})
    print("PASS", name, flush=True)

base = run / "baseline"
initial = probe("init", base)
check("initial full state committed", initial["ok"])
before = initial["state_text"]
after = initial["expected_clear_text"]
reopened = probe("inspect", base)
check("fresh process restores exact state", reopened["ok"] and reopened["state_text"] == before and reopened["pid"] != initial["pid"])
app = probe("app_boot", base)
check("actual app scene boots from disk", app["ok"] and app["state_text"] == before)
original_files = {name: (base / name).read_bytes() for name in ("slot_a.json", "slot_b.json")}

def clone(name):
    folder = run / name
    folder.mkdir()
    for filename, data in original_files.items(): (folder / filename).write_bytes(data)
    return folder

for stage in ("before_write", "after_write", "after_verify", "after_preserve", "after_remove_target", "after_publish"):
    folder = clone(stage)
    marker = folder / "stage.json"
    report = folder / "terminated.json"
    log_path = folder / "writer.log"
    with log_path.open("wb") as log:
        process = subprocess.Popen(command("clear", folder, report, (stage, marker)), stdout=log, stderr=subprocess.STDOUT, creationflags=flags)
        try:
            deadline = time.monotonic() + 25
            while not marker.exists():
                if process.poll() is not None: raise AssertionError(log_path.read_text(encoding="utf-8", errors="replace"))
                if time.monotonic() > deadline: raise TimeoutError(stage)
                time.sleep(0.05)
            # Marker is flushed/closed before the child pauses; wait for complete JSON bytes.
            marked = None
            for _ in range(40):
                try:
                    marked = json.loads(marker.read_text())
                    break
                except json.JSONDecodeError: time.sleep(0.025)
            check(stage + ": writer reached checkpoint", marked is not None and marked["pid"] == process.pid)
            if stage == "before_write":
                contender = probe("inspect", folder)
                check("live unrelated process claim is respected", not contender["ok"] and contender["error"] == "SAVE_BUSY")
            process.kill()
            process.wait(timeout=10)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
    recovered = probe("inspect", folder)
    expected = after if stage == "after_publish" else before
    check(stage + ": killed process restores whole generation", recovered["ok"] and recovered["state_text"] == expected)
    if stage == "after_publish":
        duplicate = probe("duplicate", folder)
        check("post-publication restart cannot award clear twice", not duplicate["ok"] and duplicate["error"] == "ALREADY_APPLIED")

cleared = probe("clear", base)
check("normal clear commits expected points floors and queue", cleared["ok"] and cleared["state_text"] == after)
check("another fresh process sees committed clear", probe("inspect", base)["state_text"] == after)
# Latest revision 2 is slot_a; revision 1 remains in slot_b.
corrupt = b"{truncated-latest"
(base / "slot_a.json").write_bytes(corrupt)
restored = probe("inspect", base)
check("corrupt latest falls back with explicit notice", restored["ok"] and restored["recovered"] and restored["state_text"] == before)
check("recovered app scene exposes recovery result", probe("app_boot", base)["recovered"])
check("recovered state can commit again", probe("clear", base)["state_text"] == after)
h = hashlib.sha256(corrupt).hexdigest()
check("damaged original bytes are preserved", (base / "preserved" / f"slot_a.json.{h}.bad").read_bytes() == corrupt)
(base / "slot_a.json").write_bytes(b"bad a")
(base / "slot_b.json").write_bytes(b"bad b")
broken = probe("inspect", base)
check("both corrupt block silent initialization", not broken["ok"] and broken["error"] == "SAVE_CORRUPT" and (base / "slot_a.json").read_bytes() == b"bad a")
app_error = probe("app_boot", base)
check("actual app scene presents save failure path", not app_error["ok"] and app_error["error"] == "SAVE_CORRUPT")

readonly = clone("readonly_pending")
pending = readonly / "pending.json"
pending.write_text("existing pending", encoding="utf-8")
os.chmod(pending, stat.S_IREAD)
try:
    denied = probe("clear", readonly)
    check("real read-only write failure preserves current generation", not denied["ok"] and denied["error"] == "SAVE_WRITE_FAILED" and probe("inspect", readonly)["state_text"] == before)
finally:
    os.chmod(pending, stat.S_IREAD | stat.S_IWRITE)

# A real v1 fixture is decoded in a fresh process without rewriting either
# generation; the next successful action publishes the v2 state atomically.
legacy = run / "legacy_v1_migration"
legacy.mkdir()
fixture = (ROOT / "game/tests/fixtures/save_v1_cleared_cross.json").read_bytes()
(legacy / "slot_a.json").write_bytes(fixture)
(legacy / "slot_b.json").write_bytes(fixture)
v1_before = {name: (legacy / name).read_bytes() for name in ("slot_a.json", "slot_b.json")}
legacy_resume = probe("inspect", legacy)
legacy_state = json.loads(json.loads(legacy_resume["state_text"])["payload"])
check("fresh process migrates strict v1 in memory to v2 with empty parts", legacy_resume["ok"] and legacy_state["schema_version"] == "bt_session_v2" and legacy_state["growth"]["segment_parts"] == {})
check("read-only v1 process resume preserves original bytes in both slots", all((legacy / name).read_bytes() == data for name, data in v1_before.items()))
legacy_action = probe("toggle_auto", legacy)
legacy_state_after = json.loads(json.loads(legacy_action["state_text"])["payload"])
published = [json.loads((legacy / name).read_text(encoding="utf-8")) for name in ("slot_a.json", "slot_b.json")]
published_payloads = [json.loads(entry["payload"]) for entry in published]
check("next process action writes v2 while retaining prior v1 generation", legacy_action["ok"] and legacy_state_after["schema_version"] == "bt_session_v2" and any(p["schema_version"] == "bt_session_v2" and "segment_parts" in p["growth"] for p in published_payloads) and any(p["schema_version"] == "bt_session_v1" for p in published_payloads))

# A separately created real v2 file contains both sorted parts on one brick
# segment. Inspection is read-only; the following action must retain both.
terrace_v2 = run / "terrace_v2_parts"
made_parts = probe("init_terrace_v2", terrace_v2)
check("current v2 fixture commits both sorted brick parts", made_parts["ok"])
v2_files = ("slot_a.json", "slot_b.json")
v2_before = {name: (terrace_v2 / name).read_bytes() for name in v2_files if (terrace_v2 / name).exists()}
v2_resume = probe("inspect", terrace_v2)
check("fresh process resumes existing v2 with both parts", v2_resume["ok"] and json.loads(json.loads(v2_resume["state_text"])['payload'])['growth']['segment_parts'] == {"1":["brick_arch_window","brick_terrace"]})
check("read-only v2 resume preserves every save byte", all((terrace_v2 / name).read_bytes() == data for name,data in v2_before.items()))
v2_action = probe("toggle_auto", terrace_v2)
v2_state_after = json.loads(json.loads(v2_action["state_text"])['payload'])
v2_published = [json.loads((terrace_v2 / name).read_text(encoding="utf-8")) for name in v2_files if (terrace_v2 / name).exists()]
v2_payloads = [json.loads(entry['payload']) for entry in v2_published]
check("first v2 action preserves both sorted parts across generations", v2_action["ok"] and v2_state_after['growth']['segment_parts'] == {"1":["brick_arch_window","brick_terrace"]} and all(payload['growth']['segment_parts'] == {"1":["brick_arch_window","brick_terrace"]} for payload in v2_payloads))

# Cornice extends the existing v2 sparse array without changing the envelope.
cornice_v2 = run / "cornice_v2_parts"
made_cornice = probe("init_cornice_v2", cornice_v2)
check("current v2 fixture commits all three sorted brick parts", made_cornice["ok"])
cornice_files = ("slot_a.json", "slot_b.json")
cornice_before = {name: (cornice_v2 / name).read_bytes() for name in cornice_files if (cornice_v2 / name).exists()}
cornice_resume = probe("inspect", cornice_v2)
cornice_parts = {"20":["brick_arch_window","brick_cornice","brick_terrace"]}
check("fresh process resumes the three-part v2 segment", cornice_resume["ok"] and json.loads(json.loads(cornice_resume["state_text"])['payload'])['growth']['segment_parts'] == cornice_parts)
check("read-only three-part resume preserves every save byte", all((cornice_v2 / name).read_bytes() == data for name,data in cornice_before.items()))
cornice_action = probe("toggle_auto", cornice_v2)
cornice_state_after = json.loads(json.loads(cornice_action["state_text"])['payload'])
cornice_published = [json.loads((cornice_v2 / name).read_text(encoding="utf-8")) for name in cornice_files if (cornice_v2 / name).exists()]
cornice_payloads = [json.loads(entry['payload']) for entry in cornice_published]
check("first action preserves all sorted parts through both generations", cornice_action["ok"] and cornice_state_after['growth']['segment_parts'] == cornice_parts and all(payload['growth']['segment_parts'] == cornice_parts for payload in cornice_payloads))

# A new v2 four-part state must remain byte-stable on read-only resume, then
# survive the first successful action in both generations and another process.
landmark_v2 = run / "landmark_v2_four_parts"
made_landmark = probe("init_landmark_v2", landmark_v2)
landmark_parts = {"1":["brick_arch_window","brick_cornice","brick_landmark","brick_terrace"]}
check("new v2 fixture commits four sorted brick parts", made_landmark["ok"])
landmark_files = ("slot_a.json", "slot_b.json")
landmark_before = {name:(landmark_v2 / name).read_bytes() for name in landmark_files if (landmark_v2 / name).exists()}
landmark_resume = probe("inspect", landmark_v2)
landmark_state = json.loads(json.loads(landmark_resume["state_text"])['payload']) if landmark_resume["ok"] else {}
check("fresh process resumes four-part v2 state", landmark_resume["ok"] and landmark_state.get('growth',{}).get('segment_parts') == landmark_parts and landmark_resume["pid"] != made_landmark["pid"])
check("read-only four-part resume preserves every save byte", all((landmark_v2 / name).read_bytes() == data for name,data in landmark_before.items()))
landmark_action = probe("toggle_auto", landmark_v2)
landmark_state_after = json.loads(json.loads(landmark_action["state_text"])['payload']) if landmark_action["ok"] else {}
landmark_published = [json.loads((landmark_v2 / name).read_text(encoding="utf-8")) for name in landmark_files if (landmark_v2 / name).exists()]
landmark_payloads = [json.loads(entry['payload']) for entry in landmark_published]
check("first successful action preserves all four parts across both generations", landmark_action["ok"] and landmark_state_after.get('growth',{}).get('segment_parts') == landmark_parts and len(landmark_payloads) == 2 and all(payload.get('growth',{}).get('segment_parts') == landmark_parts for payload in landmark_payloads))
landmark_second_resume = probe("inspect", landmark_v2)
check("second fresh process restores four-part state after first write", landmark_second_resume["ok"] and json.loads(json.loads(landmark_second_resume["state_text"])['payload'])['growth']['segment_parts'] == landmark_parts and landmark_second_resume["pid"] != landmark_action["pid"])

report = {"ok": True, "engine": version, "engine_sha256": engine_hash, "directory": str(run), "separate_process_probes": serial,
          "forced_terminations": 6, "checks": results, "scope": "Windows process termination and actual files, not hardware power loss"}
(run / "summary.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "tools/out/w3_restart_latest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print("PASS W3 restart", len(results), "checks; report", run / "summary.json", flush=True)
