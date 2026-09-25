extends RefCounted
## 후보 계산 → 전체 커밋 → 메모리 확정 → 연출 사건 반환의 순서를 지킨다.
const Generator = preload("res://scripts/core/generation/piece_generator.gd")
const Growth = preload("res://scripts/core/growth_rules.gd")
const MAX_COUNTER := 9000000000000000
const STATE_KEYS := ["schema_version", "rule_version", "session_id", "revision", "last_event_id", "run_id",
    "occupancy", "cell_style", "queue", "batch_id", "batch_success", "streak", "best_streak", "score", "best",
    "auto_clear", "growth", "checkpoint"]
const LEGACY_STATE_KEYS := ["schema_version", "rule_version", "session_id", "revision", "last_event_id", "run_id",
    "occupancy", "cell_style", "queue", "batch_id", "batch_success", "streak", "best_streak", "score", "best",
    "auto_clear", "growth", "checkpoint"]
const GROWTH_KEYS := ["total_floors", "brick_lines", "metal_lines", "crystal_lines", "representative_segment", "segment_styles", "segment_parts"]
const LEGACY_GROWTH_KEYS := ["total_floors", "brick_lines", "metal_lines", "crystal_lines", "representative_segment", "segment_styles"]
const ACTION_FIELDS := {
    "PLACE": ["batch_id", "slot", "x", "y"], "CLEAR": [], "SET_AUTO": ["enabled", "confirmed"],
    "NEW_RUN": ["seed_text", "confirmed"], "SET_SEGMENT_STYLE": ["segment", "material"],
    "SET_SEGMENT_PART": ["segment", "part", "enabled"], "SET_REPRESENTATIVE": ["segment"],
    "COPY_SEGMENT_APPEARANCE": ["source", "target", "confirmed"]}
var _state: Dictionary = {}
var _repository: RefCounted
var _generator: RefCounted
var _pieces: Dictionary = {}
var _busy := false
var _requires_resume := false

static func _error(code: String) -> Dictionary:
    return {"ok": false, "error": code, "events": []}

static func _counter(value: Variant, minimum: int = 0) -> bool:
    return typeof(value) == TYPE_INT and value >= minimum and value <= MAX_COUNTER

static func _keys(value: Variant, keys: Array) -> bool:
    return typeof(value) == TYPE_DICTIONARY and value.size() == keys.size() and keys.all(func(k): return value.has(k))

static func _construct(repository: Variant, config: Variant) -> Dictionary:
    if not repository is RefCounted or not repository.has_method("load_snapshot") or not repository.has_method("commit"):
        return _error("INVALID_REPOSITORY")
    var created := Generator.create(config)
    if not created.ok: return _error(created.error)
    var instance = new()
    instance._repository = repository
    instance._generator = created.generator
    for piece in instance._generator.catalog(): instance._pieces[piece.id] = piece
    return {"ok": true, "session": instance}

static func start(repository: Variant, session_id: Variant, seed_text: Variant, config: Variant = null) -> Dictionary:
    var made := _construct(repository, config)
    if not made.ok: return made
    var loaded: Dictionary = repository.load_snapshot()
    if not loaded.ok: return _error(loaded.error)
    if loaded.found: return _error("SAVE_ALREADY_EXISTS")
    if typeof(session_id) != TYPE_STRING or session_id.is_empty() or session_id.length() > 128:
        return _error("INVALID_SESSION_ID")
    var s = made.session
    var initialized: Dictionary = s._generator.initial_checkpoint(seed_text)
    if not initialized.ok: return _error(initialized.error)
    var b := PackedByteArray()
    b.resize(64)
    s._state = {"schema_version": "bt_session_v2", "rule_version": "bt_rules_v1", "session_id": session_id,
        "revision": 0, "last_event_id": 0, "run_id": 1, "occupancy": b, "cell_style": b.duplicate(),
        "queue": [], "batch_id": 1, "batch_success": false, "streak": 0, "best_streak": 0,
        "score": 0, "best": 0, "auto_clear": false, "growth": Growth.initial(), "checkpoint": initialized.checkpoint}
    s._state.growth.segment_parts = {}
    var error: String = s._refill(s._state)
    if not error.is_empty(): return _error(error)
    error = s._validate_state(s._state)
    if not error.is_empty(): return _error(error)
    var saved: Dictionary = repository.commit(s._state.duplicate(true), -1)
    if not saved.ok: return _error(saved.error)
    return made

