"""Verify Phase 2-G landmark source/runtime registration and PNG geometry."""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest_path = ROOT / "art_source/visual_bible/manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
registered = {
    item["path"]: item
    for section in ("source", "runtime")
    for item in manifest[section]
}
required = (
    "art_source/visual_bible/render_brick_landmark.gd",
    "art_source/visual_bible/tower_scenes/brick_landmark_floor_mid.tscn",
    "art_source/visual_bible/tower_scenes/brick_arch_landmark_floor_mid.tscn",
    "game/assets/visual_bible/tower/brick_landmark_floor_mid.png",
    "game/assets/visual_bible/tower/brick_arch_landmark_floor_mid.png",
    "game/assets/visual_bible/tower/brick_landmark_geometry.json",
)
for name in required:
    assert name in registered, f"Unregistered landmark artifact: {name}"
    path = ROOT / name
    raw = path.read_bytes()
    record = registered[name]
    assert record["bytes"] == len(raw), f"Stale byte count: {name}"
    assert record["sha256"] == hashlib.sha256(raw).hexdigest(), f"Stale SHA-256: {name}"
    print("PASS registered", name)

for name in required:
    if not name.endswith(".png"):
        continue
    raw = (ROOT / name).read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n", f"Invalid PNG signature: {name}"
    width, height = struct.unpack(">II", raw[16:24])
    assert (width, height) == (640, 480), f"Unexpected PNG dimensions: {name}"
    assert registered[name].get("dimensions") == [640, 480], f"Manifest dimensions stale: {name}"
    print("PASS dimensions", name, width, height)

geometry = json.loads((ROOT / "game/assets/visual_bible/tower/brick_landmark_geometry.json").read_text(encoding="utf-8-sig"))
assert geometry["canvas"] == [640, 480]
assert geometry["anchor"] == [320, 240]
assert abs(geometry["floor_step"] - 106.4683685) < 0.001
assert set(geometry["variants"]) == {"brick_landmark_floor_mid", "brick_arch_landmark_floor_mid"}
assert "clock-face landmark" in manifest["origins"]["brick_landmark_part"]
print("PASS shared canvas/anchor/floor step and ordinary/arch variants")
