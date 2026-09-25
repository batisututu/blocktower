extends "res://addons/gut/test.gd"
## 시안의 모달 입력 격리와 취소를 검사한다. 실제 저장/게임 규칙 검사가 아니다.

const Preview = preload("res://scenes/main.tscn")
var preview

func before_each():
	preview = Preview.instantiate()
	add_child_autofree(preview)
	await get_tree().process_frame

func _button_named(root: Node, value: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if button.text == value:
			return button
	return null

func test_auto_cancel_preserves_pending_lines_and_restores_focus():
	preview.state_id = "cross"
	preview._rebuild()
	var before: Array = preview.board.duplicate()
	_button_named(preview.content, "자동 지우기  OFF").pressed.emit()
	assert_true(is_instance_valid(preview.modal), "pending lines require confirmation")
	assert_false(preview.automatic, "opening confirmation changes no mode")
	assert_gt(preview.background_focus.size(), 0, "background buttons are isolated")
	var background: Array = preview.background_focus.duplicate()
	assert_true(background.all(func(control): return control.focus_mode == Control.FOCUS_NONE))
	_button_named(preview.modal, "취소").pressed.emit()
	assert_eq(preview.board, before, "cancel preserves the pending board")
	assert_false(preview.automatic)
	assert_false(is_instance_valid(preview.modal))
	assert_true(background.all(func(control): return control.focus_mode == Control.FOCUS_ALL))
	await get_tree().process_frame

func test_confirm_and_navigation_are_preview_only_transitions():
	preview.state_id = "cross"
	preview._rebuild()
	_button_named(preview.content, "자동 지우기  OFF").pressed.emit()
	var action := _button_named(preview.modal, "지우고 자동 켜기")
	assert_eq(action.get_theme_color("font_focus_color"), preview.BG, "focused primary retains dark text")
	action.pressed.emit()
	assert_true(preview.automatic)
	assert_eq(preview.state_id, "basic")
	assert_false(is_instance_valid(preview.modal))
	preview._open_tower()
	assert_eq(preview.screen_id, "tower")
	_button_named(preview.content, "퍼즐에서 계속 쌓기").pressed.emit()
	assert_eq(preview.screen_id, "puzzle")
	await get_tree().process_frame