static func resume(repository: Variant, config: Variant = null) -> Dictionary:
    var made := _construct(repository, config)
    if not made.ok: return made
    var loaded: Dictionary = repository.load_snapshot()
    if not loaded.ok: return _error(loaded.error)
    if not loaded.found: return _error("SAVE_NOT_FOUND")
    var s = made.session
    var resumed_state: Dictionary = loaded.snapshot.duplicate(true)
    if typeof(resumed_state) == TYPE_DICTIONARY and resumed_state.get("schema_version", "") == "bt_session_v1":
        if not _keys(resumed_state, LEGACY_STATE_KEYS) or not _keys(resumed_state.get("growth"), LEGACY_GROWTH_KEYS):
            return _error("INVALID_STATE")
        resumed_state.schema_version = "bt_session_v2"
        resumed_state.growth.segment_parts = {}
    var error: String = s._validate_state(resumed_state)
    if not error.is_empty(): return _error(error)
    s._state = resumed_state
    made["recovered"] = loaded.get("recovered", false)
    made["recovery"] = loaded.get("recovery", {})
    return made

static func validate_snapshot(state: Variant, config: Variant = null) -> Dictionary:
    var created := Generator.create(config)
    if not created.ok: return _error(created.error)
    var validator = new()
    validator._generator = created.generator
    for piece in validator._generator.catalog(): validator._pieces[piece.id] = piece
    var error: String = validator._validate_state(state)
    return {"ok": true} if error.is_empty() else _error(error)

func snapshot() -> Dictionary:
    return _state.duplicate(true)

func view() -> Dictionary:
    var result := _analysis(_state)
    result["growth"] = Growth.describe(_state.growth)
    result["clear_lines"] = result.pending_rows.size() + result.pending_columns.size()
    result["clear_points"] = clear_points(result.clear_lines)
    return result

static func clear_points(lines: int) -> int:
    return 0 if lines <= 0 else lines * [100, 120, 140, 160][mini(lines, 4) - 1]

func piece_for_slot(slot: int) -> Dictionary:
    if slot < 0 or slot >= 3 or _state.queue[slot].is_empty(): return {}
    return _pieces[_state.queue[slot]].duplicate(true)

func preview_placement(slot: int, x: int, y: int) -> Dictionary:
    return _placement(_state, slot, x, y)

func _placement(state: Dictionary, slot: int, x: int, y: int) -> Dictionary:
    if slot < 0 or slot >= 3: return _error("INVALID_SLOT")
    if state.queue[slot].is_empty(): return _error("SLOT_CONSUMED")
    var piece: Dictionary = _pieces[state.queue[slot]]
    if x < 0 or y < 0 or x > 8 - piece.width or y > 8 - piece.height: return _error("OUT_OF_BOUNDS")
    var cells: Array[int] = []
    for cell in piece.cells:
        var index: int = (y + cell.y) * 8 + x + cell.x
        if state.occupancy[index] != 0: return _error("OCCUPIED")
        cells.append(index)
    cells.sort()
    return {"ok": true, "cells": cells}

func _remaining(state: Dictionary) -> Array:
    return state.queue.filter(func(id): return not id.is_empty())

