extends SceneTree
## 서버가 발급한 시드와 전체 행동을 고정 규칙으로 다시 실행한다.
const Session = preload("res://scripts/core/game_session.gd")
const Repository = preload("res://scripts/core/memory_save_repository.gd")
const LowSingleConfig = preload("res://data/piece_generator_low_single.tres")
const ClassicConfig = preload("res://data/piece_generator_default.tres")
const NUMERIC_FIELDS := ["event_id", "batch_id", "slot", "x", "y", "segment", "source", "target"]
const ALLOWED_ACTIONS := ["PLACE", "CLEAR", "SET_AUTO", "SET_SEGMENT_STYLE", "SET_SEGMENT_PART", "SET_REPRESENTATIVE", "COPY_SEGMENT_APPEARANCE"]

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 2:
        quit(2)
        return
    var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    var result := _replay(input)
    var file := FileAccess.open(args[1], FileAccess.WRITE)
    if file == null:
        quit(3)
        return
    file.store_string(JSON.stringify(result))
    file.flush()
    file.close()
    quit(0 if result.ok else 1)

func _replay(input: Variant) -> Dictionary:
    if typeof(input) != TYPE_DICTIONARY or input.size() not in [3,4]:
        return {"ok": false, "error": "INVALID_TRACE"}
    if not input.has("session_id") or not input.has("seed") or not input.has("actions"):
        return {"ok": false, "error": "INVALID_TRACE"}
    if typeof(input.session_id) != TYPE_STRING or typeof(input.seed) != TYPE_STRING or typeof(input.actions) != TYPE_ARRAY:
        return {"ok": false, "error": "INVALID_TRACE"}
    if input.has("supply_profile") and typeof(input.supply_profile) != TYPE_STRING:
        return {"ok": false, "error": "INVALID_TRACE"}
    var profile: String = input.get("supply_profile","classic")
    if profile not in ["classic","reduced_single"]:
        return {"ok": false, "error": "UNKNOWN_SUPPLY_PROFILE"}
    if input.actions.size() > 20000:
        return {"ok": false, "error": "TRACE_TOO_LONG"}
    var config: Resource = LowSingleConfig if profile == "reduced_single" else ClassicConfig
    var started := Session.start(Repository.new(), input.session_id, input.seed, config)
    if not started.ok:
        return {"ok": false, "error": started.error}
    var session: RefCounted = started.session
    for i in range(input.actions.size()):
        var action: Variant = input.actions[i]
        if typeof(action) != TYPE_DICTIONARY or action.get("type", "") not in ALLOWED_ACTIONS:
            return {"ok": false, "error": "INVALID_ACTION", "index": i}
        if action.get("session_id", "") != input.session_id:
            return {"ok": false, "error": "SESSION_MISMATCH", "index": i}
        var converted: Dictionary = action.duplicate(true)
        for key in NUMERIC_FIELDS:
            if not converted.has(key): continue
            var raw: Variant = converted[key]
            if typeof(raw) != TYPE_STRING or raw.is_empty() or raw.length() > 16 or not raw.is_valid_int():
                return {"ok": false, "error": "INVALID_NUMBER", "index": i}
            if raw.begins_with("-") or (raw.length() > 1 and raw.begins_with("0")):
                return {"ok": false, "error": "INVALID_NUMBER", "index": i}
            converted[key] = raw.to_int()
        var applied: Dictionary = session.dispatch(converted)
        if not applied.ok:
            return {"ok": false, "error": applied.error, "index": i}
    var state: Dictionary = session.snapshot()
    var growth: Dictionary = state.growth
    var representative: int = growth.representative_segment
    var key := str(representative)
    var material: String = growth.segment_styles.get(key, "wood") if representative > 0 else ""
    var parts: Array = growth.segment_parts.get(key, []) if representative > 0 and material == "brick" else []
    return {"ok": true, "revision": state.revision, "floor_count": growth.total_floors,
        "tower": {"total_floors": growth.total_floors, "representative_segment": representative,
            "material": material, "parts": parts}}
