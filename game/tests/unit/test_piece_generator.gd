extends "res://addons/gut/test.gd"
## 생성기의 계약/수학적 경계/독립 좌표 판정과 대조한다.

const Generator = preload("res://scripts/core/generation/piece_generator.gd")
const Config = preload("res://scripts/core/generation/piece_generator_config.gd")
const Legacy = preload("res://scripts/core/piece_supply.gd")
var generator

func before_each():
	generator = Generator.create().generator

func empty_board() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(64)
	return b

func checker_board() -> PackedByteArray:
	var b := empty_board()
	for y in range(8):
		for x in range(8):
			b[y * 8 + x] = (x + y) % 2
	return b

func oracle_post(b: PackedByteArray) -> PackedByteArray:
	var remove := {}
	for i in range(8):
		var row := true
		var column := true
		for j in range(8):
			row = row and b[i * 8 + j] == 1
			column = column and b[j * 8 + i] == 1
		for j in range(8):
			if row: remove[i * 8 + j] = true
			if column: remove[j * 8 + i] = true
	var post := b.duplicate()
	for index in remove:
		post[index] = 0
	return post

func oracle_place(b: PackedByteArray, cells: Array, x: int, y: int) -> bool:
	for c in cells:
		if x + c.x < 0 or x + c.x >= 8 or y + c.y < 0 or y + c.y >= 8:
			return false
		if b[(y + c.y) * 8 + x + c.x] != 0:
			return false
	return true

func oracle_fit(b: PackedByteArray, cells: Array) -> bool:
	for y in range(8):
		for x in range(8):
			if oracle_place(b, cells, x, y): return true
	return false

func test_catalog_geometry_unique_connected_normalized_and_legacy_preserved():
	var pieces: Array = generator.catalog()
	assert_eq(pieces.size(), 29)
	assert_eq(generator.config_snapshot().family_ids.size(), 13)
	var shapes := {}
	for p in pieces:
		var normalized: Array = p.cells.map(func(c): return c.y * 8 + c.x)
		normalized.sort()
		assert_false(shapes.has(str(normalized)), p.id + " unique geometry")
		shapes[str(normalized)] = true
		assert_eq(p.cells.map(func(c): return c.x).min(), 0)
		assert_eq(p.cells.map(func(c): return c.y).min(), 0)
		var connected := {p.cells[0]: true}
		for step in range(p.cells.size()):
			for c in p.cells:
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if connected.has(c + direction): connected[c] = true
		assert_eq(connected.size(), p.cells.size(), p.id + " connected")
	var old := Legacy.catalog()
	for i in range(old.size()):
		assert_eq(pieces[i].id, old[i].id)
		assert_eq(pieces[i].cells, old[i].cells)

func test_integer_ticket_boundaries_exhaustive():
	var weights: Array[int] = generator.config_snapshot().family_weights
	var counts: Array[int] = []
	counts.resize(weights.size())
	for ticket in range(Legacy.weight_total(weights)):
		counts[Legacy.ticket_index(weights, ticket)] += 1
	assert_eq(counts, weights)
	assert_eq(Legacy.ticket_index(weights, -1), -1)
	assert_eq(Legacy.ticket_index(weights, 45), -1)
	assert_eq(Legacy.ticket_index([0, 1, 0], 0), 1)

func test_config_errors_and_defensive_snapshot():
	assert_false(Generator.create({}).ok)
	for values in [[], [0, 0], [-1], [1000001]]:
		var cfg := Config.new()
		cfg.family_weights.assign(values)
		assert_false(Generator.create(cfg).ok)
	var cfg := Config.new()
	cfg.family_weights.fill(0)
	assert_eq(Generator.create(cfg).error, "INVALID_WEIGHTS")
	cfg = Config.new()
	cfg.easy_families = ["missing"]
	assert_eq(Generator.create(cfg).error, "UNKNOWN_EASY_FAMILY")
	cfg.easy_families = ["single", "single"]
	assert_eq(Generator.create(cfg).error, "DUPLICATE_EASY_FAMILY")
	cfg.easy_families = []
	assert_eq(Generator.create(cfg).error, "NO_ENABLED_EASY_FAMILY")
	cfg = Config.new()
	cfg.max_rerolls = 4
	assert_false(Generator.create(cfg).ok)
	cfg = Config.new()
	var g = Generator.create(cfg).generator
	var original: Dictionary = g.config_snapshot()
	cfg.family_weights[0] = 999
	var copy: Dictionary = g.config_snapshot()
	copy.family_weights[0] = 888
	var pieces: Array = g.catalog()
	pieces[0].cells.clear()
	assert_eq(g.config_snapshot(), original)
	assert_eq(g.catalog()[0].cells.size(), 1)

