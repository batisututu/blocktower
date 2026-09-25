extends RefCounted
## 실제 앱과 헤드리스 재실행 검사가 같은 파일 저장 시작 경로를 사용한다.
const Repository = preload("res://scripts/persistence/file_save_repository.gd")
const Session = preload("res://scripts/core/game_session.gd")
var _initial_id := ""
var _initial_seed := ""

func boot(directory: String = "user://save_v1", initial_id: String = "", initial_seed: String = "") -> Dictionary:
    var opened := Repository.open(directory)
    if not opened.ok: return opened
    var repository = opened.repository
    var loaded: Dictionary = repository.load_snapshot()
    if not loaded.ok: return loaded
    var result: Dictionary
    if loaded.found:
        result = Session.resume(repository)
    else:
        # 실패 후 같은 인스턴스에서 재시도할 때 초기 시드/ID를 다시 뽑지 않는다.
        if _initial_id.is_empty():
            _initial_id = initial_id if not initial_id.is_empty() else "local-" + Crypto.new().generate_random_bytes(16).hex_encode()
            var rng := RandomNumberGenerator.new()
            rng.randomize()
            _initial_seed = initial_seed if not initial_seed.is_empty() else str(rng.seed)
        result = Session.start(repository, _initial_id, _initial_seed)
        result["recovered"] = false
        result["recovery"] = {}
    if result.ok:
        result["repository"] = repository
        result["created"] = not loaded.found
    return result
