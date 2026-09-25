extends SceneTree
## Standalone research checks. Run from an isolated temporary Godot project.
const Supply = preload("piece_supply_v0_1.gd")
var failures: Array[String] = []
var checks := 0

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	# If definitions change, review and bump versions before updating this pin.
	expect(Supply.definition_hash() ==
		"a91e1b381f5445452e1219d3803fb21016895f6054c4bab0a7cc39a546defa59",
		"versioned definition fingerprint")
	var pieces := Supply.catalog()
	var ids := {}
	var geometry := {}
	var by_id := {}
	var empty := PackedByteArray()
	empty.resize(64)
	for piece in pieces:
		var cells: Array[Vector2i] = piece["cells"]
		var unique := {}
		var min_x := 8
		var min_y := 8
		for cell in cells:
			unique[cell] = true
			min_x = mini(min_x, cell.x)
			min_y = mini(min_y, cell.y)
		expect(unique.size() == cells.size(), "unique cells: " + piece["id"])
		expect(min_x == 0 and min_y == 0, "normalized: " + piece["id"])
		var reached := {cells[0]: true}
		var frontier: Array[Vector2i] = [cells[0]]
		while not frontier.is_empty():
			var here: Vector2i = frontier.pop_back()
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = here + step
				if unique.has(neighbor) and not reached.has(neighbor):
					reached[neighbor] = true
					frontier.append(neighbor)
		expect(reached.size() == cells.size(), "connected: " + piece["id"])
		expect(Supply.has_fit(empty, cells), "empty-board fit: " + piece["id"])
		ids[piece["id"]] = true
		geometry[str(cells)] = true
		by_id[piece["id"]] = piece
	expect(pieces.size() == 19 and ids.size() == 19 and geometry.size() == 19,
		"19 distinct fixed pieces")
	var weights: Array[int] = Supply.policy_weights(Supply.WEIGHTED_POLICY)
	var counts: Array[int] = []
	counts.resize(weights.size())
	counts.fill(0)
	for ticket in range(100):
		counts[Supply.ticket_index(weights, ticket)] += 1
	expect(counts == weights, "all 100 weighted ticket boundaries")
	var uniform: Array[int] = Supply.policy_weights(Supply.UNIFORM_POLICY)
	expect(Supply.weight_total(uniform) == 19, "uniform policy has 19 tickets")
	for family_index in range(Supply.FAMILIES.size()):
		expect(uniform[family_index] == Supply.FAMILIES[family_index]["patterns"].size(),
			"uniform family weight equals number of variants")
	expect(Supply.ticket_index(weights, -1) == -1
		and Supply.ticket_index(weights, 100) == -1, "invalid tickets rejected")
	var zeros: Array[int] = [0, 0]
	var negative: Array[int] = [1, -1]
	expect(Supply.ticket_index(zeros, 0) == -1
		and Supply.ticket_index(negative, 0) == -1, "bad weights rejected")
	var seed_value := 20260920
	var initial := Supply.initial_rng_state(seed_value)
	var first := Supply.draw_batch(seed_value, initial)
	expect(first == Supply.draw_batch(seed_value, initial), "same input, same batch")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(first))
	var after := Supply.draw_batch(int(restored["rng_seed"]), int(restored["rng_state"]))
	expect(after == Supply.draw_batch(seed_value, int(first["rng_state"])),
		"JSON string RNG round trip")
	var effect_rng := RandomNumberGenerator.new()
	effect_rng.seed = 99
	for i in range(100):
		effect_rng.randi()
	expect(first == Supply.draw_batch(seed_value, initial), "presentation RNG isolation")
	expect(not Supply.draw_batch(seed_value, initial, "missing")["ok"], "unknown policy")
	var big_int := 9223372036854775807
	var value: Dictionary = JSON.parse_string(JSON.stringify({"value": str(big_int)}))
	expect(int(value["value"]) == big_int, "64-bit decimal string round trip")
	var full := empty.duplicate()
	full.fill(1)
	var small_ids: Array[String] = ["single_v0"]
	expect(Supply.pending_line_count(full) == 16, "full board has 16 lines")
	expect(Supply.tray_status(full, small_ids) == "MUST_CLEAR", "pending beats game-over")
	var none: Array[String] = []
	expect(Supply.tray_status(full, none) == "REFILL_REQUIRED", "empty tray requires refill")
	var checker := empty.duplicate()
	for y in range(8):
		for x in range(8):
			checker[y * 8 + x] = (x + y) % 2
	var large_ids: Array[String] = ["square2_v0", "square3_v0", "line2_v0"]
	expect(Supply.tray_status(checker, large_ids) == "GAME_OVER", "isolated holes, no lines")
	var mixed: Array[String] = ["square3_v0", "single_v0"]
	expect(Supply.tray_status(checker, mixed) == "CAN_PLACE", "any remaining piece fits")
	var invalid: Array[String] = ["single_v0", "missing"]
	expect(Supply.tray_status(empty, invalid) == "INVALID_INPUT", "validate all IDs first")
	expect(not Supply.can_place(empty, by_id["line2_v0"]["cells"], Vector2i(7, 0)),
		"right edge is not row wrapping")
	var old_checker := checker.duplicate()
	Supply.tray_status(checker, mixed)
	expect(checker == old_checker, "probe does not mutate board")
	# Three horizontal dominoes each fit the same initial board, but after
	# either possible first placement no horizontal domino fits and no line clears.
	var counterexample := checker.duplicate()
	counterexample[1] = 0
	var domino: Array[Vector2i] = by_id["line2_v0"]["cells"]
	var positions: Array[Vector2i] = []
	for y in range(8):
		for x in range(8):
			if Supply.can_place(counterexample, domino, Vector2i(x, y)):
				positions.append(Vector2i(x, y))
	expect(positions.size() == 2, "counterexample has exactly two first anchors")
	for origin in positions:
		var next := counterexample.duplicate()
		for cell in domino:
			var placed := origin + cell
			next[placed.y * 8 + placed.x] = 1
		expect(not Supply.has_fit(next, domino) and Supply.pending_line_count(next) == 0,
			"individual fits do not guarantee a sequentially placeable tray")
	var family_counts := {}
	for family in Supply.FAMILIES:
		family_counts[family["id"]] = 0
	var rng_state := initial
	var duplicates_seen := false
	var seen := {}
	for batch in range(10000):
		var result := Supply.draw_batch(seed_value, rng_state)
		rng_state = int(result["rng_state"])
		var drawn: Array[String] = result["piece_ids"]
		if drawn[0] == drawn[1] or drawn[0] == drawn[2] or drawn[1] == drawn[2]:
			duplicates_seen = true
		for id in drawn:
			seen[id] = true
			family_counts[by_id[id]["family"]] += 1
	expect(duplicates_seen, "sampling with replacement permits duplicates")
	expect(seen.size() == 19, "all IDs reached in deterministic sample")
	# Diagnostic only: this is not a gameplay/balance acceptance test.
	print(JSON.stringify({"engine": Engine.get_version_info()["string"],
		"checks": checks, "failures": failures, "sample_pieces": 30000,
		"family_counts": family_counts, "first_batch": first}))
	quit(0 if failures.is_empty() else 1)