func test_strict_int64_and_checkpoint_validation():
	for s in ["0", "1", "-1", "9223372036854775807", "-9223372036854775808"]:
		assert_true(Generator.parse_int64(s).ok, s)
		assert_true(generator.initial_checkpoint(s).ok)
	for s in ["", "00", "-0", "+1", " 1", "1 ", "1.0", "1e3", "--1", "9223372036854775808", "-9223372036854775809", 1, 1.0, null, true]:
		assert_false(Generator.parse_int64(s).ok, str(s))
	var checkpoint: Dictionary = generator.initial_checkpoint("42").checkpoint
	for key in checkpoint:
		var bad := checkpoint.duplicate(true)
		bad.erase(key)
		assert_false(generator.generate(empty_board(), [], bad).ok)
		bad = checkpoint.duplicate(true)
		bad[key] = "wrong"
		assert_false(generator.generate(empty_board(), [], bad).ok)

func test_bad_input_and_nonempty_tray_do_not_change_owned_state():
	var b := empty_board()
	var cp: Dictionary = generator.initial_checkpoint("-42").checkpoint
	var before: Dictionary = cp.duplicate(true)
	var expected: Dictionary = generator.generate(b, [], cp)
	for invalid in [null, [], PackedByteArray([0]), "board"]:
		assert_false(generator.generate(invalid, [], cp).ok)
	var bad := b.duplicate()
	bad[63] = 2
	assert_false(generator.generate(bad, [], cp).ok)
	assert_eq(generator.generate(b, ["single_v0"], cp).error, "REFILL_NOT_ALLOWED")
	assert_false(generator.analyze_tray(b, ["single_v0", "unknown"]).ok)
	assert_false(generator.generate(b, null, cp).ok)
	assert_eq(cp, before)
	assert_eq(b, empty_board())
	assert_eq(generator.generate(b, [], cp), expected)

func test_post_clear_union_and_must_clear_before_game_over():
	var b := empty_board()
	for i in range(8):
		b[3 * 8 + i] = 1
		b[i * 8 + 6] = 1
	var before := b.duplicate()
	var result: Dictionary = generator.analyze_tray(b, ["square3_v0"])
	assert_eq(result.pending_rows, [3])
	assert_eq(result.pending_columns, [6])
	assert_eq(result.post_clear, empty_board())
	assert_eq(b, before)
	b.fill(1)
	result = generator.analyze_tray(b, ["square3_v0"])
	assert_eq(result.status, "MUST_CLEAR")
	assert_true(result.witness.requires_clear)
	assert_eq(generator.analyze_tray(b, []).status, "REFILL_REQUIRED")
	result = generator.analyze_tray(checker_board(), ["line2_v0", "square2_v0"])
	assert_eq(result.status, "GAME_OVER")

func test_exhaustive_512_local_masks_match_independent_coordinate_oracle():
	var pieces: Array = generator.catalog()
	var checks := 0
	for mask in range(512):
		var b := checker_board()
		# 우하단 창에 9비트 전수를 넣어 가장자리/최상위 셀도 검사한다.
		for bit in range(9): b[(5 + bit / 3) * 8 + 5 + bit % 3] = (mask >> bit) & 1
		var post := oracle_post(b)
		for piece in pieces:
			var actual: Dictionary = generator.analyze_tray(b, [piece.id])
			var current := oracle_fit(b, piece.cells)
			var after := oracle_fit(post, piece.cells)
			var pending: bool = post != b
			var expected := "CAN_PLACE" if current else ("MUST_CLEAR" if pending else "GAME_OVER")
			if actual.status != expected or actual.post_clear != post or actual.witness.is_empty() == (current or after):
				fail_test("oracle mismatch: mask=%d id=%s" % [mask, piece.id])
				return
			checks += 1
	assert_eq(checks, 14848)

func test_deterministic_json_resume_and_board_ownership():
	var cp: Dictionary = generator.initial_checkpoint("9223372036854775807").checkpoint
	var clone = Generator.create().generator
	var resumed: Dictionary = JSON.parse_string(JSON.stringify(cp))
	var board_rng := RandomNumberGenerator.new()
	board_rng.seed = 93
	for batch in range(200):
		var b := empty_board()
		for cell in range(64): b[cell] = int(board_rng.randf() < 0.7)
		var before := b.duplicate()
		var a: Dictionary = generator.generate(b, [], cp)
		var other: Dictionary = clone.generate(b, [], resumed)
		assert_eq(a, other)
		assert_eq(b, before)
		assert_true(a.guarantee_met)
		assert_eq(a.piece_ids.size(), 3)
		assert_true(a.piece_ids.any(func(id): return id.get_slice("_v", 0) in generator.config_snapshot().easy_families))
		var witness: Dictionary = a.decision.witness
		var piece: Dictionary = generator.catalog().filter(func(p): return p.id == witness.piece_id)[0]
		assert_true(oracle_place(oracle_post(b) if witness.requires_clear else b, piece.cells, witness.x, witness.y))
		cp = a.checkpoint
		resumed = JSON.parse_string(JSON.stringify(other.checkpoint))

