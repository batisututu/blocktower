extends RefCounted
## 두 세대 파일을 교대로 갱신한다. 확정 전에는 현재 유효 세대를 건드리지 않는다.
const Codec = preload("res://scripts/persistence/save_codec.gd")
const Generator = preload("res://scripts/core/generation/piece_generator.gd")
const AndroidGuard = preload("res://scripts/persistence/android_file_guard.gd")
const SLOTS := ["slot_a.json", "slot_b.json"]
var _root := ""
var _codec: RefCounted
var _has_lock := false
var _observed_recovery := ""
var _native_guard: RefCounted

static func open(directory: String = "user://save_v1", config: Variant = null) -> Dictionary:
    var repository = new()
    var error: String = repository.configure(directory, config)
    return {"ok": true, "repository": repository} if error.is_empty() else Codec.failure(error)

func configure(directory: String, config: Variant = null) -> String:
    if not _root.is_empty(): return "ALREADY_CONFIGURED"
    if directory.begins_with("res://") or (not directory.begins_with("user://") and not directory.is_absolute_path()): return "INVALID_SAVE_PATH"
    var path := ProjectSettings.globalize_path(directory).simplify_path().replace("\\", "/").trim_suffix("/")
    if path.is_empty() or path.get_file().is_empty() or path.ends_with(":") or path == "/": return "INVALID_SAVE_PATH"
    var valid := Generator.create(config)
    if not valid.ok: return valid.error
    _root = path
    _codec = Codec.new(config)
    return ""

func directory() -> String:
    return _root

func _lock_name() -> String:
    return ".writer_%d.lock" % OS.get_process_id()

func _owner_status(pid: int) -> int:
    if OS.get_name() == "Android": return AndroidGuard.owner_status(pid)
    # Godot is_process_running은 자신의 자식만 검사한다. 다른 인스턴스에 사용하지 않는다.
    if OS.get_name() != "Windows": return -1
    var executable := OS.get_environment("SystemRoot").path_join("System32/tasklist.exe")
    if not FileAccess.file_exists(executable): return -1
    var output: Array = []
    var code := OS.execute(executable, ["/FO", "CSV", "/NH"], output, true, false)
    if code != 0 or output.is_empty(): return -1
    var rows := 0
    for line in str(output[0]).split("\n"):
        var text := line.strip_edges()
        if text.is_empty(): continue
        var columns := text.split("\",\"")
        if not text.begins_with("\"") or columns.size() < 5: return -1
        var parsed := Generator.parse_int64(columns[1])
        if not parsed.ok: return -1
        rows += 1
        if parsed.value == pid: return 1
    return 0 if rows > 0 else -1

func _acquire() -> String:
    if _root.is_empty(): return "NOT_CONFIGURED"
    if _has_lock: return "SAVE_BUSY"
    if FileAccess.file_exists(_root): return "SAVE_DIRECTORY_FAILED"
    if DirAccess.make_dir_recursive_absolute(_root) != OK: return "SAVE_DIRECTORY_FAILED"
    if OS.get_name() == "Android":
        _native_guard = AndroidGuard.new()
        var error: String = _native_guard.acquire(_root.path_join(".writer.guard"))
        if not error.is_empty(): return error
    else:
        var claim := _root.path_join(_lock_name())
        var made := DirAccess.make_dir_absolute(claim)
        if made != OK: return "SAVE_BUSY" if DirAccess.dir_exists_absolute(claim) else "SAVE_LOCK_FAILED"
    _has_lock = true
    var directory_handle := DirAccess.open(_root)
    if directory_handle == null:
        _release()
        return "SAVE_READ_FAILED"
    directory_handle.include_hidden = true
    for name in directory_handle.get_directories():
        if (name == _lock_name() and _native_guard == null) or not name.begins_with(".writer_") or not name.ends_with(".lock"): continue
        var owner := Generator.parse_int64(name.trim_prefix(".writer_").trim_suffix(".lock"))
        if not owner.ok or owner.value <= 0 or owner.value > 2147483647:
            _release()
            return "SAVE_LOCK_INVALID"
        var owner_status := _owner_status(owner.value)
        if owner_status != 0:
            _release()
            return "SAVE_BUSY" if owner_status == 1 else "SAVE_PROCESS_CHECK_FAILED"
        # 이름을 엄격히 제한한 현재 저장 폴더의 빈 잠금 디렉터리만 제거한다.
        if DirAccess.remove_absolute(_root.path_join(name)) != OK and DirAccess.dir_exists_absolute(_root.path_join(name)):
            _release()
            return "SAVE_LOCK_FAILED"
    return ""

