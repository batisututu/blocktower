"""Build an isolated probe project from unchanged production save/core sources."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--godot', required=True)
p.add_argument('--sdk', default=str(Path.home() / 'AppData/Local/Android/Sdk'))
p.add_argument('--javac', default=shutil.which('javac'))
a = p.parse_args()
target = ROOT / 'tools/out/android_recovery_probe'
target.mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / 'game/assets/visual_bible/surfaces/icon_tower.svg', target / 'icon.svg')
shutil.copytree(ROOT / 'game/data', target / 'data', dirs_exist_ok=True)
for name in ('core', 'persistence'):
    shutil.copytree(ROOT / 'game/scripts' / name, target / 'scripts' / name, dirs_exist_ok=True)
(target / 'scripts/application').mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / 'game/scripts/application/saved_game.gd', target / 'scripts/application/saved_game.gd')
source = (ROOT / 'game/tests/integration/save_process_probe.gd').read_text(encoding='utf-8')
source = source.replace('extends SceneTree', 'extends Node', 1)
source = source.replace('func _initialize():\n    args = OS.get_cmdline_user_args()', 'func _ready():\n    var command: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://command.json"))\n    args = PackedStringArray(command.args)')
start = source.index('    if mode == "app_boot":')
end = source.index('    var opened:', start)
source = source[:start] + '''    if mode == "guard":
        var guard_type = load("res://scripts/persistence/android_file_guard.gd")
        var first = guard_type.new()
        var second = guard_type.new()
        var guard_path := ProjectSettings.globalize_path("user://guard-test")
        var acquired: String = first.acquire(guard_path)
        var busy: String = second.acquire(guard_path + "/../guard-test")
        var live: int = guard_type.owner_status(OS.get_process_id())
        var dead: int = guard_type.owner_status(2147483647)
        var released: bool = first.release()
        var retried: String = second.acquire(guard_path)
        var released_second: bool = second.release()
        _finish({"ok": acquired == "" and busy == "SAVE_BUSY" and live == 1 and dead == 0 and released and retried == "" and released_second,
            "error": str([acquired, busy, live, dead, released, retried, released_second])})
        return
''' + source[end:]
source = source.replace('quit(', 'get_tree().quit(')
(target / 'probe.gd').write_text(source, encoding='utf-8')
(target / 'probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
(target / 'project.godot').write_text('''config_version=5
[application]
config/name="Blocktower Recovery QA"
config/icon="res://icon.svg"
run/main_scene="res://probe.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
''', encoding='utf-8')
preset = (ROOT / 'game/export_presets.cfg').read_text(encoding='utf-8').split('[preset.1]')[0]
preset = preset.replace('com.blocktower.game', 'com.blocktower.recovery.qa').replace('package/name="Blocktower"', 'package/name="Blocktower Recovery QA"')
preset = preset.replace('export/blocktower-device-debug.apk', 'probe.apk').replace('assets/visual_bible/tower/geometry.json', '')
preset = preset.replace('architectures/x86_64=false', 'architectures/x86_64=true')
(target / 'export_presets.cfg').write_text(preset, encoding='utf-8')
manifest = {str(f.relative_to(ROOT / 'game')): hashlib.sha256(f.read_bytes()).hexdigest() for f in (ROOT / 'game/scripts').rglob('*.gd') if f.parts[-2] == 'persistence' or 'core' in f.parts or f.name == 'saved_game.gd'}
manifest.update({str(f.relative_to(ROOT / 'game')): hashlib.sha256(f.read_bytes()).hexdigest() for f in (ROOT / 'game/data').rglob('*.tres')})
(target / 'source_hashes.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
for flags in (['--editor', '--import'], ['--export-debug', 'Android Device Debug', str(target / 'probe.apk')]):
    result = subprocess.run([a.godot, '--headless', '--path', str(target), *flags], capture_output=True)
    log = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    print(log)
    assert result.returncode == 0 and 'SCRIPT ERROR:' not in log and 'ERROR:' not in log, 'Probe export failed'
android_jar = Path(a.sdk) / 'platforms/android-36/android.jar'
subprocess.run([a.javac, '--release', '8', '-cp', str(android_jar), '-d', str(target), str(ROOT / 'tools/RecoveryLockProbe.java')], check=True)
subprocess.run([str(Path(a.sdk) / 'build-tools/36.0.0/d8.bat'), '--lib', str(android_jar), '--output', str(target), str(target / 'RecoveryLockProbe.class')], check=True)
print(target / 'probe.apk')
