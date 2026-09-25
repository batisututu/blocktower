extends RefCounted
## 순수 공급기. 모든 난수는 요청의 체크포인트로 복원한 지역 RNG만 사용한다.

const Config = preload("res://scripts/core/generation/piece_generator_config.gd")
const Legacy = preload("res://scripts/core/piece_supply.gd")
const DEFAULT_CONFIG = preload("res://data/piece_generator_default.tres")
const CATALOG_VERSION := "bt_catalog_29_v0_2"
const RAW := "bt_family_weighted_v0_2"
const EASY := "bt_easy_family_v0_2"
const SOFT := "bt_soft_one_move_v0_2"
const SIDE := 8
const TRAY_SIZE := 3
const MAX_WEIGHT := 1000000
const CHECKPOINT_KEYS := ["rng_seed", "rng_state", "engine_version", "catalog_version", "supply_policy_version", "definition_hash", "config_hash"]

var _families: Array = []
var _pieces: Array = []
var _lookup: Dictionary = {}
var _weights: Array[int] = []
var _easy: Array[String] = []
var _policy: String
var _max_rerolls: int
var _definition_hash: String
var _config_hash: String

static func create(config: Variant = null) -> Dictionary:
	if config == null:
		config = DEFAULT_CONFIG
	if not config is Config:
		return _error("INVALID_CONFIG_TYPE")
	var instance = new()
	var error: String = instance._configure(config)
	if not error.is_empty():
		return _error(error)
	return {"ok": true, "generator": instance}

static func _error(code: String) -> Dictionary:
	return {"ok": false, "error": code}

