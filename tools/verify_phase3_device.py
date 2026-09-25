"""Exercise Phase 3 on an isolated Android QA package with canonical save fixtures."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import statistics
import subprocess
import time


ROOT = Path(__file__).resolve().parents[1]
QA_PACKAGE = "com.blocktower.game.qa"


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def adb(base, *args, binary=False):
    result = subprocess.run([*base, *map(str, args)], capture_output=True, timeout=60)
    if result.returncode:
        raise RuntimeError(f"adb {' '.join(map(str, args))}: {result.stderr.decode(errors='replace')}")
    return result.stdout if binary else result.stdout.decode(errors="replace").strip()


def create_seed(godot, out, floors):
    seed_dir = out / f"seed_{floors}_{int(time.time() * 1000)}"
    seed_dir.mkdir()
    command = [godot, "--headless", "--path", str(ROOT / "game"), "--script",
               "res://tests/integration/save_process_probe.gd", "--", "init_copy_v2",
               str(seed_dir), str(seed_dir / "result.json")]
    result = subprocess.run(command, capture_output=True, timeout=60)
    log = (result.stdout + result.stderr).decode(errors="replace")
    if result.returncode or "SCRIPT ERROR:" in log or "ERROR:" in log:
        raise RuntimeError(f"seed generation failed: {log}")
    assert json.loads((seed_dir / "result.json").read_text(encoding="utf-8"))["ok"]
    return seed_dir / "slot_b.json"


def fixture(seed_path, floors):
    envelope = json.loads(seed_path.read_text(encoding="utf-8"))
    state = json.loads(envelope["payload"])
    growth = state["growth"]
    growth["total_floors"] = str(floors)
    growth["brick_lines"] = str(min(100, floors))
    growth["metal_lines"] = "0"
    growth["crystal_lines"] = "0"
    growth["representative_segment"] = "1"
    growth["segment_styles"] = {"1": "brick"}
    growth["segment_parts"] = {
        "1": ["brick_arch_window", "brick_terrace"] if floors == 30 else
        ["brick_arch_window", "brick_cornice", "brick_landmark", "brick_terrace"]
    }
    if floors >= 300:
        growth["segment_styles"].update({"2": "metal", "3": "crystal"})
    if floors >= 3000:
        growth["segment_styles"].update({"150": "metal", "300": "crystal"})
    payload = canonical(state)
    return canonical({"format": envelope["format"], "payload": payload,
                      "checksum": hashlib.sha256(payload.encode("utf-8")).hexdigest()}).encode("utf-8")


def screen(base, out, name):
    (out / f"{name}.png").write_bytes(adb(base, "exec-out", "screencap", "-p", binary=True))


def tap(base, x, y):
    adb(base, "shell", "input", "tap", x, y)
    time.sleep(0.4)


def memory(base):
    report = adb(base, "shell", "dumpsys", "meminfo", QA_PACKAGE)
    total = re.search(r"(?m)^\s*TOTAL\s+(\d+)\s", report)
    graphics = re.search(r"(?m)^\s*Graphics:\s+(\d+)\s", report)
    assert total and graphics, "meminfo counters missing"
    return {"total_pss_kib": int(total.group(1)), "graphics_pss_kib": int(graphics.group(1))}


def presented_frames(base, out, name):
    listing = adb(base, "shell", "dumpsys", "SurfaceFlinger", "--list")
    layers = [line.strip() for line in listing.splitlines()
              if f"SurfaceView[{QA_PACKAGE}/" in line and "(BLAST)" in line]
    assert len(layers) == 1, f"expected one Godot BLAST surface: {layers}"
    command = f"dumpsys SurfaceFlinger --latency '{layers[0]}'"
    adb(base, "shell", command.replace("--latency", "--latency-clear"))
    time.sleep(4)
    raw = adb(base, "shell", command)
    (out / f"{name}_surface_latency.tsv").write_text(raw + "\n", encoding="utf-8")
    actual = []
    for line in raw.splitlines()[1:]:
        columns = line.split()
        if len(columns) == 3 and columns[1].isdigit() and 0 < int(columns[1]) < 1_000_000_000_000_000_000:
            actual.append(int(columns[1]))
    intervals = [(b - a) / 1_000_000 for a, b in zip(actual, actual[1:]) if b > a]
    assert len(intervals) >= 60, f"too few presented frames: {len(intervals)}"
    return {"surface": layers[0], "samples": len(intervals),
            "median_interval_ms": round(statistics.median(intervals), 2),
            "p95_interval_ms": round(sorted(intervals)[int(0.95 * (len(intervals) - 1))], 2),
            "max_interval_ms": round(max(intervals), 2),
            "over_33ms": sum(value > 33.34 for value in intervals)}


def save_state(base):
    slots = [adb(base, "exec-out", "run-as", QA_PACKAGE, "cat", f"files/save_v1/slot_{name}.json", binary=True)
             for name in ("a", "b")]
    snapshots = [json.loads(json.loads(raw)["payload"]) for raw in slots]
    return max(snapshots, key=lambda state: int(state["revision"])), slots


def copy_appearance(base, out, fixture_state, mode):
    if mode == "brick_parts":
        tap(base, 150, 1850)
    tap(base, 540, 2190)
    if mode == "brick_parts":
        adb(base, "shell", "input", "text", "3")
    adb(base, "shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.3)
    screen(base, out, f"copy_sheet_{mode}")
    tap(base, 775, 2260)
    screen(base, out, f"copy_result_{mode}")
    saved, slots = save_state(base)
    expected = json.loads(canonical(fixture_state))
    expected["revision"] = "2"
    expected["last_event_id"] = "2"
    if mode == "brick_parts":
        expected["growth"]["segment_styles"]["3"] = "brick"
        expected["growth"]["segment_parts"]["3"] = expected["growth"]["segment_parts"]["1"][:]
    else:
        expected["growth"]["segment_styles"]["1"] = "metal"
        expected["growth"]["segment_parts"].pop("1")
    assert saved == expected, f"copy result differs from one atomic target update: {mode}"
    adb(base, "shell", "am", "force-stop", QA_PACKAGE)
    adb(base, "shell", "am", "start", "-W", "-a", "android.intent.action.MAIN",
        "-c", "android.intent.category.LAUNCHER", "-p", QA_PACKAGE)
    time.sleep(1)
    resumed, resumed_slots = save_state(base)
    assert resumed == expected and resumed_slots == slots, "copy save changed during restart"
    return {"mode": mode, "revision": saved["revision"], "target_material":
            saved["growth"]["segment_styles"]["3" if mode == "brick_parts" else "1"],
            "target_parts": saved["growth"]["segment_parts"].get("3" if mode == "brick_parts" else "1", []),
            "same_state_after_restart": True, "same_save_bytes_after_restart": True}


def jump_to_segment(base, out, target, from_puzzle):
    if from_puzzle:
        tap(base, 240, 225)
    before, slots = save_state(base)
    tap(base, 870, 330)
    adb(base, "shell", "input", "text", str(target))
    adb(base, "shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.3)
    screen(base, out, f"jump_sheet_{target}")
    tap(base, 775, 2260)
    screen(base, out, f"jump_result_{target}")
    after, after_slots = save_state(base)
    assert before == after and slots == after_slots, "jump changed saved state"
    return {"target": target, "save_unchanged": True}


def soak_navigation(base, cycles):
    before, slots = save_state(base)
    initial_memory = memory(base)
    initial_process = adb(base, "shell", "pidof", QA_PACKAGE)
    for _ in range(cycles):
        tap(base, 900, 2190)
        tap(base, 540, 2180)
    final_memory = memory(base)
    final_process = adb(base, "shell", "pidof", QA_PACKAGE)
    after, after_slots = save_state(base)
    assert initial_process == final_process and before == after and slots == after_slots
    return {"cycles": cycles, "same_process": True, "same_save_bytes": True,
            "initial_memory": initial_memory, "final_memory": final_memory,
            "pss_delta_kib": final_memory["total_pss_kib"] - initial_memory["total_pss_kib"]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", default=str(Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe"))
    parser.add_argument("--serial", required=True)
    parser.add_argument("--seed", help="Optional prebuilt canonical v2 save envelope")
    parser.add_argument("--godot", default="C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")
    parser.add_argument("--output", default=str(ROOT / "tools/out/phase3_device"))
    parser.add_argument("--floors", type=int, choices=[30, 300, 3000], required=True)
    parser.add_argument("--exercise", action="store_true")
    parser.add_argument("--copy-mode", choices=["brick_parts", "nonbrick"])
    parser.add_argument("--jump-segment", type=int)
    parser.add_argument("--soak-cycles", type=int, default=0)
    parser.add_argument("--large-text", action="store_true")
    args = parser.parse_args()
    if not args.exercise and (args.copy_mode or args.jump_segment or args.soak_cycles):
        parser.error("copy, jump and navigation soak require --exercise")
    if args.soak_cycles < 0:
        parser.error("--soak-cycles must be nonnegative")
    base = [args.adb, "-s", args.serial]
    out = Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=True)
    package_list = adb(base, "shell", "pm", "list", "packages", QA_PACKAGE)
    assert f"package:{QA_PACKAGE}" in package_list, "QA APK is not installed"
    payload = fixture(Path(args.seed) if args.seed else create_seed(args.godot, out, args.floors), args.floors)
    fixture_state = json.loads(json.loads(payload)["payload"])
    local = out / f"fixture_{args.floors}.json"
    local.write_bytes(payload)
    assert "Success" in adb(base, "shell", "pm", "clear", QA_PACKAGE)
    remote = f"/data/local/tmp/blocktower_phase3_{args.floors}.json"
    adb(base, "push", local, remote)
    adb(base, "shell", "run-as", QA_PACKAGE, "mkdir", "-p", "files/save_v1")
    for slot in ("a", "b"):
        adb(base, "shell", "run-as", QA_PACKAGE, "cp", remote, f"files/save_v1/slot_{slot}.json")
    adb(base, "shell", "rm", remote)
    if args.large_text:
        prefs = out / "large_text_preferences.json"
        prefs.write_text(canonical({"schema": "bt_presentation_v2", "reduced_motion": True,
                                    "muted": True, "volume": 70, "haptics": False,
                                    "large_text": True}), encoding="utf-8")
        prefs_remote = "/data/local/tmp/blocktower_phase3_preferences.json"
        adb(base, "push", prefs, prefs_remote)
        adb(base, "shell", "run-as", QA_PACKAGE, "cp", prefs_remote, "files/save_v1/presentation.json")
        adb(base, "shell", "rm", prefs_remote)
    adb(base, "shell", "input", "keyevent", "KEYCODE_WAKEUP")
    adb(base, "shell", "wm", "dismiss-keyguard")
    launch = adb(base, "shell", "am", "start", "-W", "-a", "android.intent.action.MAIN",
                 "-c", "android.intent.category.LAUNCHER", "-p", QA_PACKAGE)
    time.sleep(2)
    screen(base, out, f"puzzle_{args.floors}")
    result = {"floors": args.floors, "large_text": args.large_text,
              "fixture_sha256": hashlib.sha256(payload).hexdigest(),
              "launch": launch, "screenshots": [f"puzzle_{args.floors}.png"]}
    if args.exercise:
        assert "1080x2400" in adb(base, "shell", "wm", "size"), "coordinate map requires 1080x2400"
        original = adb(base, "exec-out", "run-as", QA_PACKAGE, "cat", "files/save_v1/slot_a.json", binary=True)
        tap(base, 240, 225)
        screen(base, out, f"detail_{args.floors}")
        result["screenshots"].append(f"detail_{args.floors}.png")
        tap(base, 930, 730)
        screen(base, out, f"focus_{args.floors}")
        result["screenshots"].append(f"focus_{args.floors}.png")
        tap(base, 930, 2295)
        screen(base, out, f"focus_next_{args.floors}")
        result["screenshots"].append(f"focus_next_{args.floors}.png")
        adb(base, "shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(0.4)
        tap(base, 900, 2190)
        screen(base, out, f"overview_{args.floors}")
        result["screenshots"].append(f"overview_{args.floors}.png")
        result["memory_overview"] = memory(base)
        result["presented_frames_overview"] = presented_frames(base, out, f"overview_{args.floors}")
        adb(base, "shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(0.4)
        after = adb(base, "exec-out", "run-as", QA_PACKAGE, "cat", "files/save_v1/slot_a.json", binary=True)
        result["read_only_save_unchanged"] = original == after == payload
        assert result["read_only_save_unchanged"], "read-only navigation changed saved state"
        result["memory_detail"] = memory(base)
        if args.soak_cycles:
            result["navigation_soak"] = soak_navigation(base, args.soak_cycles)
        if args.copy_mode:
            assert args.floors >= 300, "copy fixture requires unlocked four parts"
            result["copy"] = copy_appearance(base, out, fixture_state, args.copy_mode)
            result["screenshots"].extend([f"copy_sheet_{args.copy_mode}.png", f"copy_result_{args.copy_mode}.png"])
        if args.jump_segment:
            assert 1 <= args.jump_segment <= args.floors // 10
            result["jump"] = jump_to_segment(base, out, args.jump_segment, bool(args.copy_mode))
            result["screenshots"].extend([f"jump_sheet_{args.jump_segment}.png", f"jump_result_{args.jump_segment}.png"])
    (out / f"result_{args.floors}.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
