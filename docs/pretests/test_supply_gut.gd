extends "res://addons/gut/test.gd"
const Supply = preload("res://examples/piece_supply_v0_1.gd")

func test_crossing_lines_count_as_two_and_keep_manual_clear_available():
	var board := PackedByteArray()
	board.resize(64)
	for i in range(8):
		board[3 * 8 + i] = 1
		board[i * 8 + 4] = 1
	assert_eq(Supply.pending_line_count(board), 2)
	var full := board.duplicate()
	full.fill(1)
	var ids: Array[String] = ["square3_v0"]
	assert_eq(Supply.tray_status(full, ids), "MUST_CLEAR")

func test_empty_tray_requires_refill_before_game_over():
	var board := PackedByteArray()
	board.resize(64)
	board.fill(1)
	var ids: Array[String] = []
	assert_eq(Supply.tray_status(board, ids), "REFILL_REQUIRED")

func test_rng_roundtrip_preserves_next_batch():
	var initial := Supply.initial_rng_state(37)
	var batch := Supply.draw_batch(37, initial)
	var restored: Dictionary = JSON.parse_string(JSON.stringify(batch))
	assert_eq(Supply.draw_batch(37, int(batch["rng_state"])),
		Supply.draw_batch(int(restored["rng_seed"]), int(restored["rng_state"])))

func test_unknown_id_is_rejected_even_when_another_piece_fits():
	var board := PackedByteArray()
	board.resize(64)
	var ids: Array[String] = ["single_v0", "unknown"]
	assert_eq(Supply.tray_status(board, ids), "INVALID_INPUT")

func test_board_status_does_not_modify_input():
	var board := PackedByteArray()
	board.resize(64)
	board[4] = 1
	var before := board.duplicate()
	var ids: Array[String] = ["square2_v0", "single_v0"]
	assert_eq(Supply.tray_status(board, ids), "CAN_PLACE")
	assert_eq(board, before)

func test_integer_weight_boundaries_and_zero_weight():
	var weights: Array[int] = [2, 0, 3]
	assert_eq(Supply.ticket_index(weights, 0), 0)
	assert_eq(Supply.ticket_index(weights, 1), 0)
	assert_eq(Supply.ticket_index(weights, 2), 2)
	assert_eq(Supply.ticket_index(weights, 4), 2)
	assert_eq(Supply.ticket_index(weights, 5), -1)
