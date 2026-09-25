extends Control
## W0의 실제 에셋/레이아웃 검토 화면. 게임 로직·성장·저장은 W2/W3에서 연결한다.

const Fixtures = preload("res://scripts/presentation/preview_fixtures.gd")
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const CELL = preload("res://assets/vector/cell_b.svg")
const FRAME = preload("res://assets/vector/cell_frame.svg")
const EMPTY = preload("res://assets/vector/cell_empty.svg")
const VALID = preload("res://assets/vector/state_valid.svg")
const INVALID = preload("res://assets/vector/state_invalid.svg")
const FLOOR = preload("res://assets/vector/wood_floor.svg")
const ROOF = preload("res://assets/vector/wood_roof.svg")
const BASE = preload("res://assets/vector/wood_base.svg")
const CORNICE = preload("res://assets/vector/wood_cornice.svg")
const COLORS: Array[Color] = [Color("c9775f"), Color("cda453"), Color("83aa99"), Color("7b9cac"), Color("ba9672"), Color("9889ab")]
const BG = Color("182126")
const SURFACE = Color("243238")
const TEXT = Color("f3eddf")
const MUTED = Color("b8c6c4")
const GOLD = Color("dfba66")
const MINT = Color("bdebd5")

var state_id := "basic"
var screen_id := "puzzle"
var floor_count := 13
var automatic := false
var reduced_motion := true
var board: Array[int] = []
var lines: Dictionary = {}
var board_rect := Rect2()
var tray_rect := Rect2()
var selected_slot := -1
var content: Control
var modal: Control
var bold: FontVariation
var regular: FontVariation
var capture_path := ""
var capture_auto_confirmation := false
var compact := false
var background_focus: Array[Control] = []

func _ready() -> void:
	regular = FontVariation.new()
	regular.base_font = FONT
	regular.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 400}
	bold = FontVariation.new()
	bold.base_font = FONT
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto-confirm":
			capture_auto_confirmation = true
		if arg.begins_with("--review-size="):
			var dimensions := arg.trim_prefix("--review-size=").split("x")
			if dimensions.size() == 2:
				get_window().content_scale_size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
		if arg.begins_with("--state="):
			state_id = arg.trim_prefix("--state=")
		if arg.begins_with("--screen="):
			screen_id = arg.trim_prefix("--screen=")
		if arg.begins_with("--floors="):
			floor_count = clampi(arg.trim_prefix("--floors=").to_int(), 0, 30)
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
	if state_id not in Fixtures.STATE_IDS:
		state_id = "basic"
	resized.connect(_rebuild)
	_rebuild()
	if capture_auto_confirmation:
		_toggle_auto()
	if not capture_path.is_empty():
		_capture.call_deferred()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Design capture requires a rendering display, not --headless")
		get_tree().quit(2)
		return
	for frame in range(8):
		await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(capture_path)
	print("DESIGN_CAPTURE ", capture_path, " result=", result, " viewport=", size)
	get_tree().quit(0 if result == OK else 2)

func _style(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.border_color = border
	return style

func _label(parent: Control, value: String, rect: Rect2, font_size: int, color: Color = TEXT, strong: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", bold if strong else regular)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Control, value: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", bold)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", BG if primary else TEXT)
	button.add_theme_color_override("font_hover_color", BG if primary else TEXT)
	button.add_theme_color_override("font_pressed_color", BG if primary else TEXT)
	button.add_theme_color_override("font_focus_color", BG if primary else TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else SURFACE))
	button.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.08) if primary else SURFACE.lightened(0.07)))
	button.add_theme_stylebox_override("pressed", _style(GOLD.darkened(0.1) if primary else SURFACE.darkened(0.15)))
	button.add_theme_stylebox_override("disabled", _style(Color("29363b")))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, MINT))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _icon_button(parent: Control, icon: String, rect: Rect2, tooltip: String, callback: Callable) -> Button:
	var button := _button(parent, "", rect, callback)
	button.icon = load("res://assets/vector/icon_%s.svg" % icon)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = tooltip
	return button

func _rebuild() -> void:
	if not is_node_ready():
		return
	_close_modal()
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	modal = null
	compact = size.y < 700
	board = Fixtures.board_for(state_id)
	lines = Fixtures.pending_lines(board)
	if screen_id == "tower":
		_build_tower()
	else:
		_build_puzzle()
	queue_redraw()