func _analysis(state: Dictionary) -> Dictionary:
    var result: Dictionary = _generator.analyze_tray(state.occupancy, _remaining(state))
    if not result.witness.is_empty():
        var live_slots: Array[int] = []
        for slot in range(3):
            if not state.queue[slot].is_empty(): live_slots.append(slot)
        result.witness.slot = live_slots[result.witness.slot]
    return result

func _validate_state(state: Variant) -> String:
    if not _keys(state, STATE_KEYS): return "INVALID_STATE"
    if state.schema_version != "bt_session_v2" or state.rule_version != "bt_rules_v1": return "UNSUPPORTED_VERSION"
    if typeof(state.session_id) != TYPE_STRING or state.session_id.is_empty() or state.session_id.length() > 128: return "INVALID_STATE"
    for key in ["revision", "last_event_id", "streak", "best_streak", "score", "best"]:
        if not _counter(state[key]): return "INVALID_STATE"
    for key in ["run_id", "batch_id"]:
        if not _counter(state[key], 1): return "INVALID_STATE"
    if state.revision != state.last_event_id or state.best < state.score or state.best_streak < state.streak: return "INVALID_STATE"
    if typeof(state.auto_clear) != TYPE_BOOL or typeof(state.batch_success) != TYPE_BOOL: return "INVALID_STATE"
    if typeof(state.occupancy) != TYPE_PACKED_BYTE_ARRAY or state.occupancy.size() != 64: return "INVALID_STATE"
    if typeof(state.cell_style) != TYPE_PACKED_BYTE_ARRAY or state.cell_style.size() != 64: return "INVALID_STATE"
    for i in range(64):
        if state.occupancy[i] > 1: return "INVALID_STATE"
        if state.occupancy[i] == 0 and state.cell_style[i] != 0: return "INVALID_STATE"
        if state.occupancy[i] == 1 and (state.cell_style[i] < 1 or state.cell_style[i] > 13): return "INVALID_STATE"
    if typeof(state.queue) != TYPE_ARRAY or state.queue.size() != 3: return "INVALID_STATE"
    for id in state.queue:
        if typeof(id) != TYPE_STRING or (not id.is_empty() and not _pieces.has(id)): return "INVALID_STATE"
    if _remaining(state).is_empty(): return "INVALID_STATE"
    if not _keys(state.growth, GROWTH_KEYS): return "INVALID_STATE"
    var growth: Dictionary = state.growth
    for key in GROWTH_KEYS:
        if key not in ["segment_styles", "segment_parts"] and not _counter(growth[key]): return "INVALID_STATE"
    if growth.crystal_lines > growth.metal_lines or growth.metal_lines > growth.brick_lines or growth.brick_lines > growth.total_floors: return "INVALID_STATE"
    var total_segments: int = growth.total_floors / 10
    if total_segments == 0 and growth.representative_segment != 0: return "INVALID_STATE"
    if total_segments > 0 and (growth.representative_segment == 0 or growth.representative_segment > total_segments): return "INVALID_STATE"
    if typeof(growth.segment_styles) != TYPE_DICTIONARY: return "INVALID_STATE"
    var available: Array = Growth.describe(growth).materials
    for key in growth.segment_styles:
        var parsed := Generator.parse_int64(key)
        if not parsed.ok or parsed.value < 1 or parsed.value > total_segments: return "INVALID_STATE"
        if typeof(growth.segment_styles[key]) != TYPE_STRING or growth.segment_styles[key] not in available: return "INVALID_STATE"
    if typeof(growth.segment_parts) != TYPE_DICTIONARY: return "INVALID_STATE"
    var unlocked_parts: Array = Growth.describe(growth).parts
    for key in growth.segment_parts:
        var parsed_part_segment := Generator.parse_int64(key)
        if not parsed_part_segment.ok or str(parsed_part_segment.value) != key or parsed_part_segment.value < 1 or parsed_part_segment.value > total_segments: return "INVALID_STATE"
        var equipped: Variant = growth.segment_parts[key]
        if typeof(equipped) != TYPE_ARRAY or equipped.is_empty() or equipped.size() > 4: return "INVALID_STATE"
        var previous := ""
        for part_id in equipped:
            if typeof(part_id) != TYPE_STRING or part_id not in ["brick_arch_window", "brick_terrace", "brick_cornice", "brick_landmark"] or part_id == previous: return "INVALID_STATE"
            if not previous.is_empty() and part_id <= previous: return "INVALID_STATE"
            if part_id not in unlocked_parts: return "INVALID_STATE"
            previous = part_id
    if typeof(state.checkpoint) != TYPE_DICTIONARY or not state.checkpoint.has("rng_seed") or not state.checkpoint.has("rng_state"): return "INVALID_STATE"
    var initial: Dictionary = _generator.initial_checkpoint(state.checkpoint.rng_seed)
    if not initial.ok or not Generator.parse_int64(state.checkpoint.rng_state).ok: return "INVALID_STATE"
    initial.checkpoint.rng_state = state.checkpoint.rng_state
    if initial.checkpoint != state.checkpoint: return "CHECKPOINT_VERSION_MISMATCH"
    var analysis := _analysis(state)
    if state.auto_clear and (not analysis.pending_rows.is_empty() or not analysis.pending_columns.is_empty()): return "INVALID_STATE"
    if analysis.status == "GAME_OVER" and state.streak != 0: return "INVALID_STATE"
    return ""

