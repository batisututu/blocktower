extends RefCounted
## Original Blocktower research example, not vendored third-party code.
## Fixed experiment data; product balance and Godot 4.7.2 validation pending.

const CATALOG_VERSION := "bt_catalog_19_v0_1"
const WEIGHTED_POLICY := "bt_family_weighted_v0_1"
const UNIFORM_POLICY := "bt_id_uniform_v0_1"
const SIDE := 8
const FAMILIES := [
	{"id": "single", "weight": 6, "patterns": [["#"]]},
	{"id": "line2", "weight": 16, "patterns": [["##"], ["#", "#"]]},
	{"id": "line3", "weight": 18, "patterns": [["###"], ["#", "#", "#"]]},
	{"id": "line4", "weight": 12, "patterns": [["####"], ["#", "#", "#", "#"]]},
	{"id": "line5", "weight": 6, "patterns": [["#####"], ["#", "#", "#", "#", "#"]]},
	{"id": "square2", "weight": 14, "patterns": [["##", "##"]]},
	{"id": "square3", "weight": 4, "patterns": [["###", "###", "###"]]},
	{"id": "elbow3", "weight": 16, "patterns": [
		["##", "#."], ["##", ".#"], [".#", "##"], ["#.", "##"]]},
	{"id": "elbow5", "weight": 8, "patterns": [
		["###", "#..", "#.."], ["###", "..#", "..#"],
		["..#", "..#", "###"], ["#..", "#..", "###"]]},
]

static func definition_hash() -> String:
	# Fixed serialization: family order, weights, variant order and row patterns.
	var chunks := PackedStringArray()
	for family in FAMILIES:
		chunks.append("%s:%d" % [family["id"], family["weight"]])
		for rows in family["patterns"]:
			chunks.append("/".join(PackedStringArray(rows)))
	return "\n".join(chunks).sha256_text()

static func catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for family in FAMILIES:
		var patterns: Array = family["patterns"]
		for variant in range(patterns.size()):
			var rows: Array = patterns[variant]
			var cells: Array[Vector2i] = []
			for y in range(rows.size()):
				var row: String = rows[y]
				for x in range(row.length()):
					if row[x] == "#":
						cells.append(Vector2i(x, y))
			result.append({"id": "%s_v%d" % [family["id"], variant],
				"family": family["id"], "cells": cells})
	return result

static func policy_weights(policy_id: String) -> Array[int]:
	var weights: Array[int] = []
	if policy_id != WEIGHTED_POLICY and policy_id != UNIFORM_POLICY:
		return weights
	for family in FAMILIES:
		# Weight by variant count => uniform probability per fixed piece ID.
		weights.append(int(family["weight"]) if policy_id == WEIGHTED_POLICY
			else family["patterns"].size())
	return weights

static func weight_total(weights: Array[int]) -> int:
	var total := 0
	for weight in weights:
		if weight < 0 or weight > 1000000 - total:
			return -1
		total += weight
	return total

static func ticket_index(weights: Array[int], ticket: int) -> int:
	var total := weight_total(weights)
	if total <= 0 or ticket < 0 or ticket >= total:
		return -1
	for i in range(weights.size()):
		if ticket < weights[i]:
			return i
		ticket -= weights[i]
	return -1

static func initial_rng_state(seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.state

static func draw_batch(seed_value: int, previous_rng_state: int,
		policy_id: String = WEIGHTED_POLICY) -> Dictionary:
	var weights := policy_weights(policy_id)
	var total := weight_total(weights)
	if total <= 0:
		return {"ok": false, "error": "UNKNOWN_OR_INVALID_POLICY"}
	# Candidate-local RNG: caller-owned state is never mutated here.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	rng.state = previous_rng_state
	var ids: Array[String] = []
	for slot in range(3):
		var family_index := ticket_index(weights, rng.randi_range(0, total - 1))
		var family: Dictionary = FAMILIES[family_index]
		var variant := rng.randi_range(0, family["patterns"].size() - 1)
		ids.append("%s_v%d" % [family["id"], variant])
	return {"ok": true, "piece_ids": ids, "rng_state": str(rng.state),
		"rng_seed": str(seed_value), "catalog_version": CATALOG_VERSION,
		"supply_policy_version": policy_id, "definition_hash": definition_hash(),
		"engine_version": Engine.get_version_info()["string"]}

static func valid_board(board: PackedByteArray) -> bool:
	if board.size() != SIDE * SIDE:
		return false
	for value in board:
		if value != 0 and value != 1:
			return false
	return true

## Requires a validated board and trusted, nonempty catalog cells.
static func can_place(board: PackedByteArray, cells: Array[Vector2i],
		origin: Vector2i) -> bool:
	if board.size() != SIDE * SIDE or cells.is_empty():
		return false
	for offset in cells:
		var cell := origin + offset
		if cell.x < 0 or cell.y < 0 or cell.x >= SIDE or cell.y >= SIDE:
			return false
		if board[cell.y * SIDE + cell.x] != 0:
			return false
	return true

static func has_fit(board: PackedByteArray, cells: Array[Vector2i]) -> bool:
	for y in range(SIDE):
		for x in range(SIDE):
			if can_place(board, cells, Vector2i(x, y)):
				return true
	return false

static func pending_line_count(board: PackedByteArray) -> int:
	var count := 0
	for a in range(SIDE):
		var full_row := true
		var full_column := true
		for b in range(SIDE):
			full_row = full_row and board[a * SIDE + b] == 1
			full_column = full_column and board[b * SIDE + a] == 1
		if full_row:
			count += 1
		if full_column:
			count += 1
	return count

static func tray_status(board: PackedByteArray, remaining_ids: Array[String]) -> String:
	if not valid_board(board):
		return "INVALID_INPUT"
	if remaining_ids.is_empty():
		return "REFILL_REQUIRED"
	if remaining_ids.size() > 3:
		return "INVALID_INPUT"
	var lookup := {}
	for piece in catalog():
		lookup[piece["id"]] = piece
	# Validate every ID before any early success.
	for id in remaining_ids:
		if not lookup.has(id):
			return "INVALID_INPUT"
	for id in remaining_ids:
		if has_fit(board, lookup[id]["cells"]):
			return "CAN_PLACE"
	if pending_line_count(board) > 0:
		return "MUST_CLEAR"
	return "GAME_OVER"
