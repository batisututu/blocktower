"""Capture and validate both wood/brick floor-boundary orientations with pinned Godot."""
import argparse
import hashlib
import json
import subprocess
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_ENGINE_SHA256 = "ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424"
ORDERS = (
    "wood_over_brick", "brick_over_wood",
    "landmark_over_brick", "brick_over_landmark",
    "arch_landmark_over_arch", "arch_over_arch_landmark",
    "landmark_over_terrace", "cornice_roof_over_landmark",
)

parser = argparse.ArgumentParser()
parser.add_argument("--godot", default="C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64.exe")
parser.add_argument("--output", default="tools/out/phase2a_seam_20260924")
args = parser.parse_args()
engine = Path(args.godot)
engine_hash = hashlib.sha256(engine.read_bytes()).hexdigest()
if engine_hash != EXPECTED_ENGINE_SHA256:
    raise SystemExit(f"Unexpected Godot GUI engine SHA-256: {engine_hash}")
output = (ROOT / args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
reports = []
creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)

for order in ORDERS:
    capture = output / f"{order}.png"
    command = [
        str(engine), "--path", str(ROOT / "game"), "--resolution", "360x800",
        "--script", "res://tests/integration/brick_seam_capture.gd", "--",
        order, str(capture),
    ]
    run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                         encoding="utf-8", errors="replace", timeout=60,
                         creationflags=creationflags)
    (output / f"{order}.log").write_text(run.stdout + run.stderr, encoding="utf-8")
    if run.returncode != 0 or "SCRIPT ERROR" in run.stdout + run.stderr or "ERROR:" in run.stdout + run.stderr:
        raise SystemExit(f"Godot seam capture failed: {order}\n{run.stdout}\n{run.stderr}")
    report = json.loads(capture.with_suffix(".json").read_text(encoding="utf-8-sig"))
    assert capture.is_file() and capture.stat().st_size > 0
    assert report["viewport"] == [360, 800]
    assert report["shared_canvas"] == [640, 480] and report["shared_anchor"] == [320, 240]
    assert abs(report["floor_step_source_px"] - 106.4683685) < 0.001
    assert report["upper_source"]["size"] == [640, 480]
    assert report["lower_source"]["size"] == [640, 480]
    assert report["source_overlap_silhouette_empty_rows"] == 0
    reports.append(report)
    print(f"PASS {order}", flush=True)

assert len(reports) == len(ORDERS)
landmark_reports = [r for r in reports if "landmark" in r["upper_material"] or "landmark" in r["lower_material"]]
assert len(landmark_reports) == 6
assert all(r["source_overlap_silhouette_empty_rows"] == 0 for r in landmark_reports)
summary = {
    "godot_version": "4.7.2.stable.official.ed1daf0bf",
    "engine_sha256": engine_hash,
    "viewport": [360, 800],
    "shared_canvas": [640, 480],
    "shared_anchor": [320, 240],
    "floor_step_source_px": 106.4683685,
    "sample_scale": 0.5,
    "reports": reports,
    "checks": [
        {"name": "both legacy material orders captured", "passed": True},
        {"name": "ordinary/arch landmark joins and terrace/cornice endpoints captured", "passed": True},
        {"name": "both source modules have matching dimensions and anchor metadata", "passed": True},
        {"name": "all captured joins have no empty silhouette rows in the shared overlap envelope", "passed": True},
        {"name": "native PNG and per-case JSON evidence exist", "passed": True},
    ],
}
(output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(output)
