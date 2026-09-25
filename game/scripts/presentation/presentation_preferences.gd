extends RefCounted
## 게임 기록과 독립된 표시 설정. 잘못된 원본은 덮어쓰지 않는다.
const LEGACY_SCHEMA := "bt_presentation_v1"
const DEFAULTS := {"schema": "bt_presentation_v2", "reduced_motion": false, "muted": false, "volume": 70, "haptics": true, "large_text": false}
const LEGACY_DEFAULTS := {"schema": LEGACY_SCHEMA, "reduced_motion": false, "muted": false, "volume": 70, "haptics": true}
const BOOLEAN_KEYS := ["reduced_motion", "muted", "haptics", "large_text"]
var values: Dictionary = DEFAULTS.duplicate()
var path := ""
var warning := ""

func configure(file_path: String) -> void:
    path = ProjectSettings.globalize_path(file_path)
    if not FileAccess.file_exists(path): return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        warning = "설정을 읽지 못해 기본 설정을 사용합니다."
        return
    var length := file.get_length()
    file.close()
    if length > 4096:
        warning = "설정 파일을 확인할 수 없어 기본 설정을 사용합니다."
        return
    var parser := JSON.new()
    var error := parser.parse(FileAccess.get_file_as_string(path))
    var decoded = parser.data
    if error != OK:
        warning = "설정 파일을 확인할 수 없어 기본 설정을 사용합니다."
        return
    if _valid(decoded):
        values = decoded
        values.volume = int(values.volume)
        return
    if _valid_legacy(decoded):
        values = _migrate(decoded)
        if not _write(values):
            warning = "기존 설정을 새 형식으로 저장하지 못해 읽기 전용으로 사용합니다."
        return
    warning = "설정 파일을 확인할 수 없어 기본 설정을 사용합니다."

func _valid(v: Variant) -> bool:
    return _valid_shape(v, DEFAULTS)

func _valid_legacy(v: Variant) -> bool:
    return _valid_shape(v, LEGACY_DEFAULTS)

func _valid_shape(v: Variant, shape: Dictionary) -> bool:
    if not v is Dictionary or v.size() != shape.size(): return false
    for key in shape:
        if not v.has(key): return false
    if v.schema != shape.schema: return false
    for key in BOOLEAN_KEYS:
        if not shape.has(key): continue
        if typeof(v[key]) != TYPE_BOOL: return false
    return typeof(v.volume) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v.volume)) and v.volume == int(v.volume) and v.volume >= 0 and v.volume <= 100

func _migrate(legacy: Dictionary) -> Dictionary:
    var migrated := DEFAULTS.duplicate()
    for key in ["reduced_motion", "muted", "volume", "haptics"]:
        migrated[key] = legacy[key]
    migrated.volume = int(migrated.volume)
    return migrated

func update(key: String, value: Variant) -> bool:
    if not warning.is_empty(): return false
    var candidate := values.duplicate()
    candidate[key] = value
    if not _valid(candidate) or path.is_empty(): return false
    if not _write(candidate): return false
    values = candidate
    return true

func _write(candidate: Dictionary) -> bool:
    if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
    var pending := path + ".pending"
    var file := FileAccess.open(pending, FileAccess.WRITE)
    if file == null: return false
    var text := JSON.stringify(candidate)
    var stored := file.store_string(text)
    file.flush()
    var error := file.get_error()
    file.close()
    if not stored or error != OK or FileAccess.get_file_as_string(pending) != text: return false
    if DirAccess.rename_absolute(pending, path) != OK: return false
    return true
