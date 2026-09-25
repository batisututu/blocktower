extends "res://addons/gut/test.gd"
const Session = preload("res://scripts/core/game_session.gd")
const Memory = preload("res://scripts/core/memory_save_repository.gd")
const App = preload("res://scripts/application/app_root.gd")
var repository
var session
var app

class BootService:
    extends "res://scripts/application/saved_game.gd"
    var value: RefCounted
    var recovered := false
    var fail := false
    var calls := 0
    func boot(_directory: String = "user://save_v1", _initial_id: String = "", _initial_seed: String = "") -> Dictionary:
        calls += 1
        return {"ok": false, "error": "SAVE_CORRUPT"} if fail else {"ok": true, "session": value, "recovered": recovered}

func before_each():
    repository = Memory.new()
    session = Session.start(repository,"lifecycle-test","20260921").session
    app = App.new()
    var service := BootService.new()
    service.value = session
    app.service = service
    app.save_directory = "user://w5_lifecycle/%d_%d" % [Time.get_ticks_usec(),randi()]
    add_child_autofree(app)
    app.screen.preferences.values.muted = true

func suspend():
    app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)

func resume():
    app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
    app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

func cross():
    var state: Dictionary = session.snapshot()
    state.occupancy.fill(0)
    state.cell_style.fill(0)
    for x in range(8):
        state.occupancy[x] = 1
        state.cell_style[x] = 1
    repository = Memory.new()
    repository.commit(state,-1)
    session = Session.resume(repository).session
    app.service.value = session
    app._boot()
    app.screen.preferences.values.muted = true

func test_notification_pair_order_duplicates_and_controller_gate():
    var before: Dictionary = session.snapshot()
    suspend()
    app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
    app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    assert_false(app.screen.controller.application_active)
    assert_false(app.screen.controller.begin_drag(0,0))
    assert_eq(app.screen.controller.submit("SET_AUTO",{"enabled":true}).error,"SUSPENDED")
    assert_eq(app.screen.controller.submit_modal("NEW_RUN",{}).error,"SUSPENDED")
    app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
    assert_true(app.screen.controller.application_active)
    assert_eq(session.snapshot(),before)
    assert_null(app.screen.modal)
    assert_eq(app.service.calls,1,"Resume never reboots or saves")
    app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
    assert_eq(session.snapshot(),before)

func test_drag_cancel_late_release_and_new_press_after_resume():
    var screen = app.screen
    var before: Dictionary = session.snapshot()
    screen._pointer(4,screen.tray_rects[0].get_center(),true,false)
    assert_eq(screen.controller.phase,"dragging")
    suspend()
    assert_true(screen.drag_piece.is_empty())
    resume()
    screen._pointer(4,screen.board_rect.get_center(),false,true)
    assert_eq(session.snapshot(),before)
    assert_eq(screen.controller.pointer,-2)
    screen._pointer(5,screen.tray_rects[0].get_center(),true,false)
    assert_eq(screen.controller.phase,"dragging")
    screen._pointer(6,screen.board_rect.get_center(),false,true)
    assert_eq(screen.controller.pointer,5,"Second pointer cannot complete the drag")
    assert_eq(session.snapshot(),before)

func test_paused_clear_keeps_commit_and_does_not_replay_tail():
    cross()
    var screen = app.screen
    screen._clear()
    var committed: Dictionary = session.snapshot()
    assert_gt(screen.remnants.size(),0)
    var cue_count: int = screen.feedback.played.size()
    suspend()
    assert_eq(screen.effect_alpha,0.0)
    for player in screen.feedback.players: assert_false(player.playing)
    screen.feedback.cue("lock")
    assert_eq(screen.feedback.played.size(),cue_count)
    resume()
    await get_tree().create_timer(.55).timeout
    assert_eq(screen.score_label.text,str(committed.score))
    assert_eq(screen.feedback.played.size(),cue_count)
    assert_eq(session.snapshot(),committed)
    assert_eq(screen.controller.phase,"idle")

func test_old_confirmation_and_pressed_buttons_cannot_execute_after_resume():
    cross()
    var screen = app.screen
    screen._toggle_auto()
    var old_confirm: Button = screen.modal_actions.get_child(0)
    var old_auto: Button = screen.auto_button
    var before: Dictionary = session.snapshot()
    old_auto.button_down.emit()
    suspend()
    assert_eq(old_auto.scale,Vector2.ONE)
    old_confirm.pressed.emit()
    assert_eq(session.snapshot(),before)
    resume()
    old_confirm.pressed.emit()
    old_auto.pressed.emit()
    assert_eq(session.snapshot(),before)
    assert_null(screen.modal)
    screen.auto_button.pressed.emit()
    assert_not_null(screen.modal,"Fresh action still works")
    screen.modal_actions.get_child(0).pressed.emit()
    assert_eq(session.snapshot().revision,before.revision+1)
    assert_true(session.snapshot().auto_clear)

