extends RefCounted
## 디자인 검토 전용 데이터. 실제 세션이나 저장 상태를 변경하지 않는다.

const STATE_IDS: Array[String] = ["basic", "ready", "cross", "valid", "invalid", "blocked", "game_over", "save_error"]
const STATE_NAMES: Array[String] = ["기본 화면", "1줄 완성", "교차 2줄", "배치 가능", "배치 불가", "막힘 · 클리어 가능", "게임오버", "저장 실패"]

static func board_for(state_id: String) -> Array[int]:
	var board: Array[int] = []
	board.resize(64)
	board.fill(-1)
	var rows: Array[String] = ["00.1....", "0..11...", ".22..3..", ".2.4433.", "........", "55..1...", ".5..111.", "..444..."]
	for y in range(8):
		for x in range(8):
			if rows[y][x] != ".":
				board[y * 8 + x] = int(rows[y][x])
	if state_id in ["ready", "cross"]:
		for x in range(8):
			board[5 * 8 + x] = 2
	if state_id == "cross":
		for y in range(8):
			board[y * 8 + 3] = 2
	if state_id == "blocked":
		board.fill(1)
	if state_id == "game_over":
		for y in range(8):
			for x in range(8):
				board[y * 8 + x] = 3 if (x + y) % 2 == 0 else -1
	return board

static func pending_lines(board: Array[int]) -> Dictionary:
	var rows: Array[int] = []
	var columns: Array[int] = []
	for axis in range(8):
		var row_full := true
		var column_full := true
		for cell in range(8):
			row_full = row_full and board[axis * 8 + cell] >= 0
			column_full = column_full and board[cell * 8 + axis] >= 0
		if row_full:
			rows.append(axis)
		if column_full:
			columns.append(axis)
	return {"rows": rows, "columns": columns, "count": rows.size() + columns.size()}

static func tray_for(state_id: String) -> Array:
	if state_id == "game_over":
		return [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], [Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(0, 0), Vector2i(0, 1)]]
	return [[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)], [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]]