func _release() -> bool:
    if not _has_lock: return true
    if _native_guard != null:
        var released: bool = _native_guard.release()
        if released:
            _has_lock = false
            _native_guard = null
        return released
    var error := DirAccess.remove_absolute(_root.path_join(_lock_name()))
    _has_lock = false
    return error == OK

func _read(name: String) -> Dictionary:
    var path := _root.path_join(name)
    if DirAccess.dir_exists_absolute(path): return Codec.failure("SAVE_READ_FAILED")
    if not FileAccess.file_exists(path): return {"ok": true, "found": false}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return Codec.failure("SAVE_READ_FAILED")
    var length := file.get_length()
    if length > Codec.MAX_BYTES:
        file.close()
        return Codec.failure("SAVE_TOO_LARGE")
    var bytes := file.get_buffer(length)
    var error := file.get_error()
    file.close()
    if bytes.size() != length or error != OK: return Codec.failure("SAVE_READ_FAILED")
    var decoded: Dictionary = _codec.decode(bytes)
    decoded["found"] = true
    decoded["file"] = name
    decoded["raw_hash"] = FileAccess.get_sha256(path)
    return decoded

func _scan() -> Dictionary:
    var valid: Array = []
    var damaged: Array = []
    for name in SLOTS:
        var read := _read(name)
        if not read.ok:
            if not read.error.begins_with("CORRUPT_"): return read
            damaged.append({"file": name, "reason": read.error, "raw_hash": read.raw_hash})
        elif read.found:
            valid.append(read)
    if valid.is_empty():
        if not damaged.is_empty(): return Codec.failure("SAVE_CORRUPT")
        return {"ok": true, "found": false, "recovered": false, "recovery": {}, "ignored_pending": FileAccess.file_exists(_root.path_join("pending.json"))}
    if valid.size() == 2:
        if valid[0].snapshot.session_id != valid[1].snapshot.session_id: return Codec.failure("SAVE_DIVERGED")
        if valid[0].snapshot.revision == valid[1].snapshot.revision and valid[0].checksum != valid[1].checksum: return Codec.failure("SAVE_DIVERGED")
        if valid[1].snapshot.revision > valid[0].snapshot.revision: valid.reverse()
    var chosen: Dictionary = valid[0]
    return {"ok": true, "found": true, "snapshot": chosen.snapshot, "checksum": chosen.checksum,
        "selected_file": chosen.file, "recovered": not damaged.is_empty(),
        "recovery": {"selected_revision": chosen.snapshot.revision, "damaged_files": damaged} if not damaged.is_empty() else {},
        "ignored_pending": FileAccess.file_exists(_root.path_join("pending.json"))}

func load_snapshot() -> Dictionary:
    var error := _acquire()
    if not error.is_empty(): return Codec.failure(error)
    var result := _scan()
    if result.ok:
        _observed_recovery = result.checksum if result.recovered else ""
    if not _release(): return Codec.failure("SAVE_LOCK_FAILED")
    return result

# 하위 테스트 클래스는 이 지점에서 실패 또는 프로세스 중단을 주입할 수 있다.
func _checkpoint(_stage: String) -> String:
    return ""