func dispatch(action: Variant) -> Dictionary:
    if _busy: return _error("BUSY")
    if _requires_resume: return _error("RECOVERY_REQUIRED")
    _busy = true
    var result := _dispatch(action)
    _busy = false
    return result

func _dispatch(action: Variant) -> Dictionary:
    if typeof(action) != TYPE_DICTIONARY or not action.has("type") or typeof(action.type) != TYPE_STRING or not ACTION_FIELDS.has(action.type): return _error("INVALID_ACTION")
    var keys: Array = ["type", "session_id", "event_id"] + ACTION_FIELDS[action.type]
    if not _keys(action, keys): return _error("INVALID_ACTION")
    if typeof(action.session_id) != TYPE_STRING or action.session_id != _state.session_id: return _error("SESSION_MISMATCH")
    if not _counter(action.event_id, 1): return _error("INVALID_ACTION")
    if action.event_id <= _state.last_event_id:
        var duplicate := _error("ALREADY_APPLIED")
        duplicate["snapshot"] = snapshot()
        return duplicate
    if action.event_id != _state.last_event_id + 1: return _error("EVENT_OUT_OF_ORDER")
    if action.type in ["PLACE", "CLEAR"] and _analysis(_state).status == "GAME_OVER": return _error("GAME_OVER")
    var candidate := _state.duplicate(true)
    var events: Array = []
    var error := _reduce(candidate, action, events)
    if not error.is_empty(): return _error(error)
    candidate.revision += 1
    candidate.last_event_id = action.event_id
    candidate.best = maxi(candidate.best, candidate.score)
    if _analysis(candidate).status == "GAME_OVER":
        candidate.streak = 0
        if _analysis(_state).status != "GAME_OVER": events.append({"type": "GAME_OVER"})
    error = _validate_state(candidate)
    if not error.is_empty(): return _error(error)
    if _repository.has_method("stage_action"):
        var staged: Dictionary = _repository.stage_action(action.duplicate(true))
        if not staged.ok: return _error(staged.error)
    var saved: Dictionary = _repository.commit(candidate.duplicate(true), _state.revision)
    if not saved.ok:
        if saved.error in ["COMMIT_UNCERTAIN", "SAVE_CONFLICT", "RECOVERY_REQUIRED"]: _requires_resume = true
        return _error(saved.error)
    _state = candidate
    return {"ok": true, "snapshot": snapshot(), "events": events}

