extends SceneTree
## 독립 좌표 검증과 고정 보드 시퀀스로 세 정책을 비교한다. 플레이어 모델은 아니다.
const Generator = preload("res://scripts/core/generation/piece_generator.gd")
const Config = preload("res://scripts/core/generation/piece_generator_config.gd")
var failures: Array[String] = []

func post_clear(board: PackedByteArray) -> PackedByteArray:
	var remove := {}
	for i in range(8):
		var row := true
		var column := true
		for j in range(8):
			row = row and board[i * 8 + j] == 1
			column = column and board[j * 8 + i] == 1
		for j in range(8):
			if row: remove[i * 8 + j] = true
			if column: remove[j * 8 + i] = true
	var result := board.duplicate()
	for cell in remove: result[cell] = 0
	return result

func can_place(board: PackedByteArray, cells: Array, x: int, y: int) -> bool:
	for cell in cells:
		if x + cell.x < 0 or x + cell.x >= 8 or y + cell.y < 0 or y + cell.y >= 8: return false
		if board[(y + cell.y) * 8 + x + cell.x] != 0: return false
	return true

func make_board(index: int, rng: RandomNumberGenerator) -> PackedByteArray:
	var board := PackedByteArray()
	board.resize(64)
	var kind := index % 10
	if kind == 0: return board
	if kind == 1:
		board.fill(1)
		return board
	if kind == 2:
		for cell in range(64): board[cell] = (cell / 8 + cell % 8) % 2
		return board
	var density: float = [0.25, 0.5, 0.7, 0.85, 0.95, 0.7, 0.9][kind - 3]
	for cell in range(64): board[cell] = int(rng.randf() < density)
	if kind == 8:
		for i in range(8):
			board[3 * 8 + i] = 1
			board[i * 8 + 6] = 1
	if kind == 9:
		# 완성 줄 없이 한 칸 구멍만 남은 대각선 보드.
		board.fill(1)
		for i in range(8): board[i * 8 + i] = 0
	return board

func check(condition: bool, message: String) -> void:
	if not condition and failures.size() < 20: failures.append(message)

func run_policy(policy: String, count: int) -> Dictionary:
	var config := Config.new()
	config.supply_policy_version = policy
	var generator = Generator.create(config).generator
	var snapshot: Dictionary = generator.config_snapshot()
	var pieces := {}
	for piece in generator.catalog(): pieces[piece.id] = piece
	var checkpoint: Dictionary = generator.initial_checkpoint("20260921").checkpoint
	var board_rng := RandomNumberGenerator.new()
	board_rng.seed = 821913
	var times: Array[int] = []
	var stats := {"policy": policy, "trays": count, "attempts": 0, "rerolls": 0,
		"easy_replacements": 0, "replacement_slots": [0, 0, 0], "fallback": {},
		"statuses": {}, "witnesses": 0, "requires_clear": 0, "final_cells": 0,
		"raw_family_counts": {}, "raw_variant_counts": {}, "final_family_counts": {}, "config": snapshot}
	for index in range(count):
		var board := make_board(index, board_rng)
		var before := board.duplicate()
		var original := checkpoint.duplicate(true)
		var start := Time.get_ticks_usec()
		var result: Dictionary = generator.generate(board, [], checkpoint)
		times.append(Time.get_ticks_usec() - start)
		if not result.ok:
			check(false, "generate error: %s" % result)
			break
		check(board == before and checkpoint == original, "input mutation")
		check(result.piece_ids.size() == 3, "tray size")
		check(result.metrics.attempts >= 1 and result.metrics.attempts <= 4, "unbounded attempts")
		var easy := false
		for id in result.piece_ids:
			check(pieces.has(id), "unknown piece")
			var piece: Dictionary = pieces[id]
			check(snapshot.family_weights[piece.family_index] > 0, "disabled piece generated")
			easy = easy or piece.family in snapshot.easy_families
			stats.final_cells += piece.cells.size()
			stats.final_family_counts[piece.family] = stats.final_family_counts.get(piece.family, 0) + 1
		if policy != Generator.RAW: check(easy, "missing easy family")
		if policy == Generator.SOFT: check(result.guarantee_met, "default one-move guarantee failed")
		var witness: Dictionary = result.decision.witness
		check(result.guarantee_met == not witness.is_empty(), "guarantee flag mismatch")
		if not witness.is_empty():
			stats.witnesses += 1
			check(result.piece_ids[witness.slot] == witness.piece_id, "witness slot mismatch")
			var target := post_clear(board) if witness.requires_clear else board
			check(can_place(target, pieces[witness.piece_id].cells, witness.x, witness.y), "invalid witness")
			if witness.requires_clear: stats.requires_clear += 1
		if index % 1000 == 0:
			var restored: Dictionary = JSON.parse_string(JSON.stringify(checkpoint))
			check(generator.generate(board, [], restored) == result, "JSON replay mismatch")
		for id in result.metrics.raw_piece_ids:
			var family: String = pieces[id].family
			stats.raw_family_counts[family] = stats.raw_family_counts.get(family, 0) + 1
			stats.raw_variant_counts[id] = stats.raw_variant_counts.get(id, 0) + 1
		for key in ["attempts", "rerolls", "easy_replacements"]: stats[key] += result.metrics[key]
		for slot in result.metrics.replacement_slots: stats.replacement_slots[slot] += 1
		var fallback: String = result.metrics.fallback
		stats.fallback[fallback] = stats.fallback.get(fallback, 0) + 1
		var status: String = result.decision.status
		stats.statuses[status] = stats.statuses.get(status, 0) + 1
		checkpoint = result.checkpoint
		if (index + 1) % 10000 == 0: print("%s: %d/%d" % [policy, index + 1, count])
	times.sort()
	stats["latency_us"] = {"p50": times[int(times.size() * 0.5)], "p95": times[int(times.size() * 0.95)], "p99": times[int(times.size() * 0.99)], "max": times[-1]}
	stats["mean_cells_per_tray"] = float(stats.final_cells) / count
	stats["last_checkpoint"] = checkpoint
	return stats

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 100000
	var output := args[1] if args.size() > 1 else "user://piece_generation_simulation.json"
	if count < 10 or count > 1000000:
		printerr("count must be 10..1000000")
		quit(1)
		return
	var results := []
	for policy in [Generator.RAW, Generator.EASY, Generator.SOFT]: results.append(run_policy(policy, count))
	var report := {"ok": failures.is_empty(), "utc": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(),
		"board_seed": "821913", "generator_seed": "20260921", "board_mix": "10 equally repeated synthetic classes; no player model",
		"failures": failures, "policies": results}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Cannot open report: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Simulation complete: ok=%s, trays=%d, report=%s" % [report.ok, count * 3, output])
	quit(0 if report.ok else 1)