func _preserve(name: String) -> String:
    var source := _root.path_join(name)
    var directory_path := _root.path_join("preserved")
    if FileAccess.file_exists(directory_path): return "SAVE_PRESERVE_FAILED"
    if DirAccess.make_dir_recursive_absolute(directory_path) != OK: return "SAVE_PRESERVE_FAILED"
    var hash := FileAccess.get_sha256(source)
    if hash.is_empty(): return "SAVE_PRESERVE_FAILED"
    var target := directory_path.path_join(name + "." + hash + ".bad")
    if not FileAccess.file_exists(target):
        var original := FileAccess.open(source, FileAccess.READ)
        if original == null: return "SAVE_PRESERVE_FAILED"
        var bytes := original.get_buffer(original.get_length())
        var read_error := original.get_error()
        original.close()
        if read_error != OK: return "SAVE_PRESERVE_FAILED"
        var preserved := FileAccess.open(target, FileAccess.WRITE)
        if preserved == null: return "SAVE_PRESERVE_FAILED"
        var stored := preserved.store_buffer(bytes)
        preserved.flush()
        var write_error := preserved.get_error()
        preserved.close()
        if not stored or write_error != OK: return "SAVE_PRESERVE_FAILED"
    if FileAccess.get_sha256(target) != hash: return "SAVE_PRESERVE_FAILED"
    return ""

func commit(candidate: Dictionary, expected_revision: int) -> Dictionary:
    var error := _acquire()
    if not error.is_empty(): return Codec.failure(error)
    var result := _commit(candidate, expected_revision)
    if not _release(): return Codec.failure("COMMIT_UNCERTAIN" if result.ok else result.error)
    return result

func _commit(candidate: Dictionary, expected_revision: int) -> Dictionary:
    var encoded: Dictionary = _codec.encode(candidate)
    if not encoded.ok: return encoded
    var loaded := _scan()
    if not loaded.ok: return loaded
    var revision: int = loaded.snapshot.revision if loaded.found else -1
    if revision != expected_revision: return Codec.failure("SAVE_CONFLICT")
    if candidate.revision != expected_revision + 1: return Codec.failure("SAVE_REVISION_INVALID")
    if loaded.found and candidate.session_id != loaded.snapshot.session_id: return Codec.failure("SAVE_CONFLICT")
    if loaded.recovered and _observed_recovery != loaded.checksum: return Codec.failure("RECOVERY_REQUIRED")
    var target: String = SLOTS[1] if loaded.found and loaded.selected_file == SLOTS[0] else SLOTS[0]
    var temporary := _root.path_join("pending.json")
    var injected := _checkpoint("before_write")
    if not injected.is_empty(): return Codec.failure(injected)
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null: return Codec.failure("SAVE_WRITE_FAILED")
    var stored := file.store_string(encoded.text)
    file.flush()
    var error := file.get_error()
    file.close()
    if not stored or error != OK: return Codec.failure("SAVE_WRITE_FAILED")
    injected = _checkpoint("after_write")
    if not injected.is_empty(): return Codec.failure(injected)
    var verified := _read("pending.json")
    if not verified.ok or not verified.found or verified.checksum != encoded.checksum: return Codec.failure("SAVE_VERIFY_FAILED")
    injected = _checkpoint("after_verify")
    if not injected.is_empty(): return Codec.failure(injected)
    if loaded.recovered:
        for damaged in loaded.recovery.damaged_files:
            error = OK
            var preserve_error := _preserve(damaged.file)
            if not preserve_error.is_empty(): return Codec.failure(preserve_error)
    injected = _checkpoint("after_preserve")
    if not injected.is_empty(): return Codec.failure(injected)
    var target_path := _root.path_join(target)
    if FileAccess.file_exists(target_path) and DirAccess.remove_absolute(target_path) != OK: return Codec.failure("SAVE_REPLACE_FAILED")
    injected = _checkpoint("after_remove_target")
    if not injected.is_empty(): return Codec.failure(injected)
    if DirAccess.rename_absolute(temporary, target_path) != OK: return Codec.failure("SAVE_REPLACE_FAILED")
    injected = _checkpoint("after_publish")
    if not injected.is_empty(): return Codec.failure("COMMIT_UNCERTAIN")
    verified = _read(target)
    if not verified.ok or not verified.found or verified.checksum != encoded.checksum: return Codec.failure("COMMIT_UNCERTAIN")
    _observed_recovery = ""
    return {"ok": true}