static func parse_int64(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 20:
		return _error("INVALID_INT64")
	var negative: bool = value.begins_with("-")
	var digits: String = value.substr(1) if negative else value
	if digits.is_empty() or (digits.length() > 1 and digits.begins_with("0")) or (negative and digits == "0"):
		return _error("INVALID_INT64")
	for index in range(digits.length()):
		var code := digits.unicode_at(index)
		if code < 48 or code > 57:
			return _error("INVALID_INT64")
	var bound := "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() > 19 or (digits.length() == 19 and digits > bound):
		return _error("INVALID_INT64")
	return {"ok": true, "value": value.to_int()}

func _configure(config: Resource) -> String:
	if config.catalog_version != CATALOG_VERSION:
		return "UNKNOWN_CATALOG"
	if config.supply_policy_version not in [RAW, EASY, SOFT]:
		return "UNKNOWN_POLICY"
	if config.max_rerolls < 0 or config.max_rerolls > 3:
		return "INVALID_REROLL_LIMIT"
	# 이전 방향 순서는 유지하고 새로운 계열을 뒤에 추가한다.
	_families = Legacy.FAMILIES.duplicate(true)
	_families.append_array([
		{"id": "t", "patterns": [["###", ".#."], [".#", "##", ".#"], [".#.", "###"], ["#.", "##", "#."]]},
		{"id": "s", "patterns": [[".##", "##."], ["#.", "##", ".#"]]},
		{"id": "z", "patterns": [["##.", ".##"], [".#", "##", "#."]]},
		{"id": "rect2x3", "patterns": [["###", "###"], ["##", "##", "##"]]}
	])
	if config.family_weights.size() != _families.size():
		return "INVALID_WEIGHT_COUNT"
	_weights.assign(config.family_weights)
	var total := Legacy.weight_total(_weights)
	if total <= 0:
		return "INVALID_WEIGHTS"
	_policy = config.supply_policy_version
	_max_rerolls = config.max_rerolls
	var requested: Dictionary = {}
	for family_id in config.easy_families:
		if requested.has(family_id):
			return "DUPLICATE_EASY_FAMILY"
		requested[family_id] = true
	var definition := PackedStringArray([CATALOG_VERSION])
	var easy_weight := 0
	for fi in range(_families.size()):
		var family: Dictionary = _families[fi]
		# 카탈로그에는 정책 가중치를 섞지 않는다.
		family.erase("weight")
		definition.append(family.id)
		if requested.has(family.id):
			_easy.append(family.id)
			easy_weight += _weights[fi]
		for vi in range(family.patterns.size()):
			var pattern: Array = family.patterns[vi]
			definition.append("/".join(PackedStringArray(pattern)))
			var cells: Array[Vector2i] = []
			var masks := PackedInt32Array()
			var width: int = pattern[0].length()
			for y in range(pattern.size()):
				var mask := 0
				for x in range(width):
					if pattern[y][x] == "#":
						cells.append(Vector2i(x, y))
						mask |= 1 << x
				masks.append(mask)
			var piece := {"id": "%s_v%d" % [family.id, vi], "family": family.id, "family_index": fi,
				"cells": cells, "width": width, "height": pattern.size(), "row_masks": masks}
			_pieces.append(piece)
			_lookup[piece.id] = piece
	if requested.size() != _easy.size():
		return "UNKNOWN_EASY_FAMILY"
	if _policy != RAW and easy_weight == 0:
		return "NO_ENABLED_EASY_FAMILY"
	_definition_hash = "\n".join(definition).sha256_text()
	_config_hash = ("%s|%s|%s|%s|%d" % [_definition_hash, _policy, str(_weights), ",".join(_easy), _max_rerolls]).sha256_text()
	return ""

func catalog() -> Array:
	return _pieces.duplicate(true)

func config_snapshot() -> Dictionary:
	return {"catalog_version": CATALOG_VERSION, "supply_policy_version": _policy,
		"family_ids": _families.map(func(f): return f.id), "family_weights": _weights.duplicate(),
		"easy_families": _easy.duplicate(), "max_rerolls": _max_rerolls,
		"definition_hash": _definition_hash, "config_hash": _config_hash}

func _checkpoint(seed_value: String, state: int) -> Dictionary:
	return {"rng_seed": seed_value, "rng_state": str(state),
		"engine_version": Engine.get_version_info().string, "catalog_version": CATALOG_VERSION,
		"supply_policy_version": _policy, "definition_hash": _definition_hash, "config_hash": _config_hash}

func initial_checkpoint(seed_text: Variant) -> Dictionary:
	var parsed := parse_int64(seed_text)
	if not parsed.ok:
		return _error("INVALID_SEED")
	var rng := RandomNumberGenerator.new()
	rng.seed = parsed.value
	return {"ok": true, "checkpoint": _checkpoint(seed_text, rng.state)}

func _validate_checkpoint(value: Variant) -> String:
	if typeof(value) != TYPE_DICTIONARY or value.size() != CHECKPOINT_KEYS.size():
		return "INVALID_CHECKPOINT"
	for key in CHECKPOINT_KEYS:
		if not value.has(key) or typeof(value[key]) != TYPE_STRING:
			return "INVALID_CHECKPOINT"
	if not parse_int64(value.rng_seed).ok or not parse_int64(value.rng_state).ok:
		return "INVALID_RNG_STATE"
	var expected := _checkpoint(value.rng_seed, 0)
	for key in ["engine_version", "catalog_version", "supply_policy_version", "definition_hash", "config_hash"]:
		if value[key] != expected[key]:
			return "CHECKPOINT_VERSION_MISMATCH"
	return ""

func _validate_board_tray(board: Variant, ids: Variant) -> String:
	if typeof(board) != TYPE_PACKED_BYTE_ARRAY or not Legacy.valid_board(board):
		return "INVALID_BOARD"
	if typeof(ids) != TYPE_ARRAY or ids.size() > TRAY_SIZE:
		return "INVALID_TRAY"
	for id in ids:
		if typeof(id) != TYPE_STRING or not _lookup.has(id):
			return "UNKNOWN_PIECE"
	return ""

func _board_context(board: PackedByteArray) -> Dictionary:
	var rows := PackedInt32Array()
	rows.resize(SIDE)
	var full_rows: Array[int] = []
	var full_columns: Array[int] = []
	for y in range(SIDE):
		for x in range(SIDE):
			rows[y] |= int(board[y * SIDE + x]) << x
		if rows[y] == 255:
			full_rows.append(y)
	for x in range(SIDE):
		var full := true
		for y in range(SIDE):
			if (rows[y] & (1 << x)) == 0:
				full = false
				break
		if full:
			full_columns.append(x)
	var post := board.duplicate()
	var post_rows := rows.duplicate()
	for y in range(SIDE):
		for x in range(SIDE):
			if y in full_rows or x in full_columns:
				post[y * SIDE + x] = 0
				post_rows[y] &= ~(1 << x)
	return {"current": rows, "after": post_rows, "post_clear": post,
		"pending_rows": full_rows, "pending_columns": full_columns,
		"has_pending": not full_rows.is_empty() or not full_columns.is_empty(), "cache": {}}

func _find_fit(rows: PackedInt32Array, piece: Dictionary) -> Dictionary:
	for y in range(SIDE - piece.height + 1):
		for x in range(SIDE - piece.width + 1):
			var fits := true
			for dy in range(piece.height):
				if (rows[y + dy] & (piece.row_masks[dy] << x)) != 0:
					fits = false
					break
			if fits:
				return {"x": x, "y": y}
	return {}

func _witness(id: String, context: Dictionary) -> Dictionary:
	if context.cache.has(id):
		return context.cache[id]
	var result := _find_fit(context.current, _lookup[id])
	if not result.is_empty():
		result["requires_clear"] = false
	elif context.has_pending:
		result = _find_fit(context.after, _lookup[id])
		if not result.is_empty():
			result["requires_clear"] = true
	context.cache[id] = result
	return result

func _decision(ids: Array, context: Dictionary) -> Dictionary:
	var witness: Dictionary = {}
	var status := "REFILL_REQUIRED" if ids.is_empty() else "GAME_OVER"
	for slot in range(ids.size()):
		var found := _witness(ids[slot], context)
		if not found.is_empty():
			if witness.is_empty() or not found.requires_clear:
				witness = found.duplicate()
				witness["slot"] = slot
				witness["piece_id"] = ids[slot]
			if not found.requires_clear:
				status = "CAN_PLACE"
				break
	if status == "GAME_OVER" and context.has_pending:
		status = "MUST_CLEAR"
	return {"status": status, "witness": witness}

func analyze_tray(board: Variant, ids: Variant) -> Dictionary:
	var error := _validate_board_tray(board, ids)
	if not error.is_empty():
		return _error(error)
	var context := _board_context(board)
	var result := _decision(ids, context)
	result.merge({"ok": true, "pending_rows": context.pending_rows, "pending_columns": context.pending_columns,
		"post_clear": context.post_clear})
	return result

func _sample(rng: RandomNumberGenerator, easy_only: bool = false, eligible: Dictionary = {}) -> String:
	var weights: Array[int] = []
	for fi in range(_families.size()):
		var allowed: bool = not easy_only or _families[fi].id in _easy
		if not eligible.is_empty():
			allowed = allowed and eligible.has(fi)
		weights.append(_weights[fi] if allowed else 0)
	var fi := Legacy.ticket_index(weights, rng.randi_range(0, Legacy.weight_total(weights) - 1))
	var variants: Array = []
	if eligible.is_empty():
		for vi in range(_families[fi].patterns.size()):
			variants.append("%s_v%d" % [_families[fi].id, vi])
	else:
		variants = eligible[fi]
	return variants[rng.randi_range(0, variants.size() - 1)]

func _is_easy(id: String) -> bool:
	return _lookup[id].family in _easy

func _eligible(context: Dictionary, easy_only: bool) -> Dictionary:
	var result := {}
	for piece in _pieces:
		var fi: int = piece.family_index
		if _weights[fi] == 0 or (easy_only and piece.family not in _easy):
			continue
		if not _witness(piece.id, context).is_empty():
			if not result.has(fi):
				result[fi] = []
			result[fi].append(piece.id)
	return result

func generate(board: Variant, remaining_ids: Variant, checkpoint: Variant) -> Dictionary:
	var error := _validate_board_tray(board, remaining_ids)
	if not error.is_empty():
		return _error(error)
	if not remaining_ids.is_empty():
		return _error("REFILL_NOT_ALLOWED")
	error = _validate_checkpoint(checkpoint)
	if not error.is_empty():
		return _error(error)
	var context := _board_context(board)
	var rng := RandomNumberGenerator.new()
	rng.seed = parse_int64(checkpoint.rng_seed).value
	rng.state = parse_int64(checkpoint.rng_state).value
	var ids: Array[String] = []
	var metrics := {"attempts": 0, "rerolls": 0, "easy_replacements": 0,
		"fallback": "none", "replacement_slots": [], "raw_piece_ids": []}
	var decision: Dictionary
	var limit := _max_rerolls + 1 if _policy == SOFT else 1
	for attempt in range(limit):
		ids.clear()
		metrics.attempts += 1
		metrics.rerolls = attempt
		for slot in range(TRAY_SIZE):
			ids.append(_sample(rng))
		metrics.raw_piece_ids.append_array(ids)
		if _policy != RAW and not ids.any(_is_easy):
			var slot := rng.randi_range(0, TRAY_SIZE - 1)
			ids[slot] = _sample(rng, true)
			metrics.easy_replacements += 1
			metrics.replacement_slots.append(slot)
		decision = _decision(ids, context)
		if _policy != SOFT or not decision.witness.is_empty():
			break
	if _policy == SOFT and decision.witness.is_empty():
		var eligible := _eligible(context, true)
		metrics.fallback = "easy_fit"
		if eligible.is_empty():
			eligible = _eligible(context, false)
			metrics.fallback = "enabled_fit"
		if not eligible.is_empty():
			var replacement := _sample(rng, false, eligible)
			var slots: Array[int] = []
			var easy_count := ids.filter(_is_easy).size()
			for slot in range(TRAY_SIZE):
				if _is_easy(replacement) or easy_count > 1 or not _is_easy(ids[slot]):
					slots.append(slot)
			var slot := slots[rng.randi_range(0, slots.size() - 1)]
			ids[slot] = replacement
			metrics.replacement_slots.append(slot)
			decision = _decision(ids, context)
		else:
			metrics.fallback = "no_enabled_fit"
	return {"ok": true, "piece_ids": ids, "checkpoint": _checkpoint(checkpoint.rng_seed, rng.state),
		"decision": decision, "guarantee_met": not decision.witness.is_empty(), "metrics": metrics}
