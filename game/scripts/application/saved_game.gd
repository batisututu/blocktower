extends RefCounted
## 실제 앱과 헤드리스 재실행 검사가 같은 파일 저장 시작 경로를 사용한다.
const Repository = preload("res://scripts/persistence/file_save_repository.gd")
const Session = preload("res://scripts/core/game_session.gd")
const LOW_SINGLE_CONFIG = preload("res://data/piece_generator_low_single.tres")
const CLASSIC_CONFIG = preload("res://data/piece_generator_default.tres")
var _initial_id := ""
var _initial_seed := ""

func boot(directory: String = "user://save_v1", initial_id: String = "", initial_seed: String = "") -> Dictionary:
    var config: Resource = LOW_SINGLE_CONFIG
    var opened := Repository.open(directory, config)
    if not opened.ok: return opened
    var repository = opened.repository
    var loaded: Dictionary = repository.load_snapshot()
    if not loaded.ok and loaded.error == "CHECKPOINT_VERSION_MISMATCH":
        # 기존 공급 설정의 저장은 그 설정으로 계속 읽어 재현성을 지킨다.
        var classic_opened: Dictionary = Repository.open(directory, CLASSIC_CONFIG)
        if not classic_opened.ok: return classic_opened
        var classic_loaded: Dictionary = classic_opened.repository.load_snapshot()
        if not classic_loaded.ok: return classic_loaded
        if not classic_loaded.found: return loaded
        repository = classic_opened.repository
        loaded = classic_loaded
        config = CLASSIC_CONFIG
    if not loaded.ok: return loaded
    var result: Dictionary
    if loaded.found:
        result = Session.resume(repository, config)
    else:
        # 실패 후 같은 인스턴스에서 재시도할 때 초기 시드/ID를 다시 뽑지 않는다.
        if _initial_id.is_empty():
            _initial_id = initial_id if not initial_id.is_empty() else "local-" + Crypto.new().generate_random_bytes(16).hex_encode()
            var rng := RandomNumberGenerator.new()
            rng.randomize()
            _initial_seed = initial_seed if not initial_seed.is_empty() else str(rng.seed)
        result = Session.start(repository, _initial_id, _initial_seed, config)
        result["recovered"] = false
        result["recovery"] = {}
    if result.ok:
        result["repository"] = repository
        result["created"] = not loaded.found
        result["supply_profile"] = "reduced_single" if config == LOW_SINGLE_CONFIG else "classic"
    return result