func test_old_preferences_and_tower_controls_are_inert():
    var screen = app.screen
    screen._open_tower()
    screen._settings()
    var panel: Control = screen.modal_content
    var old_check: CheckButton
    var old_volume: HSlider
    # 음량 슬라이더는 '음량' 이름과 같은 줄 컨테이너 안에 있다.
    var pending: Array[Node] = panel.get_children()
    while not pending.is_empty():
        var child: Node = pending.pop_front()
        if child is CheckButton and old_check == null: old_check = child
        if child is HSlider: old_volume = child
        pending.append_array(child.get_children())
    var original: Dictionary = screen.preferences.values.duplicate()
    var before: Dictionary = session.snapshot()
    suspend()
    resume()
    old_check.toggled.emit(true)
    old_volume.value_changed.emit(0.0)
    assert_eq(screen.preferences.values,original)
    assert_eq(screen.screen_id,"tower")
    assert_eq(session.snapshot(),before)

func test_mandatory_commit_recovery_survives_pause_and_reload_inherits_gate():
    repository.uncertain_next_commit = true
    app.screen.controller.submit("SET_AUTO",{"enabled":true,"confirmed":false})
    assert_eq(app.screen.controller.phase,"recovery")
    suspend()
    resume()
    assert_eq(app.screen.controller.phase,"recovery")
    assert_not_null(app.screen.modal)
    app.screen.handle_back()
    assert_not_null(app.screen.modal)
    suspend()
    app._boot()
    assert_false(app.screen.controller.application_active)
    assert_false(app.screen.controller.begin_drag(1,0))
    resume()
    # 실제 저장 재조회는 SavedGame/Repository 테스트가 별도로 검증한다.

func test_startup_recovery_notice_requires_fresh_confirmation_after_resume():
    app.service.recovered = true
    app._boot()
    var old_notice: CanvasLayer = app._notice
    var old_button: Button = old_notice.get_child(0).get_child(0).get_child(0).get_child(1)
    var before: Dictionary = session.snapshot()
    suspend()
    old_button.pressed.emit()
    assert_false(app.screen.visible)
    resume()
    old_button.pressed.emit()
    assert_false(app.screen.visible)
    assert_not_null(app._notice)
    await get_tree().process_frame
    var current: Button = app._notice.get_child(0).get_child(0).get_child(0).get_child(1)
    current.pressed.emit()
    assert_true(app.screen.visible)
    assert_null(app._notice)
    assert_eq(session.snapshot(),before)

func test_repeated_pause_resume_never_changes_rng_revision_or_replays_audio():
    var before: Dictionary = session.snapshot()
    for i in range(20):
        suspend()
        app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
        assert_false(app.screen.controller.application_active)
        app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
        assert_true(app.screen.controller.application_active)
        assert_eq(session.snapshot(),before)
        assert_eq(app.screen.feedback.played.size(),0)
        await get_tree().process_frame

func test_startup_failure_retry_is_blocked_until_fresh_active_notice():
    app.service.fail = true
    app._boot()
    assert_null(app.screen)
    var old_button: Button = app._notice.get_child(0).get_child(0).get_child(0).get_child(1)
    var calls: int = app.service.calls
    suspend()
    old_button.pressed.emit()
    assert_eq(app.service.calls,calls)
    resume()
    old_button.pressed.emit()
    assert_eq(app.service.calls,calls)
    app.service.fail = false
    await get_tree().process_frame
    var fresh_button: Button = app._notice.get_child(0).get_child(0).get_child(0).get_child(1)
    fresh_button.pressed.emit()
    assert_eq(app.service.calls,calls+1)
    assert_not_null(app.screen)
    assert_null(app._notice)
    assert_true(app.screen.controller.application_active)

func test_os_notification_propagation_keeps_root_notice_attached_and_stale_press_inert():
    for failed in [false, true]:
        app.service.fail = failed
        app.service.recovered = not failed
        app._boot()
        var old_notice: CanvasLayer = app._notice
        var old_button: Button = old_notice.get_child(0).get_child(0).get_child(0).get_child(1)
        var calls: int = app.service.calls
        # 직접 함수 호출과 달리 실제 OS 전파는 부모의 자식 목록을 잠근다.
        app.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
        app.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
        old_button.pressed.emit()
        assert_eq(app.service.calls, calls)
        assert_eq(app._notice, old_notice)
        if not failed: assert_false(app.screen.visible)
        await get_tree().process_frame
        assert_true(is_instance_valid(app._notice))
        assert_true(app._notice.is_inside_tree())
        assert_eq(app._notice.get_parent(), app)
        assert_ne(app._notice, old_notice)
        var fresh_button: Button = app._notice.get_child(0).get_child(0).get_child(0).get_child(1)
        assert_true(fresh_button.is_visible_in_tree())
        app.service.fail = false
        fresh_button.pressed.emit()
        assert_null(app._notice)
        assert_true(app.screen.visible)

func test_deferred_notice_refresh_is_discarded_after_another_suspend_or_boot():
    app.service.recovered = true
    app._boot()
    suspend()
    resume()
    var paused_notice: CanvasLayer = app._notice
    suspend()
    await get_tree().process_frame
    assert_eq(app._notice, paused_notice)
    resume()
    app.service.recovered = false
    app._boot()
    await get_tree().process_frame
    assert_null(app._notice)
    assert_true(app.screen.visible)
