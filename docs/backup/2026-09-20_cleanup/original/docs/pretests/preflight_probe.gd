extends SceneTree
const Supply = preload("../examples/piece_supply_v0_1.gd")
var failures: Array[String] = []
var checks := 0

func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition and failures.size() < 20:
		failures.append(label)

func read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Expected phase, input JSON, output JSON")
		quit(2)
		return
	var data := read_json(args[1])
	var output: Dictionary
	if args[0] == "resume":
		output = resume_checks(data)
	else:
		output = primary_checks(data)
	output["checks"] = checks
	output["failures"] = failures
	output["engine"] = Engine.get_version_info()["string"]
	var file := FileAccess.open(args[2], FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	file.store_string(JSON.stringify(output))
	file.close()
	print(JSON.stringify({"phase": args[0], "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func resume_checks(data: Dictionary) -> Dictionary:
	for checkpoint in data["checkpoints"]:
		var state_value := int(checkpoint["state"])
		var sequence: Array = []
		for batch in range(10):
			var result := Supply.draw_batch(int(checkpoint["seed"]), state_value,
				checkpoint["policy"])
			sequence.append_array(result["piece_ids"])
			state_value = int(result["rng_state"])
		verify(sequence == checkpoint["expected_ids"], "process resume IDs: " + checkpoint["seed"])
		verify(str(state_value) == checkpoint["expected_state"], "process resume state")
	return {"checkpoint_count": data["checkpoints"].size()}

func primary_checks(data: Dictionary) -> Dictionary:
	var catalog := Supply.catalog()
	var lookup := {}
	for piece in catalog:
		lookup[piece["id"]] = piece
	var placement_comparisons := 0
	for fixture in data["boards"]:
		var board := PackedByteArray(fixture["board"])
		for piece in catalog:
			var mask := ""
			for y in range(-1, 9):
				for x in range(-1, 9):
					mask += "1" if Supply.can_place(board, piece["cells"], Vector2i(x, y)) else "0"
					placement_comparisons += 1
			verify(mask == fixture["masks"][piece["id"]], "placement oracle: " + fixture["name"] + "/" + piece["id"])
		verify(Supply.pending_line_count(board) == int(fixture["pending"]), "line oracle: " + fixture["name"])
		for tray in fixture["trays"]:
			var remaining: Array[String] = []
			remaining.assign(tray["ids"])
			verify(Supply.tray_status(board, remaining) == tray["status"], "tray oracle: " + fixture["name"])
		verify(board == PackedByteArray(fixture["board"]), "board mutation")
	for fixture in data["invalid_boards"]:
		var ids: Array[String] = ["single_v0"]
		verify(Supply.tray_status(PackedByteArray(fixture), ids) == "INVALID_INPUT", "invalid board")
	var original_catalog := Supply.catalog()
	catalog[0]["cells"].append(Vector2i(7, 7))
	verify(Supply.catalog() == original_catalog, "catalog ownership isolation")
	var checkpoints: Array = []
	var samples := {}
	var streams := {}
	for policy in [Supply.WEIGHTED_POLICY, Supply.UNIFORM_POLICY]:
		var counts := {}
		var slot_counts: Array = [{}, {}, {}]
		for piece in original_catalog:
			counts[piece["id"]] = 0
			for slot in range(3):
				slot_counts[slot][piece["id"]] = 0
		var duplicate_batches := 0
		var batches := 0
		for seed_text in data["seeds"]:
			var seed_value := int(seed_text)
			var state_value := Supply.initial_rng_state(seed_value)
			var supply_stream: Array = []
			for batch in range(int(data["batches_per_seed"])):
				var result := Supply.draw_batch(seed_value, state_value, policy)
				state_value = int(result["rng_state"])
				var ids: Array[String] = result["piece_ids"]
				if batch < int(data["play_stream_length"]) and seed_text in data["play_seeds"]:
					supply_stream.append(ids)
				for slot in range(3):
					counts[ids[slot]] += 1
					slot_counts[slot][ids[slot]] += 1
				if ids[0] == ids[1] or ids[0] == ids[2] or ids[1] == ids[2]:
					duplicate_batches += 1
				batches += 1
			if not supply_stream.is_empty():
				streams[policy + ":" + seed_text] = supply_stream
			var checkpoint := {"seed": seed_text, "policy": policy, "state": str(state_value)}
			var expected: Array = []
			for batch in range(10):
				var result := Supply.draw_batch(seed_value, state_value, policy)
				expected.append_array(result["piece_ids"])
				state_value = int(result["rng_state"])
			checkpoint["expected_ids"] = expected
			checkpoint["expected_state"] = str(state_value)
			checkpoints.append(checkpoint)
		samples[policy] = {"counts": counts, "slot_counts": slot_counts,
			"batches": batches, "duplicate_batches": duplicate_batches}
	var json_catalog: Array = []
	for piece in original_catalog:
		var cells: Array = []
		for cell in piece["cells"]:
			cells.append([cell.x, cell.y])
		json_catalog.append({"id": piece["id"], "family": piece["family"], "cells": cells})
	return {"placement_comparisons": placement_comparisons,
		"board_count": data["boards"].size(), "samples": samples,
		"checkpoints": checkpoints, "play_streams": streams, "catalog": json_catalog,
		"definition_hash": Supply.definition_hash()}