func _refill(state: Dictionary) -> String:
    var result: Dictionary = _generator.generate(state.occupancy, [], state.checkpoint)
    if not result.ok: return result.error
    state.queue = result.piece_ids
    state.checkpoint = result.checkpoint
    return ""

func _clear(state: Dictionary, events: Array) -> void:
    var analysis := _analysis(state)
    var lines: int = analysis.pending_rows.size() + analysis.pending_columns.size()
    if lines == 0: return
    var cells: Array[int] = []
    var styles: Array[int] = []
    for i in range(64):
        if state.occupancy[i] != 0 and analysis.post_clear[i] == 0:
            cells.append(i)
            styles.append(state.cell_style[i])
    var points := clear_points(lines)
    state.score += points
    state.occupancy = analysis.post_clear
    for i in range(64):
        if state.occupancy[i] == 0: state.cell_style[i] = 0
    var growth := Growth.award(state.growth, lines)
    events.append({"type": "CLEARED", "lines": lines, "points": points, "floors": lines,
        "rows": analysis.pending_rows.duplicate(), "columns": analysis.pending_columns.duplicate(), "cells": cells, "styles": styles,
        "new_segments": growth.new_segments, "materials": growth.materials, "parts": growth.parts})

func _reduce(state: Dictionary, action: Dictionary, events: Array) -> String:
    match action.type:
        "PLACE":
            for key in ["batch_id", "slot", "x", "y"]:
                if typeof(action[key]) != TYPE_INT: return "INVALID_ACTION"
            if action.batch_id != state.batch_id: return "STALE_BATCH"
            var placement := _placement(state, action.slot, action.x, action.y)
            if not placement.ok: return placement.error
            var piece: Dictionary = _pieces[state.queue[action.slot]]
            var before := _analysis(state)
            for cell in piece.cells:
                var i: int = (action.y + cell.y) * 8 + action.x + cell.x
                state.occupancy[i] = 1
                state.cell_style[i] = piece.family_index + 1
            state.queue[action.slot] = ""
            state.score += piece.cells.size()
            var after := _analysis(state)
            if after.pending_rows.size() + after.pending_columns.size() > before.pending_rows.size() + before.pending_columns.size(): state.batch_success = true
            events.append({"type": "PLACED", "slot": action.slot, "piece_id": piece.id, "x": action.x, "y": action.y, "points": piece.cells.size(), "cells": placement.cells.duplicate()})
            if state.auto_clear: _clear(state, events)
            if _remaining(state).is_empty():
                state.streak = state.streak + 1 if state.batch_success else 0
                state.best_streak = maxi(state.best_streak, state.streak)
                events.append({"type": "BATCH_SETTLED", "batch_id": state.batch_id, "success": state.batch_success, "streak": state.streak})
                state.batch_id += 1
                state.batch_success = false
                var error := _refill(state)
                if not error.is_empty(): return error
                events.append({"type": "SUPPLIED", "batch_id": state.batch_id, "piece_ids": state.queue.duplicate()})
        "CLEAR":
            if state.auto_clear: return "MANUAL_ONLY"
            var analysis := _analysis(state)
            if analysis.pending_rows.is_empty() and analysis.pending_columns.is_empty(): return "NO_LINES"
            _clear(state, events)
        "SET_AUTO":
            if typeof(action.enabled) != TYPE_BOOL or typeof(action.confirmed) != TYPE_BOOL: return "INVALID_ACTION"
            if action.enabled == state.auto_clear: return "NO_CHANGE"
            var analysis := _analysis(state)
            if action.enabled and (not analysis.pending_rows.is_empty() or not analysis.pending_columns.is_empty()):
                if not action.confirmed: return "CONFIRMATION_REQUIRED"
                _clear(state, events)
            state.auto_clear = action.enabled
            events.append({"type": "AUTO_CHANGED", "enabled": action.enabled})
        "NEW_RUN":
            if typeof(action.confirmed) != TYPE_BOOL: return "INVALID_ACTION"
            if not action.confirmed and _analysis(state).status != "GAME_OVER": return "CONFIRMATION_REQUIRED"
            var initial: Dictionary = _generator.initial_checkpoint(action.seed_text)
            if not initial.ok: return initial.error
            state.occupancy.fill(0)
            state.cell_style.fill(0)
            state.queue = []
            state.score = 0
            state.streak = 0
            state.batch_success = false
            state.run_id += 1
            state.batch_id += 1
            state.checkpoint = initial.checkpoint
            var error := _refill(state)
            if not error.is_empty(): return error
            events.append({"type": "RUN_STARTED", "run_id": state.run_id, "batch_id": state.batch_id})
        "COPY_SEGMENT_APPEARANCE":
            if not _counter(action.source,1) or not _counter(action.target,1): return "INVALID_SEGMENT"
            var completed: int = state.growth.total_floors / 10
            if action.source > completed or action.target > completed: return "INVALID_SEGMENT"
            if typeof(action.confirmed) != TYPE_BOOL: return "INVALID_ACTION"
            if not action.confirmed: return "CONFIRMATION_REQUIRED"
            if action.source == action.target: return "NO_CHANGE"
            var source_key := str(action.source)
            var target_key := str(action.target)
            var material: String = state.growth.segment_styles.get(source_key,"wood")
            var parts: Array = state.growth.segment_parts.get(source_key,[]).duplicate() if material == "brick" else []
            if state.growth.segment_styles.get(target_key,"wood") == material and state.growth.segment_parts.get(target_key,[]) == parts: return "NO_CHANGE"
            if material == "wood": state.growth.segment_styles.erase(target_key)
            else: state.growth.segment_styles[target_key] = material
            if parts.is_empty(): state.growth.segment_parts.erase(target_key)
            else: state.growth.segment_parts[target_key] = parts
            events.append({"type":"TOWER_CHANGED","segment":action.target,"copied_from":action.source})
        "SET_SEGMENT_STYLE", "SET_SEGMENT_PART", "SET_REPRESENTATIVE":
            if not _counter(action.segment, 1) or action.segment > state.growth.total_floors / 10: return "INVALID_SEGMENT"
            if action.type == "SET_REPRESENTATIVE":
                if action.segment == state.growth.representative_segment: return "NO_CHANGE"
                state.growth.representative_segment = action.segment
            elif action.type == "SET_SEGMENT_STYLE":
                if typeof(action.material) != TYPE_STRING or action.material not in Growth.describe(state.growth).materials: return "MATERIAL_LOCKED"
                var key := str(action.segment)
                if state.growth.segment_styles.get(key, "wood") == action.material: return "NO_CHANGE"
                if action.material == "wood": state.growth.segment_styles.erase(key)
                else: state.growth.segment_styles[key] = action.material
            else:
                if typeof(action.part) != TYPE_STRING or action.part not in ["brick_arch_window", "brick_terrace", "brick_cornice", "brick_landmark"] or typeof(action.enabled) != TYPE_BOOL: return "INVALID_ACTION"
                var segment_key := str(action.segment)
                var parts: Array = state.growth.segment_parts.get(segment_key, []).duplicate()
                var has_part: bool = action.part in parts
                if action.enabled == has_part: return "NO_CHANGE"
                if action.enabled:
                    if state.growth.segment_styles.get(segment_key, "wood") != "brick": return "MATERIAL_REQUIRED"
                    if action.part not in Growth.describe(state.growth).parts: return "PART_LOCKED"
                    parts.append(action.part)
                    parts.sort()
                    state.growth.segment_parts[segment_key] = parts
                else:
                    parts.erase(action.part)
                    if parts.is_empty(): state.growth.segment_parts.erase(segment_key)
                    else: state.growth.segment_parts[segment_key] = parts
            events.append({"type": "TOWER_CHANGED", "segment": action.segment})
    return ""
