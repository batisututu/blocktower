extends Node
## 앱 시작과 재조회는 같은 저장 세션을 실제 퍼즐 화면에 연결한다.
const SavedGame = preload("res://scripts/application/saved_game.gd")
const PuzzleScreen = preload("res://scripts/presentation/puzzle_screen.gd")
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
var service := SavedGame.new()
var save_directory := "user://save_v1"
var game_session: RefCounted
var startup_result: Dictionary
var _notice: CanvasLayer
var screen: Control
var _application_blockers: Dictionary = {}
var _notice_message := ""
var _notice_retry := false
var _notice_epoch := 0

func _input(_event: InputEvent) -> void:
    if not _application_blockers.is_empty(): get_viewport().set_input_as_handled()

func _ready() -> void:
    if OS.get_name() == "Android": get_tree().quit_on_go_back = false
    _boot()

func _notification(what: int) -> void:
    var was_active := _application_blockers.is_empty()
    match what:
        NOTIFICATION_APPLICATION_FOCUS_OUT: _application_blockers["focus"] = true
        NOTIFICATION_APPLICATION_PAUSED: _application_blockers["pause"] = true
        NOTIFICATION_APPLICATION_FOCUS_IN: _application_blockers.erase("focus")
        NOTIFICATION_APPLICATION_RESUMED: _application_blockers.erase("pause")
    var active := _application_blockers.is_empty()
    if active != was_active:
        _notice_epoch += 1
        if is_instance_valid(screen): screen.set_application_active(active)
        # OS 알림 전파 중에는 루트 자식 목록이 잠겨 있으므로 UI 교체를 지연한다.
        if active and is_instance_valid(_notice):
            _refresh_notice.call_deferred(_notice, _notice_epoch)
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if not active: return
        # 모달과 탑의 뒤로가기를 처리한 뒤 루트 화면에서만 종료한다.
        if is_instance_valid(_notice) or not is_instance_valid(screen) or not screen.handle_back():
            get_tree().quit()

func _boot() -> void:
    if is_instance_valid(screen):
        remove_child(screen)
        screen.queue_free()
        screen = null
    if is_instance_valid(_notice):
        remove_child(_notice)
        _notice.queue_free()
        _notice = null
    startup_result = service.boot(save_directory)
    if not startup_result.ok:
        game_session = null
        _show_notice("저장 기록을 불러오지 못했어요.\n기록은 그대로 보관하고 있습니다.\n다시 시도해 주세요.", true)
        return
    game_session = startup_result.session
    screen = PuzzleScreen.new()
    screen.reload_requested.connect(func():
        if _application_blockers.is_empty(): _boot())
    add_child(screen)
    screen.attach(game_session, save_directory.path_join("presentation.json"))
    screen.set_application_active(_application_blockers.is_empty())
    if startup_result.get("recovered", false):
        screen.controller.open_modal()
        screen.hide()
        _show_notice("일부 저장 기록이 손상되어\n정상적으로 읽을 수 있는 기록으로 복구했어요.\n최근 진행 일부가 되돌아갔을 수 있습니다.", false)

func _refresh_notice(expected: CanvasLayer, epoch: int) -> void:
    if not is_inside_tree() or not _application_blockers.is_empty(): return
    if not is_instance_valid(expected) or expected != _notice or epoch != _notice_epoch: return
    _show_notice(_notice_message, _notice_retry)

func _show_notice(message: String, retry: bool) -> void:
    if is_instance_valid(_notice):
        remove_child(_notice)
        _notice.queue_free()
    _notice_message = message
    _notice_retry = retry
    _notice = CanvasLayer.new()
    _notice.layer = 100
    add_child(_notice)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.04, 0.07, 0.09, 0.96)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _notice.add_child(backdrop)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.add_child(center)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 24)
    center.add_child(column)
    var label := Label.new()
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_override("font", FONT)
    label.add_theme_font_size_override("font_size", 16)
    column.add_child(label)
    var button := Button.new()
    button.text = "다시 시도" if retry else "확인"
    button.custom_minimum_size = Vector2(220, 48)
    button.add_theme_font_override("font", FONT)
    column.add_child(button)
    var owner_notice := _notice
    var epoch := _notice_epoch
    button.pressed.connect(func():
        if not _application_blockers.is_empty() or owner_notice != _notice or epoch != _notice_epoch: return
        if retry:
            _boot()
            return
        remove_child(_notice)
        _notice.queue_free()
        _notice = null
        if is_instance_valid(screen):
            screen.show()
            screen.controller.cancel())
    button.grab_focus()
