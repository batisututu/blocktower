extends RefCounted
## 온라인 도전의 행동 기록을 두 세대 파일로 커밋한다. 개인 저장과 분리한다.
const Session = preload("res://scripts/core/game_session.gd")
const MemoryRepository = preload("res://scripts/core/memory_save_repository.gd")
const FIELDS := ["event_id", "batch_id", "slot", "x", "y", "segment", "source", "target"]
const MAX_TRACE_BYTES := 1800000
var _root := ""
var _challenge_id := ""
var _seed := ""
var _actions: Array = []
var _staged: Dictionary = {}

static func open(challenge: Dictionary) -> Dictionary:
    var id: Variant = challenge.get("challenge_id", "")
    var seed: Variant = challenge.get("seed", "")
    if typeof(id) != TYPE_STRING or id.length() != 32:
        return {"ok": false, "error": "INVALID_CHALLENGE"}
    for character in id:
        if character not in "0123456789abcdef": return {"ok": false, "error": "INVALID_CHALLENGE"}
    if typeof(seed) != TYPE_STRING or seed.is_empty() or not seed.is_valid_int():
        return {"ok": false, "error": "INVALID_CHALLENGE"}
    var repo := new()
    repo._challenge_id = id
    repo._seed = seed
    repo._root = ProjectSettings.globalize_path("user://phase4_challenges/"+id)
    if DirAccess.make_dir_recursive_absolute(repo._root) != OK:
        return {"ok": false, "error": "SAVE_DIRECTORY_FAILED"}
    return {"ok": true, "repository": repo}

func actions() -> Array:
    return _actions.duplicate(true)

func stage_action(action: Dictionary) -> Dictionary:
    if action.get("type", "") == "NEW_RUN":
        return {"ok": false, "error": "ONLINE_NEW_RUN_DISABLED"}
    var wire := action.duplicate(true)
    for key in FIELDS:
        if wire.has(key): wire[key] = str(wire[key])
    _staged = wire
    return {"ok": true}

func _slot(revision: int) -> String:
    return _root.path_join("trace_a.json" if revision%2 == 0 else "trace_b.json")

func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {"ok": true, "found": false}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return {"ok": false, "error": "SAVE_READ_FAILED"}
    var length := file.get_length()
    if length > MAX_TRACE_BYTES:
        file.close()
        return {"ok": false, "error": "TRACE_TOO_LARGE"}
    var text := file.get_as_text()
    file.close()
    var parser := JSON.new()
    if parser.parse(text) != OK: return {"ok": false, "error": "TRACE_CORRUPT"}
    var envelope: Variant = parser.data
    if typeof(envelope) != TYPE_DICTIONARY or envelope.size() != 3 or not envelope.has("format") or not envelope.has("payload") or not envelope.has("checksum"):
        return {"ok": false, "error": "TRACE_CORRUPT"}
    if envelope.format != "bt_online_trace_v1" or typeof(envelope.payload) != TYPE_STRING or typeof(envelope.checksum) != TYPE_STRING:
        return {"ok": false, "error": "TRACE_CORRUPT"}
    if envelope.payload.sha256_text() != envelope.checksum or JSON.stringify(envelope,"",true) != text:
        return {"ok": false, "error": "TRACE_CORRUPT"}
    if parser.parse(envelope.payload) != OK: return {"ok": false, "error": "TRACE_CORRUPT"}
    var payload: Variant = parser.data
    if typeof(payload) != TYPE_DICTIONARY or payload.size() != 4 or payload.get("challenge_id","") != _challenge_id or payload.get("seed","") != _seed or typeof(payload.get("actions")) != TYPE_ARRAY:
        return {"ok": false, "error": "TRACE_CORRUPT"}
    var revision: Variant = payload.get("revision", "")
    if typeof(revision) != TYPE_STRING or not revision.is_valid_int() or revision.to_int() != payload.actions.size() or revision.to_int() > 20000:
        return {"ok": false, "error": "TRACE_CORRUPT"}
    return {"ok": true, "found": true, "revision": revision.to_int(), "actions": payload.actions}

func load_snapshot() -> Dictionary:
    var candidates: Array = []
    var damaged := false
    for slot in ["trace_a.json", "trace_b.json"]:
        var read := _read(_root.path_join(slot))
        if not read.ok:
            damaged = true
            continue
        if read.found: candidates.append(read)
    if candidates.is_empty():
        return {"ok": false, "error": "TRACE_CORRUPT"} if damaged else {"ok": true, "found": false}
    candidates.sort_custom(func(a,b): return a.revision > b.revision)
    for candidate in candidates:
        var started := Session.start(MemoryRepository.new(), _challenge_id, _seed)
        if not started.ok: return started
        var replay: RefCounted = started.session
        var valid := true
        for item in candidate.actions:
            if typeof(item) != TYPE_DICTIONARY:
                valid = false
                break
            var action: Dictionary = item.duplicate(true)
            for key in FIELDS:
                if not action.has(key): continue
                if typeof(action[key]) != TYPE_STRING or not action[key].is_valid_int():
                    valid = false
                    break
                action[key] = action[key].to_int()
            if not valid: break
            var result: Dictionary = replay.dispatch(action)
            if not result.ok:
                valid = false
                break
        if valid:
            _actions = candidate.actions.duplicate(true)
            return {"ok": true, "found": true, "snapshot": replay.snapshot(), "recovered": damaged}
        damaged = true
    return {"ok": false, "error": "TRACE_CORRUPT"}

func commit(candidate: Dictionary, expected_revision: int) -> Dictionary:
    if candidate.get("session_id", "") != _challenge_id or (expected_revision == -1 and not _actions.is_empty()) or (expected_revision >= 0 and expected_revision != _actions.size()):
        return {"ok": false, "error": "SAVE_CONFLICT"}
    var next_actions := _actions.duplicate(true)
    if expected_revision >= 0:
        if _staged.is_empty() or _staged.get("event_id", "") != str(expected_revision+1):
            return {"ok": false, "error": "ACTION_NOT_STAGED"}
        next_actions.append(_staged.duplicate(true))
    if candidate.revision != next_actions.size(): return {"ok": false, "error": "SAVE_CONFLICT"}
    var payload := JSON.stringify({"challenge_id":_challenge_id,"seed":_seed,"revision":str(candidate.revision),"actions":next_actions},"",true)
    var text := JSON.stringify({"format":"bt_online_trace_v1","payload":payload,"checksum":payload.sha256_text()},"",true)
    if text.to_utf8_buffer().size() > MAX_TRACE_BYTES: return {"ok": false, "error": "TRACE_TOO_LARGE"}
    var file := FileAccess.open(_slot(candidate.revision),FileAccess.WRITE)
    if file == null: return {"ok": false, "error": "SAVE_FAILED"}
    file.store_string(text)
    file.flush()
    var error := file.get_error()
    file.close()
    if error != OK: return {"ok": false, "error": "SAVE_FAILED"}
    _actions = next_actions
    _staged = {}
    return {"ok": true}
