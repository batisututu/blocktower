"""Rebuild original, exact vector components for Blocktower's first B asset set."""
from pathlib import Path
import json
import hashlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/vector"
OUT.mkdir(parents=True, exist_ok=True)
ASSETS = {}

def svg(name, width, height, body):
    payload = f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>\n'
    (OUT / f"{name}.svg").write_bytes(payload.encode("utf-8"))
    ASSETS[name] = {"path": f"game/assets/vector/{name}.svg", "width": width, "height": height,
                    "sha256": hashlib.sha256(payload.encode()).hexdigest(), "origin": "Original project vector geometry", "source": "art_source/build_vector_assets.py"}

svg("cell_b", 64, 64, '<path d="M10 2H54L62 10V54L54 62H10L2 54V10Z" fill="#ffffff"/><path d="M12 5H52L59 12V52L52 59H12L5 52V12Z" fill="#000000" fill-opacity=".045"/><path d="M17 13H47L51 17V49H13V17Z" fill="#ffffff" fill-opacity=".06" stroke="#ffffff" stroke-opacity=".66" stroke-width="2"/><path d="M13 49H51" stroke="#000000" stroke-opacity=".18" stroke-width="2"/>')
svg("cell_empty", 64, 64, '<rect x="2" y="2" width="60" height="60" rx="8" fill="#29383d"/>')
svg("cell_frame", 64, 64, '<path d="M17 13H47L51 17V49H13V17Z" fill="none" stroke="#fff3da" stroke-opacity=".58" stroke-width="2"/>')
svg("state_valid", 64, 64, '<rect x="3" y="3" width="58" height="58" rx="7" fill="#9bd8bd" fill-opacity=".17" stroke="#bdebd5" stroke-width="3"/><path d="M22 33L29 40L43 24" fill="none" stroke="#e1ffef" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')
svg("state_invalid", 64, 64, '<rect x="3" y="3" width="58" height="58" rx="7" fill="#f29986" fill-opacity=".17" stroke="#f29986" stroke-width="3"/><path d="M24 24L40 40M40 24L24 40" stroke="#ffe3dc" stroke-width="3" stroke-linecap="round"/>')
svg("state_selected", 64, 64, '<rect x="2" y="2" width="60" height="60" rx="8" fill="none" stroke="#f3eddf" stroke-width="3"/>')
icons = {
 "settings": '<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="2.5"/><path d="M12 2V5M12 19V22M2 12H5M19 12H22M5 5L7 7M17 17L19 19M5 19L7 17M17 7L19 5"/>',
 "back": '<path d="M14 5L7 12L14 19M7 12H21"/>',
 "close": '<path d="M6 6L18 18M18 6L6 18"/>',
 "tower": '<path d="M7 21V7H17V21M5 21H19M6 7L12 3L18 7M10 11H14M10 15H14M10 19H14"/>',
 "edit": '<path d="M5 16L16 5L19 8L8 19L4 20Z M14 7L17 10"/>',
 "featured": '<path d="M12 3L15 9L21 10L16.5 14.5L17.5 21L12 18L6.5 21L7.5 14.5L3 10L9 9Z"/>',
 "lock": '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V6A4 4 0 0 1 16 6V10M12 14V17"/>',
 "audio": '<path d="M4 9H8L13 5V19L8 15H4Z M16 9Q20 12 16 15M19 6Q25 12 19 18"/>',
 "check": '<path d="M5 12L10 17L20 6"/>',
 "chevron": '<path d="M9 5L16 12L9 19"/>',
 "layers": '<path d="M3 7L12 3L21 7L12 11Z M3 12L12 16L21 12M3 17L12 21L21 17"/>',
}
for name, body in icons.items():
    svg("icon_" + name, 24, 24, '<g fill="none" stroke="#f3eddf" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'+body+'</g>')
# Front-elevation modules deliberately use identical widths and explicit attachment edges.
svg("wood_floor", 160, 40, '<rect x="8" width="144" height="40" fill="#b48b62"/><path d="M8 0H152V5H8Z M8 35H152V40H8Z" fill="#715440"/><path d="M12 5H17V35H12Z M143 5H148V35H143Z" fill="#e1bc85"/><g fill="#2b4146" stroke="#e1bc85" stroke-width="2"><rect x="29" y="11" width="22" height="18"/><rect x="69" y="11" width="22" height="18"/><rect x="109" y="11" width="22" height="18"/></g><path d="M40 11V29M80 11V29M120 11V29" stroke="#e1bc85" stroke-width="2"/>')
svg("wood_cornice", 160, 12, '<path d="M4 0H156V5H152V12H8V5H4Z" fill="#795b43"/><path d="M4 0H156V3H4Z" fill="#e1bc85"/>')
svg("wood_roof", 160, 42, '<path d="M0 32L32 6H128L160 32H150V42H10V32Z" fill="#536b65"/><path d="M0 32L32 6H128L160 32" fill="none" stroke="#a9bbb0" stroke-width="3"/><path d="M12 34H148V42H12Z" fill="#795b43"/>')
svg("wood_base", 160, 24, '<path d="M8 0H152V15H158V24H2V15H8Z" fill="#665b4f"/><path d="M8 0H152V4H8Z M2 15H158V18H2Z" fill="#c8b99d"/>')
(ROOT / "art_source/vector_manifest.json").write_text(json.dumps({"version":"bt_assets_b_0_1", "assets":ASSETS},indent=2)+"\n",encoding="utf-8")
print(f"Wrote {len(ASSETS)} original vector assets")