func _build_puzzle() -> void:
	var w := size.x
	var top := 8.0 if compact else 20.0
	_label(content, "BLOCKTOWER", Rect2(18, top, w - 92, 40), 22, TEXT, true)
	_icon_button(content, "settings", Rect2(w - 64, top - 4, 48, 48), "디자인 검토 · 상태 선택", _show_states)
	var score_y := 56.0 if compact else 82.0
	_label(content, "현재 점수", Rect2(20, score_y, 140, 18), 12, MUTED)
	_label(content, "2,480", Rect2(18, score_y + 17, 150, 42), 32, TEXT, true)
	_label(content, "최고 5,240", Rect2(w - 160, score_y, 140, 18), 12, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	var auto_button := _button(content, "자동 지우기  " + ("ON" if automatic else "OFF"), Rect2(w - 158, score_y + 18, 140, 48), _toggle_auto)
	auto_button.add_theme_font_size_override("font_size", 13)
	var growth_h := 48.0 if compact else 62.0
	var clear_h := 48.0 if compact else 56.0
	var tray_h := 58.0 if compact else 86.0
	var growth_y := size.y - 18.0 - growth_h
	var clear_y := growth_y - 12.0 - clear_h
	var tray_y := clear_y - 12.0 - tray_h
	var board_top := 130.0 if compact else 180.0
	var side := minf(w - 32.0, tray_y - board_top - 36.0)
	board_rect = Rect2((w - side) / 2, board_top, side, side)
	tray_rect = Rect2(16, tray_y, w - 32, tray_h)
	var hint := "조각을 놓고, 완성한 줄을 지워 보세요"
	if int(lines["count"]) > 0:
		hint = "%d줄 완성 · 지금 지우거나 더 모을 수 있어요" % int(lines["count"])
		if state_id == "blocked":
			hint = "%d줄 완성 · 먼저 지우면 조각을 놓을 수 있어요" % int(lines["count"])
	elif state_id == "game_over":
		hint = "놓을 수 있는 조각이 없어요"
	elif state_id == "invalid":
		hint = "겹친 칸에는 놓을 수 없어요"
	elif state_id == "valid":
		hint = "윤곽 안에 놓을 수 있어요"
	_label(content, hint, Rect2(12, board_rect.end.y + 3, w - 24, 25), 11 if compact else 12, MINT if int(lines["count"]) > 0 else MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	for slot in range(3):
		var slot_rect := Rect2(tray_rect.position + Vector2(slot * tray_rect.size.x / 3.0, 0), Vector2(tray_rect.size.x / 3.0 - 4, tray_h))
		var target := Button.new()
		target.position = slot_rect.position
		target.size = slot_rect.size
		target.tooltip_text = "조각 %d · 프리뷰 상태 확인" % (slot + 1)
		for style_name in ["normal", "hover", "pressed"]:
			target.add_theme_stylebox_override(style_name, _style(Color.TRANSPARENT))
		target.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, MINT))
		target.pressed.connect(_select_slot.bind(slot))
		content.add_child(target)
	var clear_text := "%d줄 클리어" % int(lines["count"]) if int(lines["count"]) > 0 else "완성한 줄이 없어요"
	var clear_button := _button(content, clear_text, Rect2(16, clear_y, w - 32, clear_h), _clear_preview, true)
	clear_button.disabled = int(lines["count"]) == 0
	var tower_button := _button(content, "", Rect2(16, growth_y, w - 32, growth_h), _open_tower)
	_label(tower_button, "내 탑", Rect2(16, 5, 70, growth_h - 10), 14, MUTED)
	_label(tower_button, "13층", Rect2(80, 5, 72, growth_h - 10), 23, TEXT, true)
	_label(tower_button, "다음 구간까지 7층", Rect2(w - 204, 5, 156, growth_h - 10), 11, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(content, "시안 · 실제 진행은 저장되지 않아요", Rect2(0, size.y - 17, w, 15), 9, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	if state_id == "game_over":
		_show_dialog("이번 퍼즐은 여기까지", "쌓은 13층은 그대로 남아요.\n새 퍼즐에서 계속 쌓아 보세요.", "새 퍼즐 시안", _reset_preview, "내 탑 보기", _open_tower)
	elif state_id == "save_error":
		_show_dialog("진행을 저장하지 못했어요", "저장 공간을 확인하고 다시 시도해 주세요.\n완료되지 않은 행동은 반영하지 않아요.", "다시 시도", _retry_preview, "닫기", _close_modal)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if board.is_empty():
		return
	if screen_id == "tower":
		_draw_tower()
		return
	draw_style_box(_style(Color("10191d"), Color("425156"), 12), board_rect.grow(5))
	var step := board_rect.size.x / 8.0
	for y in range(8):
		for x in range(8):
			var cell_rect := Rect2(board_rect.position + Vector2(x, y) * step, Vector2.ONE * step)
			var index: int = board[y * 8 + x]
			draw_texture_rect(EMPTY if index < 0 else CELL, cell_rect, false, Color.WHITE if index < 0 else COLORS[index])
			if index >= 0:
				draw_texture_rect(FRAME, cell_rect, false)
	for row: int in lines["rows"]:
		var line_rect := Rect2(board_rect.position + Vector2(0, row * step), Vector2(board_rect.size.x, step))
		draw_style_box(_style(Color(0.74, 0.92, 0.83, 0.10), MINT, 5), line_rect.grow(-1))
		draw_circle(line_rect.position + Vector2(-6, step / 2), 2.5, MINT)
	for column: int in lines["columns"]:
		var line_rect := Rect2(board_rect.position + Vector2(column * step, 0), Vector2(step, board_rect.size.y))
		draw_style_box(_style(Color(0.74, 0.92, 0.83, 0.10), MINT, 5), line_rect.grow(-1))
		draw_circle(line_rect.position + Vector2(step / 2, -6), 2.5, MINT)
	if state_id in ["valid", "invalid"]:
		var anchor := Vector2i(5, 0) if state_id == "valid" else Vector2i(0, 0)
		for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var cell_rect := Rect2(board_rect.position + Vector2(anchor + offset) * step, Vector2.ONE * step)
			draw_texture_rect(VALID if state_id == "valid" else INVALID, cell_rect, false)
	var tray: Array = Fixtures.tray_for(state_id)
	for slot in range(3):
		var rect := Rect2(tray_rect.position + Vector2(slot * tray_rect.size.x / 3.0, 0), Vector2(tray_rect.size.x / 3.0 - 4, tray_rect.size.y))
		draw_style_box(_style(SURFACE, GOLD if slot == selected_slot else Color.TRANSPARENT, 10), rect)
		var cell_size := 23.0 if compact else 29.0
		var max_cell := Vector2i.ZERO
		for cell: Vector2i in tray[slot]:
			max_cell = max_cell.max(cell)
		var extent := Vector2(max_cell + Vector2i.ONE) * cell_size
		var origin := rect.position + (rect.size - extent) / 2.0
		for cell: Vector2i in tray[slot]:
			draw_texture_rect(CELL, Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size), false, COLORS[[0, 1, 3][slot]])
			draw_texture_rect(FRAME, Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size), false)

