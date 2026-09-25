extends RefCounted
## Android 커널 잠금은 프로세스 종료 시 해제된다. 잠금 파일 자체는 삭제하지 않는다.
static var _held: Dictionary = {}
var _bridge: Object
var _file: Object
var _channel: Object
var _lock: Object
var _key := ""

func acquire(path: String) -> String:
    if not _key.is_empty(): return "SAVE_BUSY"
    if OS.get_name() != "Android" or not Engine.has_singleton("JavaClassWrapper"):
        return "SAVE_PROCESS_CHECK_FAILED"
    _bridge = Engine.get_singleton("JavaClassWrapper")
    # wrap()은 마지막 Java 호출 예외를 초기화하지 않는다. 반환값만 검사한다.
    var file_class: Object = _bridge.wrap("java.io.File")
    if file_class == null: return "SAVE_LOCK_FAILED"
    var canonical_file: Object = file_class.File(path)
    if _exception() or canonical_file == null: return "SAVE_LOCK_FAILED"
    var canonical: Variant = canonical_file.getCanonicalPath()
    if _exception() or typeof(canonical) != TYPE_STRING or canonical.is_empty(): return "SAVE_LOCK_FAILED"
    # 같은 프로세스에서 두 번째 채널을 열고 닫으면 기존 POSIX 잠금까지 풀릴 수 있다.
    # 따라서 canonical 경로를 예약한 뒤에만 파일 채널을 생성한다.
    if _held.has(canonical): return "SAVE_BUSY"
    _key = canonical
    _held[_key] = true
    var random_file_class: Object = _bridge.wrap("java.io.RandomAccessFile")
    if random_file_class == null: return _failed("SAVE_LOCK_FAILED")
    _file = random_file_class.RandomAccessFile(_key, "rw")
    if _exception() or _file == null: return _failed("SAVE_LOCK_FAILED")
    _channel = _file.getChannel()
    if _exception() or _channel == null: return _failed("SAVE_LOCK_FAILED")
    # JavaClassWrapper의 실제 FileChannel 구현은 3인자 overload를 노출한다.
    # 모든 협력 writer가 같은 첫 바이트를 배타적으로 잠근다.
    _lock = _channel.tryLock(0, 1, false)
    if _exception(): return _failed("SAVE_LOCK_FAILED")
    if _lock == null: return _failed("SAVE_BUSY")
    return ""

func _exception() -> bool:
    return _bridge.get_exception() != null

func _failed(error: String) -> String:
    return error if release() else "SAVE_LOCK_FAILED"

func release() -> bool:
    if _key.is_empty(): return true
    var ok := true
    if _lock != null:
        _lock.release()
        ok = not _exception()
    if _file != null:
        _file.close()
        ok = not _exception() and ok
    if not ok:
        # 닫힘 여부가 불명확하면 같은 프로세스에서 재진입하지 않는다.
        return false
    _lock = null
    _channel = null
    _file = null
    _held.erase(_key)
    _key = ""
    return true

static func owner_status(pid: int) -> int:
    if pid <= 0 or pid > 2147483647: return -1
    if OS.get_name() != "Android" or not Engine.has_singleton("JavaClassWrapper"): return -1
    var bridge: Object = Engine.get_singleton("JavaClassWrapper")
    var android_os: Object = bridge.wrap("android.system.Os")
    if android_os == null: return -1
    android_os.kill(pid, 0)
    var error: Object = bridge.get_exception()
    if error == null: return 1
    # 오류 문구나 /proc 가시성으로 생존 여부를 추측하지 않는다.
    var constants: Object = bridge.wrap("android.system.OsConstants")
    if constants == null: return -1
    # JavaObject는 인스턴스 필드를 Godot property로 노출하지 않는다.
    # 공개 Android SDK 필드만 reflection으로 읽는다(hidden API 아님).
    var java_class: Object = bridge.wrap("java.lang.Class")
    if java_class == null: return -1
    var error_class: Object = java_class.forName("android.system.ErrnoException")
    if bridge.get_exception() != null or error_class == null: return -1
    var errno_field: Object = error_class.getField("errno")
    if bridge.get_exception() != null or errno_field == null: return -1
    var errno_value: Variant = errno_field.getInt(error)
    if bridge.get_exception() != null or typeof(errno_value) != TYPE_INT: return -1
    if errno_value == constants.get("ESRCH"): return 0
    if errno_value == constants.get("EPERM"): return 1
    return -1