func test_bounded_fallback_zero_weights_and_no_enabled_fit():
	var cfg := Config.new()
	cfg.max_rerolls = 0
	cfg.family_weights.fill(0)
	cfg.family_weights[0] = 1
	cfg.family_weights[4] = 100000
	cfg.easy_families = ["line5"]
	var g = Generator.create(cfg).generator
	var r: Dictionary = g.generate(checker_board(), [], g.initial_checkpoint("7").checkpoint)
	assert_eq(r.metrics.attempts, 1)
	assert_eq(r.metrics.fallback, "enabled_fit")
	assert_true(r.guarantee_met)
	assert_true(r.piece_ids.has("single_v0"))
	assert_true(r.piece_ids.any(func(id): return id.begins_with("line5_")))
	cfg.family_weights[0] = 0
	cfg.family_weights[4] = 0
	cfg.family_weights[6] = 1
	cfg.easy_families = ["square3"]
	cfg.max_rerolls = 3
	g = Generator.create(cfg).generator
	r = g.generate(checker_board(), [], g.initial_checkpoint("8").checkpoint)
	assert_eq(r.metrics.attempts, 4)
	assert_eq(r.metrics.rerolls, 3)
	assert_eq(r.metrics.fallback, "no_enabled_fit")
	assert_false(r.guarantee_met)
	assert_eq(r.decision.status, "GAME_OVER")
	assert_eq(r.piece_ids, ["square3_v0", "square3_v0", "square3_v0"])
	var b := checker_board()
	for x in range(8): b[x] = 1
	r = g.generate(b, [], g.initial_checkpoint("8").checkpoint)
	assert_false(r.guarantee_met)
	assert_eq(r.decision.status, "MUST_CLEAR", "existing clear is never hidden by generation failure")

func test_raw_control_has_no_easy_injection_and_old_checkpoint_rejected():
	var cfg := Config.new()
	cfg.supply_policy_version = Generator.RAW
	cfg.family_weights.fill(0)
	cfg.family_weights[6] = 1
	cfg.easy_families = []
	var g = Generator.create(cfg).generator
	var cp: Dictionary = g.initial_checkpoint("0").checkpoint
	var r: Dictionary = g.generate(checker_board(), [], cp)
	assert_eq(r.piece_ids, ["square3_v0", "square3_v0", "square3_v0"])
	assert_eq(r.metrics.easy_replacements, 0)
	assert_eq(r.metrics.attempts, 1)
	assert_false(generator.generate(empty_board(), [], cp).ok)

func test_each_piece_fit_does_not_imply_whole_tray_solution():
	var b := checker_board()
	b[1] = 0
	var ids := ["line2_v0", "line2_v0", "line2_v0"]
	assert_eq(generator.analyze_tray(b, ids).status, "CAN_PLACE")
	var cells: Array = generator.catalog().filter(func(p): return p.id == "line2_v0")[0].cells
	var first_moves := 0
	for y in range(8):
		for x in range(8):
			if oracle_place(b, cells, x, y):
				first_moves += 1
				var next := b.duplicate()
				for c in cells: next[(y + c.y) * 8 + x + c.x] = 1
				assert_false(oracle_fit(oracle_post(next), cells))
	assert_gt(first_moves, 0)

func test_easy_fallback_and_replacement_slots_and_config_identity():
	var cfg := Config.new()
	cfg.max_rerolls = 0
	cfg.family_weights.fill(0)
	cfg.family_weights[0] = 1
	cfg.family_weights[4] = 100000
	cfg.easy_families = ["single", "line5"]
	var g = Generator.create(cfg).generator
	var r: Dictionary = g.generate(checker_board(), [], g.initial_checkpoint("7").checkpoint)
	assert_eq(r.metrics.fallback, "easy_fit")
	assert_true(r.guarantee_met)
	assert_true(r.piece_ids.has("single_v0"))
	var slots := {}
	for seed_value in range(100):
		r = g.generate(checker_board(), [], g.initial_checkpoint(str(seed_value)).checkpoint)
		for slot in r.metrics.replacement_slots: slots[slot] = true
	assert_eq(slots.size(), 3)
	var snapshot: Dictionary = g.config_snapshot()
	cfg.easy_families.reverse()
	assert_eq(Generator.create(cfg).generator.config_snapshot(), snapshot)
	cfg.family_weights[0] = 2
	var other = Generator.create(cfg).generator
	assert_eq(other.generate(empty_board(), [], g.initial_checkpoint("7").checkpoint).error, "CHECKPOINT_VERSION_MISMATCH")
	cfg.family_weights[0] = 1000001
	assert_eq(Generator.create(cfg).error, "INVALID_WEIGHTS")
	cfg.family_weights[0] = -1
	assert_eq(Generator.create(cfg).error, "INVALID_WEIGHTS")
	cfg = Config.new()
	cfg.max_rerolls = -1
	assert_eq(Generator.create(cfg).error, "INVALID_REROLL_LIMIT")