func _build_tower() -> void:
	_icon_button(content, "back", Rect2(16, 16, 48, 48), "퍼즐로 돌아가기", _open_puzzle)
	_label(content, "내 탑", Rect2(76, 16, size.x - 152, 48), 20, TEXT, true)
	_icon_button(content, "settings", Rect2(size.x - 64, 16, 48, 48), "디자인 검토 · 층수 선택", _show_states)
	_label(content, "%d층" % floor_count, Rect2(16, 78, size.x - 32, 50), 38, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(content, "%d개 구간 완성 · 목재" % (floor_count / 10), Rect2(16, 131, size.x - 32, 24), 13, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_button(content, "퍼즐에서 계속 쌓기", Rect2(16, size.y - 76, size.x - 32, 56), _open_puzzle, true)
	_label(content, "시안 · 구간은 10층씩 완성돼요", Rect2(0, size.y - 18, size.x, 16), 10, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	if floor_count == 0:
		_label(content, "첫 줄을 지우면\n나만의 탑이 시작돼요", Rect2(16, size.y / 2 - 50, size.x - 32, 90), 20, TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_tower() -> void:
	if floor_count == 0:
		return
	var available := size.y - 270.0
	var scale_factor := minf(1.25, available / (float(floor_count) * 40 + 78))
	var width := 160 * scale_factor
	var floor_h := 40 * scale_factor
	var x := (size.x - width) / 2
	var bottom := size.y - 115.0
	draw_texture_rect(BASE, Rect2(x, bottom - 24 * scale_factor, width, 24 * scale_factor), false)
	var y := bottom - 24 * scale_factor
	for index in range(floor_count):
		y -= floor_h
		draw_texture_rect(FLOOR, Rect2(x, y, width, floor_h), false)
		if (index + 1) % 10 == 0 and index + 1 < floor_count:
			draw_texture_rect(CORNICE, Rect2(x, y - 5 * scale_factor, width, 12 * scale_factor), false)
	draw_texture_rect(ROOF, Rect2(x, y - 42 * scale_factor, width, 42 * scale_factor), false)

func _select_slot(slot: int) -> void:
	selected_slot = slot
	state_id = "valid"
	_rebuild()

func _open_tower() -> void:
	screen_id = "tower"
	_rebuild()

func _open_puzzle() -> void:
	screen_id = "puzzle"
	_rebuild()

func _reset_preview() -> void:
	state_id = "basic"
	_rebuild()

func _retry_preview() -> void:
	_show_dialog("저장 상태 검토", "이 화면은 저장 실패 안내 시안이에요.\n실제 저장은 아직 연결되지 않았어요.", "화면으로 돌아가기", _reset_preview)

func _clear_preview() -> void:
	var count := int(lines["count"])
	_show_dialog("%d줄을 지우면" % count, "+%d점 · 탑 +%d층\n실제 진행을 변경하지 않는 화면 시안이에요." % [count * 100 * mini(100 + 20 * (count - 1), 160) / 100, count], "확인", _close_modal)

func _toggle_auto() -> void:
	if not automatic and int(lines["count"]) > 0:
		var count := int(lines["count"])
		_show_dialog("자동으로 지울까요?", "대기 중인 %d줄이 함께 지워져요.\n+%d점 · 탑 +%d층" % [count, count * 100 * mini(100 + 20 * (count - 1), 160) / 100, count], "지우고 자동 켜기", _confirm_auto, "취소", _close_modal)
	else:
		automatic = not automatic
		_rebuild()

func _confirm_auto() -> void:
	automatic = true
	state_id = "basic"
	_rebuild()

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
	for control in background_focus:
		if is_instance_valid(control):
			control.focus_mode = Control.FOCUS_ALL
	background_focus.clear()

func _lock_background_focus() -> void:
	# 모달이 열려 있을 때 Tab/Enter로 뒤쪽 버튼을 실행하지 못하게 한다.
	for control in content.find_children("*", "BaseButton", true, false):
		if control.focus_mode == Control.FOCUS_ALL:
			background_focus.append(control)
			control.focus_mode = Control.FOCUS_NONE

func _show_dialog(title: String, message: String, primary_text: String, primary_action: Callable, secondary_text: String = "", secondary_action: Callable = Callable()) -> void:
	_close_modal()
	_lock_background_focus()
	modal = ColorRect.new()
	modal.color = Color(0.025, 0.05, 0.06, 0.85)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(modal)
	var height := 260.0 if not secondary_text.is_empty() else 202.0
	var panel := Panel.new()
	panel.position = Vector2(20, (size.y - height) / 2.0)
	panel.size = Vector2(size.x - 40, height)
	panel.add_theme_stylebox_override("panel", _style(SURFACE, Color("556466"), 16))
	modal.add_child(panel)
	_label(panel, title, Rect2(20, 19, panel.size.x - 40, 34), 20, TEXT, true)
	var description := _label(panel, message, Rect2(20, 64, panel.size.x - 40, 68), 13, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var primary := _button(panel, primary_text, Rect2(16, 138, panel.size.x - 32, 48), primary_action, true)
	if not secondary_text.is_empty():
		_button(panel, secondary_text, Rect2(16, 196, panel.size.x - 32, 48), secondary_action)
	primary.grab_focus()

func _show_states() -> void:
	_close_modal()
	_lock_background_focus()
	modal = ColorRect.new()
	modal.color = BG
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(modal)
	_label(modal, "디자인 검토", Rect2(20, 12, size.x - 92, 48), 22, TEXT, true)
	_icon_button(modal, "close", Rect2(size.x - 64, 12, 48, 48), "닫기", _close_modal).grab_focus()
	_label(modal, "상태를 선택해 가독성을 확인하세요", Rect2(20, 66, size.x - 40, 28), 13, MUTED)
	var values: Array = [0, 1, 9, 10, 11, 13, 30] if screen_id == "tower" else Fixtures.STATE_IDS
	for index in range(values.size()):
		var label_text := "%d층" % int(values[index]) if screen_id == "tower" else Fixtures.STATE_NAMES[index]
		_button(modal, label_text, Rect2(20, 106 + index * 52, size.x - 40, 48), _choose_state.bind(str(values[index])))

func _choose_state(value: String) -> void:
	if screen_id == "tower":
		floor_count = value.to_int()
	else:
		state_id = value
	_rebuild()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal):
			_close_modal()
		elif screen_id == "tower":
			_open_puzzle()
		get_viewport().set_input_as_handled()
