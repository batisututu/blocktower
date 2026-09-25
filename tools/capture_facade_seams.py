"""Capture the original Phase2-B set or crystal facade joints with pinned Godot."""
import argparse, hashlib, json, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE_SHA256 = "ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424"
ORDERS = {
    "phase2b": ("metal_over_wood", "wood_over_metal", "metal_over_brick", "brick_over_metal"),
    "crystal": ("crystal_over_wood", "wood_over_crystal", "crystal_over_brick", "brick_over_crystal", "crystal_over_metal", "metal_over_crystal"),
    "brick_arch": ("brick_arch_over_brick", "brick_over_brick_arch"),
    "phase2e": ("brick_terrace_over_brick", "brick_over_brick_terrace", "brick_arch_terrace_over_brick_arch", "brick_arch_over_brick_arch_terrace"),
    "phase2f": ("brick_cornice_over_brick", "brick_cornice_roof_top_over_brick", "brick_over_wood", "wood_over_brick", "metal_over_brick", "crystal_over_brick"),
}
parser = argparse.ArgumentParser()
parser.add_argument("--godot", default="C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64.exe")
parser.add_argument("--set", choices=ORDERS, default="phase2b")
parser.add_argument("--output")
args = parser.parse_args()
engine = Path(args.godot)
actual_hash = hashlib.sha256(engine.read_bytes()).hexdigest()
if actual_hash != ENGINE_SHA256:
    raise SystemExit(f"Unexpected Godot GUI engine SHA-256: {actual_hash}")
defaults = {"phase2b":"tools/out/phase2b_metal_glass/seams","crystal":"tools/out/phase2c_crystal/seams","brick_arch":"tools/out/phase2d_brick_arch/seams","phase2e":"tools/out/phase2e_brick_terrace/seams","phase2f":"tools/out/phase2f_brick_cornice/seams"}
output = (ROOT / (args.output or defaults[args.set])).resolve()
output.mkdir(parents=True, exist_ok=True)
reports = []
creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
for order in ORDERS[args.set]:
    capture = output / f"{order}.png"
    command = [str(engine), "--path", str(ROOT / "game"), "--resolution", "360x800", "--script",
               "res://tests/integration/facade_seam_capture.gd", "--", order, str(capture)]
    run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace",
                         timeout=60, creationflags=creationflags)
    (output / f"{order}.log").write_text(run.stdout + run.stderr, encoding="utf-8")
    if run.returncode or "SCRIPT ERROR" in run.stdout + run.stderr or "ERROR:" in run.stdout + run.stderr:
        raise SystemExit(f"Godot seam capture failed: {order}\n{run.stdout}\n{run.stderr}")
    report = json.loads(capture.with_suffix(".json").read_text(encoding="utf-8-sig"))
    assert capture.is_file() and capture.stat().st_size > 0
    assert report["viewport"] == [360, 800]
    assert report["shared_canvas"] == [640, 480] and report["shared_anchor"] == [320, 240]
    assert abs(report["floor_step_source_px"] - 106.4683685) < 0.001
    assert report["upper_source"]["size"] == report["lower_source"]["size"] == [640, 480]
    assert report["source_overlap_silhouette_empty_rows"] == 0
    reports.append(report)
    print(f"PASS {order}", flush=True)
summary = {"godot_version": "4.7.2.stable.official.ed1daf0bf", "engine_sha256": actual_hash,
           "viewport": [360, 800], "shared_canvas": [640, 480], "shared_anchor": [320, 240],
           "floor_step_source_px": 106.4683685, "sample_scale": 0.5, "reports": reports,
           "material_set": args.set,
           "checks": [{"name": "required material orientations captured", "passed": len(reports) == len(ORDERS[args.set])},
                      {"name": "source metadata aligns across all materials", "passed": True},
                      {"name": "zero empty rows", "passed": all(r["source_overlap_silhouette_empty_rows"] == 0 for r in reports)},
                      {"name": "transparent edge texel RGB counts recorded for visual halo inspection", "passed": all("transparent_pixels_with_rgb" in r["upper_source"] and "transparent_pixels_with_rgb" in r["lower_source"] for r in reports)}]}
if not all(check["passed"] for check in summary["checks"]):
    raise SystemExit("Seam summary validation failed")
(output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(output)
