"""Run real GDScript against Python set-based oracles in an isolated project.

Usage: python run_preflight.py --godot <4.7.2 console executable>
No engine download, global environment mutation or production game creation.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import random
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOCS = HERE.parent


def read_definitions():
    source = (DOCS / 'examples/piece_supply_v0_1.gd').read_text(encoding='utf-8')
    array = source.split('const FAMILIES := ', 1)[1].split('\n]\n', 1)[0] + '\n]'
    families = json.loads(re.sub(r',\s*([}\]])', r'\1', array))
    catalog = {}
    for family in families:
        for variant, rows in enumerate(family['patterns']):
            catalog[f"{family['id']}_v{variant}"] = {
                'family': family['id'],
                'cells': {(x, y) for y, row in enumerate(rows)
                          for x, char in enumerate(row) if char == '#'}}
    return families, catalog


def fixtures(catalog):
    rng = random.Random(20260920)
    cases = []
    for density in [0, .125, .25, .5, .75, .875, 1]:
        for index in range(24):
            cases.append((f'density_{density}_{index}', [int(rng.random() < density) for _ in range(64)]))
    for axis in ['row', 'column']:
        for index in range(8):
            cases.append((f'full_{axis}_{index}', [int((y if axis == 'row' else x) == index)
                                                  for y in range(8) for x in range(8)]))
    cases.append(('cross', [int(x == 3 or y == 4) for y in range(8) for x in range(8)]))
    cases.append(('checkerboard', [(x + y) % 2 for y in range(8) for x in range(8)]))
    names = list(catalog)
    boards = []
    for name, board in cases:
        free = {(x, y) for y in range(8) for x in range(8) if board[y * 8 + x] == 0}
        masks = {pid: ''.join('1' if {(x+dx, y+dy) for dx, dy in piece['cells']} <= free else '0'
                             for y in range(-1, 9) for x in range(-1, 9))
                 for pid, piece in catalog.items()}
        pending = sum(all(board[y*8+x] for x in range(8)) for y in range(8))
        pending += sum(all(board[y*8+x] for y in range(8)) for x in range(8))
        trays = []
        options = [[], ['single_v0'], ['square3_v0'] * 3, ['single_v0', 'invalid'], names[:4]]
        options += [[rng.choice(names) for _ in range(rng.randint(1, 3))] for _ in range(8)]
        for ids in options:
            if any(pid not in catalog for pid in ids) or len(ids) > 3:
                status = 'INVALID_INPUT'
            elif not ids:
                status = 'REFILL_REQUIRED'
            elif any('1' in masks[pid] for pid in ids):
                status = 'CAN_PLACE'
            else:
                status = 'MUST_CLEAR' if pending else 'GAME_OVER'
            trays.append({'ids': ids, 'status': status})
        boards.append({'name': name, 'board': board, 'masks': masks, 'pending': pending, 'trays': trays})
    seeds = ['0', '1', '-1', '11', '37', '101', '2026', '20260920',
             '9223372036854775807', '-9223372036854775808']
    seeds += [str(rng.randrange(1, 2**63)) for _ in range(10)]
    return {'boards': boards, 'invalid_boards': [[], [0]*63, [0]*65, [2]+[0]*63],
            'seeds': seeds, 'batches_per_seed': 2500, 'play_stream_length': 2048,
            'play_seeds': ['11', '37', '101', '2026', '20260920']}


def run(executable, arguments, timeout=180):
    result = subprocess.run([str(executable), *map(str, arguments)], capture_output=True,
                            text=True, encoding='utf-8', timeout=timeout)
    if result.returncode != 0 or result.stderr.strip():
        raise RuntimeError(f'Godot failed ({result.returncode})\n{result.stdout}\n{result.stderr}')
    return result.stdout


def distribution_report(samples, families, catalog):
    report = {}
    failed = []
    for policy, sample in samples.items():
        uniform = policy == 'bt_id_uniform_v0_1'
        probs = {pid: (1/len(catalog) if uniform else next(f['weight']/100/len(f['patterns'])
                 for f in families if f['id'] == piece['family'])) for pid, piece in catalog.items()}
        tests = []
        for slot, counts in [('all', sample['counts']), *list(enumerate(sample['slot_counts']))]:
            n = sample['batches'] * (3 if slot == 'all' else 1)
            for pid, p in probs.items():
                observed = counts[pid]
                z = abs(observed - n*p) / math.sqrt(n*p*(1-p))
                tests.append({'slot': slot, 'id': pid, 'observed': observed, 'expected': n*p, 'z': z})
                if z > 6:
                    failed.append(f'{policy}/{slot}/{pid}: z={z:.3f}')
        duplicate_p = 3*sum(p*p for p in probs.values()) - 2*sum(p**3 for p in probs.values())
        n = sample['batches']
        z = abs(sample['duplicate_batches'] - n*duplicate_p) / math.sqrt(n*duplicate_p*(1-duplicate_p))
        if z > 6:
            failed.append(f'{policy}/duplicates: z={z:.3f}')
        report[policy] = {'piece_count': n*3, 'tested_bins': len(tests),
                          'worst_bin': max(tests, key=lambda t:t['z']),
                          'duplicate_expected_rate': duplicate_p,
                          'duplicate_observed_rate': sample['duplicate_batches']/n,
                          'duplicate_z': z, 'id_counts': sample['counts'], 'slot_counts': sample['slot_counts']}
    return report, failed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', type=Path, required=True)
    args = parser.parse_args()
    version = run(args.godot, ['--version']).strip()
    if not version.startswith('4.7.2.stable.'):
        raise SystemExit(f'Target version mismatch: {version}')
    output = HERE/'results'
    output.mkdir(exist_ok=True)
    project = Path(tempfile.mkdtemp(prefix='blocktower-preflight-project-'))
    (project/'project.godot').write_text('config_version=5\n', encoding='utf-8')
    (project/'examples').mkdir()
    (project/'pretests').mkdir()
    for name in ['piece_supply_v0_1.gd', 'check_piece_supply.gd']:
        shutil.copyfile(DOCS/'examples'/name, project/'examples'/name)
    shutil.copyfile(HERE/'preflight_probe.gd', project/'pretests/preflight_probe.gd')
    baseline = run(args.godot, ['--headless', '--path', project, '--script', 'examples/check_piece_supply.gd'])
    baseline_data = next(json.loads(line) for line in baseline.splitlines() if line.startswith('{'))
    assert baseline_data['checks'] > 0 and not baseline_data['failures']
    families, catalog = read_definitions()
    fixture_data = fixtures(catalog)
    fixture_path = project/'fixtures.json'
    fixture_path.write_text(json.dumps(fixture_data), encoding='utf-8')
    raw_path = project/'primary.json'
    print(run(args.godot, ['--headless', '--path', project, '--script', 'pretests/preflight_probe.gd',
                          '--', 'primary', fixture_path, raw_path]), flush=True)
    raw = json.loads(raw_path.read_text(encoding='utf-8'))
    assert raw['checks'] > 0 and not raw['failures']
    resume_path = project/'resume.json'
    print(run(args.godot, ['--headless', '--path', project, '--script', 'pretests/preflight_probe.gd',
                          '--', 'resume', raw_path, resume_path]), flush=True)
    resume = json.loads(resume_path.read_text(encoding='utf-8'))
    assert resume['checks'] > 0 and not resume['failures']
    distributions, failed = distribution_report(raw['samples'], families, catalog)
    files = [DOCS/'examples/piece_supply_v0_1.gd', DOCS/'examples/check_piece_supply.gd',
             HERE/'preflight_probe.gd', Path(__file__)]
    report = {'date': '2026-09-20', 'engine_version': version,
              'baseline': baseline_data, 'oracle_checks': raw['checks'],
              'boards': raw['board_count'], 'placement_comparisons': raw['placement_comparisons'],
              'resume': resume, 'distributions': distributions, 'distribution_failures': failed,
              'statistical_threshold': 'Absolute standardized residual <= 6; screening, not proof of randomness',
              'definition_hash': raw['definition_hash'],
              'fixture_sha256': hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
              'sha256': {str(p.relative_to(DOCS)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
              'limitations': ['No production GameSession or atomic-save implementation tested',
                             'No mobile rendering/performance test', 'No human balance validation']}
    (output/'preflight_2026-09-20.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (output/'replay_checkpoints.json').write_text(json.dumps(raw['checkpoints'], indent=2)+'\n', encoding='utf-8')
    play_data = {'engine_version': version, 'definition_hash': raw['definition_hash'],
                 'catalog': raw['catalog'], 'streams': raw['play_streams']}
    (output/'play_data.json').write_text(json.dumps(play_data, separators=(',', ':'))+'\n', encoding='utf-8')
    print(json.dumps({'report': str(output/'preflight_2026-09-20.json'), 'baseline_checks': baseline_data['checks'],
                      'oracle_checks': raw['checks'], 'placement_comparisons': raw['placement_comparisons'],
                      'resume_checks': resume['checks'], 'distribution_failures': failed}), flush=True)
    raise SystemExit(1 if failed else 0)


if __name__ == '__main__':
    main()
