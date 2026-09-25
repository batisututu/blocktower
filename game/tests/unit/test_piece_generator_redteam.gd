extends "res://addons/gut/test.gd"
## 기존 비트마스크 구현을 호출하지 않는 좌표 검사로 반례를 찾는다.
const Generator = preload("res://scripts/core/generation/piece_generator.gd")
const Config = preload("res://scripts/core/generation/piece_generator_config.gd")

func board_for(index: int, rng: RandomNumberGenerator) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(64)
	for cell in range(64): b[cell] = int(rng.randf() < float(index % 11) / 10.0)
	return b

func clear_oracle(b: PackedByteArray) -> PackedByteArray:
	var marked := {}
	for axis in range(2):
		for line in range(8):
			var indices := []
			for offset in range(8):
				indices.append(line * 8 + offset if axis == 0 else offset * 8 + line)
			if indices.all(func(i): return b[i] == 1):
				for i in indices: marked[i] = true
	var out := b.duplicate()
	for i in marked: out[i] = 0
	return out

func fits_at(b: PackedByteArray, piece: Dictionary, x: int, y: int) -> bool:
	for cell in piece.cells:
		var px: int = x + cell.x
		var py: int = y + cell.y
		if px < 0 or px >= 8 or py < 0 or py >= 8 or b[py * 8 + px] != 0: return false
	return true

func fits_any(b: PackedByteArray, piece: Dictionary) -> bool:
	for y in range(8):
		for x in range(8):
			if fits_at(b, piece, x, y): return true
	return false

func test_every_piece_at_every_legal_origin_has_current_witness():
	var g = Generator.create().generator
	var checked := 0
	for piece in g.catalog():
		for y in range(9 - piece.height):
			for x in range(9 - piece.width):
				var b := PackedByteArray()
				b.resize(64)
				b.fill(1)
				for cell in piece.cells: b[(y + cell.y) * 8 + x + cell.x] = 0
				var result: Dictionary = g.analyze_tray(b, [piece.id])
				var w: Dictionary = result.witness
				if result.status != "CAN_PLACE" or w.is_empty() or w.requires_clear or not fits_at(b, piece, w.x, w.y):
					fail_test("origin mismatch %s at %d,%d" % [piece.id, x, y])
					return
				checked += 1
	assert_eq(checked, 1261)

func test_random_full_board_positive_and_negative_decisions_match_oracle():
	var g = Generator.create().generator
	var rng := RandomNumberGenerator.new()
	rng.seed = 92713
	var checked := 0
	for index in range(220):
		var b := board_for(index, rng)
		var after := clear_oracle(b)
		for piece in g.catalog():
			var current := fits_any(b, piece)
			var after_fit := fits_any(after, piece)
			var result: Dictionary = g.analyze_tray(b, [piece.id])
			var expected := "CAN_PLACE" if current else ("MUST_CLEAR" if b != after else "GAME_OVER")
			if result.status != expected or result.post_clear != after or (not result.witness.is_empty()) != (current or after_fit):
				fail_test("full board oracle mismatch %d %s" % [index, piece.id])
				return
			checked += 1
	assert_eq(checked, 6380)

func test_all_active_family_subsets_obey_conditional_guarantee():
	var rng := RandomNumberGenerator.new()
	rng.seed = 420219
	var checked := 0
	var family_ids: Array = Generator.create().generator.config_snapshot().family_ids
	# 13계열 활성/비활성 8191가지 전수. 단일 활성 계열과 single 비활성도 포함한다.
	for subset in range(1, 1 << 13):
		var cfg := Config.new()
		cfg.max_rerolls = subset % 4
		cfg.family_weights.fill(0)
		cfg.easy_families.clear()
		for fi in range(13):
			if subset & (1 << fi):
				cfg.family_weights[fi] = fi + 1
				if cfg.easy_families.is_empty(): cfg.easy_families.append(family_ids[fi])
		var g = Generator.create(cfg).generator
		var b := board_for(subset, rng)
		var after := clear_oracle(b)
		var pieces := {}
		var possible := false
		for piece in g.catalog():
			pieces[piece.id] = piece
			if cfg.family_weights[piece.family_index] > 0:
				possible = possible or fits_any(b, piece) or fits_any(after, piece)
		var result: Dictionary = g.generate(b, [], g.initial_checkpoint(str(subset)).checkpoint)
		if not result.ok or result.guarantee_met != possible:
			fail_test("conditional guarantee mismatch subset=%d" % subset)
			return
		if not result.piece_ids.any(func(id): return pieces[id].family in cfg.easy_families):
			fail_test("easy invariant lost subset=%d" % subset)
			return
		for id in result.piece_ids:
			if cfg.family_weights[pieces[id].family_index] == 0:
				fail_test("disabled family supplied subset=%d" % subset)
				return
		if result.metrics.attempts > cfg.max_rerolls + 1:
			fail_test("retry limit exceeded subset=%d" % subset)
			return
		if possible:
			var w: Dictionary = result.decision.witness
			if not fits_at(after if w.requires_clear else b, pieces[w.piece_id], w.x, w.y):
				fail_test("invalid fallback witness subset=%d" % subset)
				return
		checked += 1
	assert_eq(checked, 8191)

func test_later_current_piece_beats_earlier_post_clear_piece_and_output_is_owned():
	var g = Generator.create().generator
	var b := PackedByteArray()
	b.resize(64)
	b.fill(1)
	b[63] = 0
	var cp: Dictionary = g.initial_checkpoint("0").checkpoint
	var result: Dictionary = g.analyze_tray(b, ["square3_v0", "single_v0"])
	assert_eq(result.status, "CAN_PLACE")
	assert_eq(result.witness.slot, 1)
	assert_false(result.witness.requires_clear)
	var first: Dictionary = g.generate(b, [], cp)
	var expected: Dictionary = first.duplicate(true)
	first.piece_ids[0] = "unknown"
	first.checkpoint.rng_state = "0"
	first.metrics.raw_piece_ids.clear()
	assert_eq(g.generate(b, [], cp), expected)
	assert_eq(b[63], 0)
