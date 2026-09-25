extends "res://addons/gut/test.gd"
const Session = preload("res://scripts/core/game_session.gd")
const Memory = preload("res://scripts/core/memory_save_repository.gd")
const Controller = preload("res://scripts/presentation/presentation_controller.gd")
const Screen = preload("res://scripts/presentation/puzzle_screen.gd")
const Preferences = preload("res://scripts/presentation/presentation_preferences.gd")
const Feedback = preload("res://scripts/presentation/feedback_player.gd")
const Tokens = preload("res://scripts/presentation/feedback_tokens.gd")
var repo
var session
var controller
var path: String

class CountingSession:
    extends RefCounted
    var source: RefCounted
    var piece_reads := 0
    var preview_reads := 0
    func snapshot() -> Dictionary:
        return source.snapshot()
    func piece_for_slot(slot: int) -> Dictionary:
        piece_reads += 1
        return source.piece_for_slot(slot)
    func preview_placement(slot: int, x: int, y: int) -> Dictionary:
        preview_reads += 1
        return source.preview_placement(slot, x, y)

func before_each():
    path = "user://w4_tests/%d_%d/settings.json" % [Time.get_ticks_usec(),randi()]
    repo = Memory.new()
    session = Session.start(repo,"w4-test","20260921").session
    controller = Controller.new()
    controller.attach(session)

func install(state: Dictionary):
    repo = Memory.new()
    repo.commit(state,-1)
    session = Session.resume(repo).session
    controller.attach(session)

func crossing(auto_mode: bool = false) -> Dictionary:
    var state: Dictionary = session.snapshot()
    state.occupancy.fill(0)
    state.cell_style.fill(0)
    for i in range(8):
        state.occupancy[3*8+i] = 1
        state.occupancy[i*8+5] = 1
        state.cell_style[3*8+i] = 2
        state.cell_style[i*8+5] = 3
    if auto_mode:
        state.occupancy[29] = 0
        state.cell_style[29] = 0
    state.queue = ["single_v0","single_v0","single_v0"]
    state.auto_clear = auto_mode
    return state

func test_clear_geometry_contains_union_and_styles_before_automatic_removal():
    install(crossing(true))
    var result: Dictionary = controller.submit("PLACE",{"batch_id":1,"slot":0,"x":5,"y":3})
    assert_true(result.ok)
    var clear: Dictionary = result.events[1]
    assert_eq(clear.lines,2)
    assert_eq(clear.points,240)
    assert_eq(clear.cells.size(),15)
    assert_true(29 in clear.cells,"Newly placed cell must survive in presentation payload")
    assert_eq(clear.styles.size(),15)
    assert_eq(clear.rows,[3])
    assert_eq(clear.columns,[5])
    assert_eq(session.snapshot().occupancy.count(1),0)
    clear.cells.clear()
    assert_eq(session.snapshot().score,241)

func test_preview_uses_commit_validator_and_does_not_change_state():
    install(crossing())
    var before: Dictionary = session.snapshot()
    assert_eq(session.view().clear_points,240)
    assert_eq(session.preview_placement(0,-1,0).error,"OUT_OF_BOUNDS")
    assert_eq(session.preview_placement(0,5,3).error,"OCCUPIED")
    assert_true(session.preview_placement(0,0,0).ok)
    var piece: Dictionary = session.piece_for_slot(0)
    piece.cells.clear()
    assert_eq(session.piece_for_slot(0).cells.size(),1)
    assert_eq(session.snapshot(),before)

func test_tray_reuses_committed_pieces_and_refreshes_on_revision_or_session_change():
    var initial: Dictionary = session.snapshot()
    initial.queue = ["single_v0", "single_v0", "single_v0"]
    install(initial)
    var counted := CountingSession.new()
    counted.source = session
    var screen := Screen.new()
    screen.controller.attach(counted)
    screen.state = session.snapshot()
    screen._refresh_fits()
    assert_eq(counted.piece_reads, 3)
    var first_previews := counted.preview_reads
    for i in range(20): screen._refresh_fits()
    assert_eq(counted.piece_reads, 3, "layout refreshes do not copy pieces again")
    assert_eq(counted.preview_reads, first_previews, "unchanged board is not searched again")
    var placed: Dictionary = session.dispatch({"type": "PLACE", "session_id": initial.session_id,
        "event_id": 1, "batch_id": initial.batch_id, "slot": 0, "x": 0, "y": 0})
    assert_true(placed.ok)
    screen.state = session.snapshot()
    screen._refresh_fits()
    assert_eq(counted.piece_reads, 6)
    assert_true(screen.tray_pieces[0].is_empty(), "consumed slot is removed from drawing")
    assert_false(screen.tray_pieces[1].is_empty())
    var replacement := CountingSession.new()
    replacement.source = Session.start(Memory.new(), "replacement", "1").session
    assert_true(replacement.source.dispatch({"type": "SET_AUTO", "session_id": "replacement",
        "event_id": 1, "enabled": true, "confirmed": true}).ok)
    screen.controller.attach(replacement)
    screen.state = replacement.snapshot()
    screen._refresh_fits()
    assert_eq(replacement.piece_reads, 3, "same revision in another session invalidates cache")
    for slot in range(3):
        assert_eq(screen.tray_pieces[slot], replacement.source.piece_for_slot(slot))
    screen.free()

func test_pointer_origin_and_owner_prevent_duplicate_or_clamped_drop():
    var board := Rect2(20,100,320,320)
    assert_eq(Controller.cell_origin(Vector2(19,100),board,Vector2.ZERO,Vector2.ZERO),Vector2i(-1,0))
    assert_eq(Controller.cell_origin(Vector2(80,220),board,Vector2(20,20),Vector2(0,-60)),Vector2i(1,1))
    assert_true(controller.begin_drag(2,0))
    assert_false(controller.begin_drag(3,1))
    assert_eq(controller.release_drag(3).error,"NOT_OWNER")
    assert_eq(controller.release_drag(2,false).error,"CANCELLED")
    assert_eq(session.snapshot().revision,0)
    assert_eq(controller.phase,"idle")

func test_stale_drag_and_confirmation_never_commit_new_state():
    assert_true(controller.begin_drag(-1,0))
    session.dispatch({"type":"SET_AUTO","enabled":true,"confirmed":false,"session_id":"w4-test","event_id":1})
    assert_eq(controller.release_drag(-1).error,"STALE_INPUT")
    controller.open_modal()
    session.dispatch({"type":"SET_AUTO","enabled":false,"confirmed":false,"session_id":"w4-test","event_id":2})
    assert_eq(controller.submit_modal("SET_AUTO",{"enabled":true,"confirmed":true}).error,"STALE_INPUT")
    assert_eq(session.snapshot().revision,2)

func test_failed_commit_has_no_presentation_uncertainty_locks_until_attach():
    watch_signals(controller)
    repo.fail_next_commit = true
    assert_false(controller.submit("SET_AUTO",{"enabled":true,"confirmed":false}).ok)
    assert_signal_not_emitted(controller,"committed")
    assert_eq(controller.phase,"idle")
    repo.uncertain_next_commit = true
    assert_eq(controller.submit("SET_AUTO",{"enabled":true,"confirmed":false}).error,"COMMIT_UNCERTAIN")
    assert_eq(controller.phase,"recovery")
    controller.cancel()
    assert_eq(controller.phase,"recovery")
    controller.attach(Session.resume(repo).session)
    assert_eq(controller.phase,"idle")
    assert_signal_not_emitted(controller,"committed")

func test_settings_roundtrip_is_separate_and_corrupt_original_is_preserved():
    var settings := Preferences.new()
    settings.configure(path)
    var before: Dictionary = session.snapshot()
    assert_true(settings.update("reduced_motion",true))
    assert_true(settings.update("volume",20))
    var restored := Preferences.new()
    restored.configure(path)
    assert_eq(restored.values,settings.values)
    assert_eq(session.snapshot(),before)
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string("{broken")
    file.close()
    restored = Preferences.new()
    restored.configure(path)
    assert_false(restored.warning.is_empty())
    assert_false(restored.update("muted",true))
    assert_eq(FileAccess.get_file_as_string(path),"{broken")

func test_settings_v1_migration_preserves_every_existing_value():
    var legacy := {"schema":"bt_presentation_v1","reduced_motion":true,"muted":true,"volume":30,"haptics":false}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(JSON.stringify(legacy))
    file.close()
    var settings := Preferences.new()
    settings.configure(path)
    assert_true(settings.warning.is_empty())
    assert_eq(settings.values.schema,"bt_presentation_v2")
    assert_true(settings.values.reduced_motion)
    assert_true(settings.values.muted)
    assert_eq(settings.values.volume,30)
    assert_false(settings.values.haptics)
    assert_false(settings.values.large_text)
    var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    assert_eq(persisted.schema,"bt_presentation_v2")
    assert_eq(persisted.reduced_motion,legacy.reduced_motion)
    assert_eq(persisted.muted,legacy.muted)
    assert_eq(int(persisted.volume),legacy.volume)
    assert_eq(persisted.haptics,legacy.haptics)
    assert_true(settings.update("large_text",true))
    var restored := Preferences.new()
    restored.configure(path)
    assert_true(restored.values.large_text)
    assert_eq(restored.values.volume,30)
    assert_false(restored.values.haptics)

func test_large_text_fits_320_safe_area_and_settings_dialog():
    var screen := preload("res://tests/integration/inset_puzzle_screen.gd").new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.preferences.values.large_text = true
    screen.size = Vector2(320,568)
    screen._layout()
    assert_eq(screen._font_size(14),17)
    assert_gte(screen.tower_button.position.y,24.0)
    assert_gte(screen.clear_button.size.y,48.0)
    assert_lte(screen.clear_button.get_rect().end.y,544.0)
    assert_lte(screen.hint_label.position.y+screen.hint_label.size.y,screen.tray_rects[0].position.y)
    assert_gte(screen.score_label.get_theme_font_size("font_size"),32)
    screen._settings()
    var panel: Control = screen.modal.get_child(0)
    assert_gte(panel.position.y,24.0)
    assert_lte(panel.position.y+panel.size.y,544.0)
    var found_large_text := false
    var large_check: CheckButton
    for child in screen.modal_content.get_children():
        if child is CheckButton and child.text == "큰 글씨":
            found_large_text = child.button_pressed
            large_check = child
    assert_true(found_large_text)
    assert_gte(screen.modal_actions.get_child(0).custom_minimum_size.y,48.0)
    large_check.emit_signal("toggled",false)
    assert_false(screen.preferences.values.large_text)
    assert_false((JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary).large_text)

func test_tall_touch_piece_stays_above_finger_and_uses_shared_origin():
    assert_eq(Tokens.touch_lift_cells(1),1.4)
    assert_eq(Tokens.touch_lift_cells(4),2.65)
    var board := Rect2(12,200,336,336)
    var step := board.size.x/8
    var grab := Vector2(2,4)*step/2
    var lift := Vector2(0,-step*Tokens.touch_lift_cells(4))
    var pointer := Vector2(132,440)
    var floating_bottom := pointer.y-grab.y+lift.y+4*step
    assert_lte(floating_bottom,pointer.y-step*.65)
    assert_eq(Controller.cell_origin(pointer,board,grab,lift),Vector2i(1,1))
    var tall_piece: Dictionary = {}
    for piece in session._generator.catalog():
        if piece.height >= 4:
            tall_piece = piece
            break
    assert_false(tall_piece.is_empty())
    var tall_state: Dictionary = session.snapshot()
    tall_state.queue = [tall_piece.id,"single_v0","single_v0"]
    install(tall_state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen._pointer(4,screen.tray_rects[0].get_center(),true,false)
    assert_eq(screen.controller.phase,"dragging")
    assert_almost_eq(screen.lift.y,-screen.board_rect.size.x/8*Tokens.touch_lift_cells(tall_piece.height),.001)
    screen._cancel_drag()

func test_feedback_profiles_prioritize_clear_and_preserve_saved_haptics_choice():
    var settings := Preferences.new()
    settings.configure(path)
    assert_true(settings.values.haptics)
    assert_lt(Feedback.haptic_profile("pick").duration,Feedback.haptic_profile("snap").duration)
    assert_lt(Feedback.haptic_profile("snap").amplitude,Feedback.haptic_profile("clear",3).amplitude)
    assert_eq(Feedback.haptic_profile("button"),{})
    assert_gt(Feedback.sound_priority("clear"),Feedback.sound_priority("button"))
    assert_true(settings.update("haptics",false))
    var restored := Preferences.new()
    restored.configure(path)
    assert_false(restored.values.haptics)

func test_real_screen_clear_and_interrupt_restore_input_and_exact_hud():
    install(crossing())
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    assert_true(screen.clear_button.text.contains("240"))
    screen._clear()
    assert_eq(screen.state.score,240)
    assert_eq(screen.remnants.size(),15)
    assert_gte(screen.toast_label.position.y,screen.board_rect.end.y)
    assert_eq(screen.controller.phase,"settling")
    assert_true("clear" in screen.feedback.played)
    screen.interrupt()
    screen.controller.settle()
    assert_eq(screen.controller.phase,"idle")
    assert_eq(screen.remnants.size(),0)
    assert_eq(screen.score_label.text,"240")

func test_screen_auto_modal_cancel_and_confirm_commit_once():
    install(crossing())
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.preferences.values.reduced_motion = true
    screen.preferences.values.muted = true
    screen._toggle_auto()
    assert_eq(screen.controller.phase,"modal")
    screen._close_modal()
    assert_eq(session.snapshot().score,0)
    screen._toggle_auto()
    screen._confirm_auto()
    assert_eq(session.snapshot().score,240)
    assert_true(session.snapshot().auto_clear)
    assert_eq(session.snapshot().revision,1)
    assert_eq(screen.controller.phase,"idle")

func test_back_closes_modal_then_tower_and_cancels_drag_without_commit():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    var before: Dictionary = session.snapshot()
    screen._open_tower()
    screen._settings()
    assert_true(screen.handle_back())
    assert_null(screen.modal)
    assert_eq(screen.screen_id,"tower")
    assert_true(screen.handle_back())
    assert_eq(screen.screen_id,"puzzle")
    screen._pointer(4,screen.tray_rects[0].get_center(),true,false)
    assert_eq(screen.controller.phase,"dragging")
    assert_true(screen.handle_back())
    assert_eq(screen.controller.phase,"idle")
    assert_false(screen.handle_back(),"Only root navigation may exit the app")
    assert_eq(session.snapshot(),before)
    await get_tree().process_frame

func test_sixteen_line_payload_is_unique_and_precise():
    var state := crossing()
    state.occupancy.fill(1)
    state.cell_style.fill(2)
    install(state)
    var result: Dictionary = controller.submit("CLEAR")
    assert_true(result.ok)
    var event: Dictionary = result.events[0]
    assert_eq(event.lines,16)
    assert_eq(event.points,2560)
    assert_eq(event.cells,range(64))
    assert_eq(event.styles.size(),64)
    assert_eq(session.snapshot().growth.total_floors,16)

func test_touch_cancellation_and_focus_loss_do_not_place_or_leave_drag():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    var before: Dictionary = session.snapshot()
    screen._pointer(4,screen.tray_rects[0].get_center(),true,false)
    assert_eq(screen.controller.phase,"dragging")
    var cancelled := InputEventScreenTouch.new()
    cancelled.index = 4
    cancelled.canceled = true
    screen._input(cancelled)
    assert_eq(screen.controller.phase,"idle")
    assert_eq(session.snapshot(),before)
    screen._pointer(5,screen.tray_rects[0].get_center(),true,false)
    screen.set_application_active(false)
    assert_eq(screen.controller.phase,"idle")
    assert_eq(session.snapshot(),before)

func test_recovery_modal_cannot_be_dismissed_into_a_frozen_screen():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    repo.uncertain_next_commit = true
    screen.controller.submit("SET_AUTO",{"enabled":true,"confirmed":false})
    assert_eq(screen.controller.phase,"recovery")
    assert_not_null(screen.modal)
    screen._close_modal()
    assert_not_null(screen.modal)
    assert_eq(screen.feedback.played.size(),0)

func test_new_run_from_tower_preserves_growth_and_resets_hud():
    var state := crossing()
    state.growth.total_floors = 13
    state.growth.representative_segment = 1
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.preferences.values.reduced_motion = true
    screen._open_tower()
    screen._new_run_dialog()
    screen._confirm_new()
    assert_eq(screen.screen_id,"puzzle")
    assert_eq(screen.controller.phase,"idle")
    assert_eq(session.snapshot().run_id,2)
    assert_eq(session.snapshot().growth.total_floors,13)
    assert_eq(screen.score_label.text,"0")
    await get_tree().process_frame

func test_audio_off_does_not_start_players_and_history_is_bounded():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    for i in range(100): screen.feedback.cue("clear",4)
    assert_eq(screen.feedback.played.size(),32)
    for player in screen.feedback.players: assert_false(player.playing)

func test_resize_preserves_mandatory_recovery_action():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    repo.uncertain_next_commit = true
    screen.controller.submit("SET_AUTO",{"enabled":true,"confirmed":false})
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen._layout()
    assert_eq(screen.controller.phase,"recovery")
    assert_not_null(screen.modal)
    var action_button = screen.modal_actions.get_child(0)
    assert_eq(action_button.text,"기록 다시 읽기")
    watch_signals(screen)
    action_button.pressed.emit()
    assert_signal_emitted(screen,"reload_requested")
    await get_tree().process_frame

func test_resumed_below_best_run_announces_first_new_record_once():
    var state := crossing()
    state.score = 50
    state.best = 100
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.preferences.values.reduced_motion = true
    screen.preferences.values.muted = true
    assert_false(screen.best_announced)
    screen._clear()
    assert_eq(session.snapshot().best,290)
    assert_true(screen.last_event_details.has("새 최고 기록: 290점"))
    screen.controller.submit("PLACE",{"batch_id":session.snapshot().batch_id,"slot":0,"x":0,"y":0})
    assert_false(screen.last_event_details.has("새 최고 기록: 290점"))

func test_tower_roof_tracks_actual_top_across_segment_boundary():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    for sample in [[10,1,10,true],[11,1,10,false],[11,2,1,true],[13,1,10,false],[13,2,3,true]]:
        screen.state.growth.total_floors = sample[0]
        screen.selected_segment = sample[1]
        assert_eq(screen.tower_segment_view(),{"count":sample[2],"roof":sample[3]})

func test_tower_facade_style_is_per_completed_segment_and_survives_resume():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 23
    state.growth.brick_lines = 2
    state.growth.representative_segment = 1
    install(state)
    var screen := preload("res://tests/integration/inset_puzzle_screen.gd").new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen._open_tower()
    screen.preferences.values.large_text = true
    screen._layout()
    for child in screen.controls.get_children():
        if child is Button:
            assert_gte(child.size.y,48,"tower controls retain 48px targets")
            assert_gte(child.position.y,24,"tower controls remain below the safe top")
            assert_lte(child.get_rect().end.y,544,"tower controls remain above the safe bottom")
    screen._set_tower_style("brick")
    assert_eq(session.snapshot().growth.segment_styles,{"1":"brick"})
    controller.settle()
    screen.selected_segment = 2
    screen._layout()
    screen._set_tower_style("brick")
    controller.settle()
    screen.selected_segment = 1
    screen._layout()
    screen._set_tower_style("wood")
    controller.settle()
    assert_eq(session.snapshot().growth.segment_styles,{"2":"brick"},"wood selection removes only that sparse override")
    var resumed := Session.resume(repo)
    assert_true(resumed.ok)
    assert_eq(resumed.session.snapshot().growth.segment_styles,{"2":"brick"},"styles persist in the committed snapshot")
    screen.state = resumed.session.snapshot()
    screen.analysis = resumed.session.view()
    screen.selected_segment = 3
    screen._layout()
    assert_eq(screen.tower_segment_view().count,3)
    screen._set_tower_style("brick")
    assert_eq(resumed.session.snapshot().growth.segment_styles,{"2":"brick"},"partial segment cannot be edited")
    assert_eq(screen._tower_style_status("metal"),"현재 외벽: 금속·유리")

func test_locked_brick_status_is_clear_and_not_selectable():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 10
    state.growth.representative_segment = 1
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen._open_tower()
    screen._show_facade_sheet()
    var brick_locked := false
    var metal_locked := false
    var crystal_disabled := false
    var unlock_copy := ""
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("벽돌"):
            brick_locked = child.disabled and child.custom_minimum_size.y >= 48
        if child is Button and child.text.contains("금속·유리"):
            metal_locked = child.disabled and child.custom_minimum_size.y >= 48
        if child is Button and child.text.contains("크리스털"):
            crystal_disabled = child.disabled and child.custom_minimum_size.y >= 48
        if child is Label: unlock_copy += child.text
    assert_true(brick_locked,"locked brick is not selectable")
    assert_true(metal_locked,"locked metal/glass is not selectable")
    assert_true(crystal_disabled,"crystal remains locked before its growth condition")
    assert_true(unlock_copy.contains("동시 2줄 제거 또는 누적 30층"))
    assert_true(unlock_copy.contains("동시 3줄 제거 또는 누적 100층"))
    assert_true(unlock_copy.contains("동시 4줄 제거 또는 누적 250층"))

func test_metal_facade_selection_is_committed_per_segment_and_resumes():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 23
    state.growth.brick_lines = 3
    state.growth.metal_lines = 3
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"2":"brick"}
    install(state)
    var screen := preload("res://tests/integration/inset_puzzle_screen.gd").new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen.preferences.values.large_text = true
    screen._open_tower()
    var selector: Button
    for child in screen.controls.get_children():
        if child is Button and child.text == "외벽 선택": selector = child
    assert_not_null(selector)
    selector.grab_focus()
    screen._show_facade_sheet()
    var metal_choice: Button
    var crystal_choice: Button
    var dialog_text := ""
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("금속·유리"): metal_choice = child
        if child is Button and child.text.contains("크리스털"): crystal_choice = child
        if child is Label: dialog_text += child.text
    assert_not_null(metal_choice)
    assert_false(metal_choice.disabled)
    assert_not_null(crystal_choice)
    assert_true(crystal_choice.disabled)
    assert_true(dialog_text.contains("동시 3줄 제거 또는 누적 100층"))
    assert_true(dialog_text.contains("동시 4줄 제거 또는 누적 250층"))
    var focus_owner := screen.get_viewport().gui_get_focus_owner()
    assert_true(focus_owner is Button and focus_owner.text=="벽돌 적용","first unlocked option receives sheet keyboard focus")
    for child in screen.controls.get_children():
        if child is Button and child.visible:
            assert_gte(child.custom_minimum_size.y,48)
            assert_gte(child.position.y,24)
            assert_lte(child.get_rect().end.y,544)
    assert_true(screen.handle_back(),"Back closes the facade sheet")
    assert_null(screen.modal)
    assert_eq(screen.get_viewport().gui_get_focus_owner(),selector,"closing the sheet returns focus to its opener")
    screen._show_facade_sheet()
    screen._apply_facade_choice("metal")
    assert_eq(screen.tower_segment_style(1),"metal")
    assert_eq(session.snapshot().growth.segment_styles,{"1":"metal","2":"brick"})
    var revision: int = session.snapshot().revision
    screen._set_tower_style("metal")
    screen.controller.settle()
    assert_eq(session.snapshot().revision,revision,"same-style selection is a no-op")
    var resumed := Session.resume(repo)
    assert_true(resumed.ok)
    assert_eq(resumed.session.snapshot().growth.segment_styles,{"1":"metal","2":"brick"})
    screen.attach(resumed.session,path)
    screen.screen_id = "tower"
    screen.selected_segment = 3
    screen._layout()
    screen._set_tower_style("metal")
    assert_eq(resumed.session.snapshot().revision,revision,"partial segment cannot acquire metal")
    assert_eq(screen.tower_segment_style(1),"metal")
    assert_eq(screen.tower_segment_style(2),"brick")

func test_material_sheet_buttons_apply_their_own_bound_choice():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 20
    state.growth.brick_lines = 4
    state.growth.metal_lines = 4
    state.growth.crystal_lines = 4
    state.growth.representative_segment = 1
    for material in ["wood","brick","metal","crystal"]:
        state.growth.segment_styles = {"1": "brick" if material == "wood" else "wood"}
        install(state)
        var screen := Screen.new()
        add_child_autofree(screen)
        screen.attach(session,path)
        screen._open_tower()
        screen._show_facade_sheet()
        var target: Button
        for child in screen.modal_content.get_children():
            if child is Button and child.text.contains(screen._facade_label(material)):
                target = child
                break
        assert_not_null(target,"button exists for %s" % material)
        assert_false(target.disabled,"button is enabled for %s" % material)
        target.pressed.emit()
        assert_eq(session.snapshot().growth.segment_styles.get("1","wood"),material,"pressed button applies captured %s" % material)

func test_saved_crystal_displays_without_migration_and_failed_change_keeps_it():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 20
    state.growth.brick_lines = 4
    state.growth.metal_lines = 4
    state.growth.crystal_lines = 4
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"1":"crystal"}
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen._open_tower()
    var saved_revision: int = session.snapshot().revision
    assert_eq(screen.tower_segment_style(),"crystal")
    assert_true(screen._tower_style_status("crystal").contains("현재 외벽: 크리스털"))
    screen._show_facade_sheet()
    var crystal_choice: Button
    var metal_choice: Button
    var copy := ""
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("크리스털"): crystal_choice = child
        if child is Button and child.text.contains("금속·유리"): metal_choice = child
        if child is Label: copy += child.text
    assert_true(crystal_choice.disabled,"the already applied crystal style is not submitted as a change")
    assert_false(metal_choice.disabled)
    assert_true(copy.contains("동시 4줄 제거 또는 누적 250층"))
    assert_eq(session.snapshot().revision,saved_revision,"showing a saved crystal does not write a migration commit")
    screen._close_modal()
    repo.fail_next_commit = true
    screen._set_tower_style("metal")
    assert_eq(session.snapshot().growth.segment_styles,{"1":"crystal"})
    assert_eq(screen.tower_segment_style(),"crystal")
    assert_not_null(screen.modal,"failed save leaves committed visual unchanged and opens recovery flow")

func test_crystal_button_commits_independently_and_resumes_with_other_facade():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 23
    state.growth.brick_lines = 4
    state.growth.metal_lines = 4
    state.growth.crystal_lines = 4
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"2":"metal"}
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen._open_tower()
    var before_revision: int = session.snapshot().revision
    screen._show_facade_sheet()
    var choice: Button
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("크리스털"):
            choice = child
            break
    assert_not_null(choice)
    assert_false(choice.disabled,"crystal is selectable when Growth.describe unlocks it")
    choice.pressed.emit()
    assert_eq(session.snapshot().growth.segment_styles,{"1":"crystal","2":"metal"})
    assert_eq(screen.tower_segment_style(1),"crystal")
    assert_eq(screen.tower_segment_style(2),"metal")
    assert_eq(session.snapshot().revision,before_revision+1)
    var same_revision: int = session.snapshot().revision
    screen._set_tower_style("crystal")
    assert_eq(session.snapshot().revision,same_revision,"same-style request is a no-op")
    var resumed := Session.resume(repo)
    assert_true(resumed.ok)
    assert_eq(resumed.session.snapshot().growth.segment_styles,{"1":"crystal","2":"metal"},"crystal and metal styles remain independent after resume")

func test_failed_facade_commit_keeps_saved_and_displayed_material_unchanged():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 10
    state.growth.brick_lines = 2
    state.growth.representative_segment = 1
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen._open_tower()
    repo.fail_next_commit = true
    screen._show_facade_sheet()
    var brick_choice: Button
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("벽돌"):
            brick_choice = child
            break
    assert_not_null(brick_choice)
    assert_false(brick_choice.disabled)
    brick_choice.pressed.emit()
    assert_eq(session.snapshot().growth.segment_styles,{})
    assert_eq(screen.tower_segment_style(),"wood")
    assert_not_null(screen.modal,"commit failure presents the existing save recovery flow")

func test_brick_arch_part_button_lock_unlock_and_failed_commit_are_real_pressed_actions():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 30
    state.growth.brick_lines = 2
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"1":"brick"}
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen.preferences.values.large_text = true
    screen._open_tower()
    screen._show_facade_sheet()
    var part_button: Button
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("아치 창문"): part_button = child
    assert_not_null(part_button)
    assert_true(part_button.disabled)
    assert_gte(part_button.custom_minimum_size.y,48)
    assert_true(screen.modal_content.get_children().any(func(child):return child is Label and child.text.contains("벽돌 10줄 또는 누적 60층")))
    screen._close_modal()
    state.growth.total_floors = 60
    state.growth.segment_styles = {"1":"brick"}
    install(state)
    screen.attach(session,path)
    screen._open_tower()
    screen._show_facade_sheet()
    part_button = null
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("아치 창문"): part_button = child
    assert_not_null(part_button)
    assert_false(part_button.disabled)
    var before: int = session.snapshot().revision
    part_button.pressed.emit()
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_arch_window"]})
    assert_eq(session.snapshot().revision,before+1)
    screen._show_facade_sheet()
    part_button = null
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("아치 창문 장착"): part_button = child
    assert_not_null(part_button)
    assert_false(part_button.disabled,"equipped state exposes the unequip action")
    repo.fail_next_commit = true
    part_button.pressed.emit()
    assert_true(session.snapshot().growth.segment_parts.has("1"),"failed part save keeps the committed decoration")

func test_brick_terrace_and_arch_choices_are_independent_real_button_actions():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 120
    state.growth.brick_lines = 2
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"1":"brick"}
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen.preferences.values.large_text = true
    screen._open_tower()
    screen._show_facade_sheet()
    var terrace_button: Button
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("테라스"): terrace_button = child
    assert_not_null(terrace_button)
    assert_false(terrace_button.disabled,"cumulative 120-floor unlock makes terrace selectable")
    assert_gte(terrace_button.custom_minimum_size.y,48)
    terrace_button.pressed.emit()
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_terrace"]})
    screen._show_facade_sheet()
    var arch_button: Button
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("아치 창문"): arch_button = child
    assert_not_null(arch_button)
    arch_button.pressed.emit()
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_arch_window","brick_terrace"]},"independent UI choices preserve sorted coexistence")
    screen._close_modal()
    screen._layout()
    assert_true(screen.controls.get_children().any(func(child):return child is Label and child.text.contains("현재 벽돌 ·") and child.text.contains("아치 창문+테라스")),"selected tower caption names both committed parts")
    screen._show_facade_sheet()
    terrace_button = null
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("테라스 장착"): terrace_button = child
    assert_not_null(terrace_button)
    repo.fail_next_commit = true
    terrace_button.pressed.emit()
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_arch_window","brick_terrace"]},"failed unequip leaves committed rendering intact")

func test_brick_cornice_actual_button_and_roof_vs_horizontal_cap_selection():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 205
    state.growth.brick_lines = 2
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"20":"brick"}
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen.preferences.values.large_text = true
    screen._open_tower()
    screen.selected_segment = 20
    screen._layout()
    assert_eq(screen.tower_segment_view(),{"count":10,"roof":false})
    assert_eq(screen.tower_cap_key(),"cornice","lower completed segment retains horizontal cap selection")
    screen._show_facade_sheet()
    var cornice_button: Button
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("상단 장식"): cornice_button = child
    assert_not_null(cornice_button)
    assert_false(cornice_button.disabled,"cumulative 200-floor unlock enables cornice")
    assert_gte(cornice_button.custom_minimum_size.y,48)
    cornice_button.pressed.emit()
    assert_eq(session.snapshot().growth.segment_parts.get("20",[]),["brick_cornice"],"real choice commits to the selected segment")
    assert_eq(screen.tower_cap_key(),"brick_cornice","cornice replaces the horizontal cap for a lower brick segment")
    screen._close_modal()

    var roof_state: Dictionary = session.snapshot()
    roof_state.growth.total_floors = 200
    install(roof_state)
    var roof_screen := Screen.new()
    add_child_autofree(roof_screen)
    roof_screen.attach(session,path)
    roof_screen.selected_segment = 20
    assert_eq(roof_screen.tower_segment_view(),{"count":10,"roof":true},"last complete segment at 200 floors keeps roof geometry")
    assert_eq(roof_screen.tower_cap_key(),"brick_cornice_roof_top","cornice decorates rather than replaces the top roof")

func test_brick_two_part_captions_are_truthful_measured_and_accessible():
    var combinations: Array[Dictionary] = [
        {"parts":["brick_arch_window","brick_cornice"],"shown":["아치 창문","상단 장식"],"omitted":"테라스"},
        {"parts":["brick_cornice","brick_terrace"],"shown":["테라스","상단 장식"],"omitted":"아치 창문"}
    ]
    for combination in combinations:
        var state: Dictionary = session.snapshot()
        state.growth.total_floors = 200
        state.growth.brick_lines = 60
        state.growth.representative_segment = 1
        state.growth.segment_styles = {"20":"brick"}
        state.growth.segment_parts = {"20":combination.parts}
        install(state)

        var screen := Screen.new()
        add_child_autofree(screen)
        screen.attach(session,path)
        screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
        screen.size = Vector2(320,568)
        screen.preferences.values.large_text = true
        screen._open_tower()
        screen.selected_segment = 20
        screen._layout()

        var caption: Label
        var previous_button: Button
        var next_button: Button
        var facade_button: Button
        for child in screen.controls.get_children():
            if child is Label and child.text.contains("현재 벽돌") and child.text.contains("상단 장식"): caption = child
            if child is Button and child.text == "이전": previous_button = child
            if child is Button and child.text == "다음": next_button = child
            if child is Button and child.text.begins_with("외벽 선택"): facade_button = child
        assert_not_null(caption,"selected segment has a visible caption for %s" % str(combination.parts))
        if caption == null: continue
        for shown_part in combination.shown:
            assert_true(caption.text.contains(shown_part),"caption truthfully includes %s" % shown_part)
        assert_false(caption.text.contains(combination.omitted),"caption does not imply an unequipped part")
        assert_eq(caption.accessibility_name,caption.text,"accessible name equals truthful visible caption")
        var caption_font: Font = caption.get_theme_font("font")
        var caption_font_size: int = caption.get_theme_font_size("font_size")
        for line in caption.text.split("\n"):
            assert_lte(caption_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_font_size).x,caption.size.x,"caption line fits within its measured 320px arrow gap")
        assert_not_null(previous_button)
        assert_not_null(next_button)
        assert_not_null(facade_button)
        if previous_button != null and next_button != null and facade_button != null:
            var caption_rect := caption.get_global_rect()
            assert_gte(caption_rect.position.x,previous_button.get_global_rect().end.x,"caption begins after previous arrow target")
            assert_lte(caption_rect.end.x,next_button.get_global_rect().position.x,"caption ends before next arrow target")
            assert_lte(caption_rect.end.y,facade_button.get_global_rect().position.y,"caption remains above facade action")

func test_brick_landmark_button_combines_with_arch_and_four_part_caption_fits():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 300
    state.growth.brick_lines = 100
    state.growth.representative_segment = 30
    state.growth.segment_styles = {"1":"brick"}
    state.growth.segment_parts = {"1":["brick_arch_window","brick_cornice","brick_terrace"]}
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen.preferences.values.large_text = true
    screen._open_tower()
    screen.selected_segment = 1
    screen._layout()
    var facade_button: Button
    for child in screen.controls.get_children():
        if child is Button and child.text.begins_with("외벽 선택"): facade_button = child
    assert_not_null(facade_button)
    facade_button.pressed.emit()
    var landmark_button: Button
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("랜드마크"): landmark_button = child
    assert_not_null(landmark_button)
    assert_false(landmark_button.disabled,"300-floor unlock enables actual landmark selector")
    assert_gte(landmark_button.custom_minimum_size.y,48)
    landmark_button.pressed.emit()
    assert_eq(session.snapshot().growth.segment_parts["1"],["brick_arch_window","brick_cornice","brick_landmark","brick_terrace"],"actual landmark button preserves sorted coexistence with all prior parts")
    screen.controller.settle()
    assert_eq(screen.tower_landmark_key(),"brick_arch_landmark_floor_mid","arch-equipped segment selects matching landmark module")
    assert_not_null(screen.tower_art["brick_arch_landmark_floor_mid"])
    screen._close_modal()
    screen.selected_segment = 1
    screen._layout()
    var caption: Label
    var previous_button: Button
    var next_button: Button
    var style_button: Button
    for child in screen.controls.get_children():
        if child is Label and child.text.contains("랜드마크"): caption = child
        if child is Button and child.text == "이전": previous_button = child
        if child is Button and child.text == "다음": next_button = child
        if child is Button and child.text.begins_with("외벽 선택"): style_button = child
    assert_not_null(caption,"selected caption reports the full four-part loadout")
    if caption != null:
        for required in ["아치 창문","테라스","상단 장식","랜드마크"]: assert_true(caption.text.contains(required),"four-part caption includes "+required)
        assert_eq(caption.accessibility_name,caption.text)
        var font: Font = caption.get_theme_font("font")
        var font_size: int = caption.get_theme_font_size("font_size")
        for line in caption.text.split("\n"):
            assert_lte(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,caption.size.x,"wrapped four-part caption fits between arrows")
    assert_not_null(previous_button)
    assert_not_null(next_button)
    assert_not_null(style_button)
    if caption != null and previous_button != null and next_button != null and style_button != null:
        assert_gte(caption.get_global_rect().position.x,previous_button.get_global_rect().end.x)
        assert_lte(caption.get_global_rect().end.x,next_button.get_global_rect().position.x)
        assert_lte(caption.get_global_rect().end.y,style_button.get_global_rect().position.y)
    screen._set_tower_style("metal")
    screen.controller.settle()
    assert_eq(screen.tower_landmark_key(),"","landmark drawing is hidden while its saved part is dormant on another facade")
    screen._set_tower_style("brick")
    screen.controller.settle()
    assert_eq(screen.tower_landmark_key(),"brick_arch_landmark_floor_mid","stored landmark returns with brick facade")

func test_three_part_landmark_captions_match_each_equipped_combination():
    var cases := [
        {"parts":["brick_arch_window","brick_cornice","brick_landmark"],"names":["아치 창문","상단 장식","랜드마크"]},
        {"parts":["brick_arch_window","brick_landmark","brick_terrace"],"names":["아치 창문","테라스","랜드마크"]},
        {"parts":["brick_cornice","brick_landmark","brick_terrace"],"names":["테라스","상단 장식","랜드마크"]}
    ]
    for item in cases:
        var state: Dictionary = session.snapshot()
        state.growth.total_floors = 300
        state.growth.brick_lines = 100
        state.growth.representative_segment = 1
        state.growth.segment_styles = {"1":"brick"}
        state.growth.segment_parts = {"1":item.parts}
        install(state)
        var screen := Screen.new()
        add_child_autofree(screen)
        screen.attach(session,path)
        screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
        screen.size = Vector2(320,568)
        screen.preferences.values.large_text = true
        screen._open_tower()
        screen.selected_segment = 1
        screen._layout()
        var caption: Label
        var previous_button: Button
        var next_button: Button
        var facade_button: Button
        for child in screen.controls.get_children():
            if child is Label and child.text.contains("랜드마크"): caption = child
            if child is Button and child.text == "이전": previous_button = child
            if child is Button and child.text == "다음": next_button = child
            if child is Button and child.text.begins_with("외벽 선택"): facade_button = child
        assert_not_null(caption,"three-part landmark caption exists for "+str(item.parts))
        if caption == null: continue
        for part_name in item.names: assert_true(caption.text.contains(part_name),"caption names equipped part "+part_name)
        for omitted_name in ["아치 창문","테라스","상단 장식","랜드마크"]:
            if omitted_name not in item.names: assert_false(caption.text.contains(omitted_name),"caption omits unequipped part "+omitted_name)
        assert_eq(caption.accessibility_name,caption.text,"accessibility keeps full equipped part names")
        var font: Font = caption.get_theme_font("font")
        var font_size: int = caption.get_theme_font_size("font_size")
        for line in caption.text.split("\n"):
            assert_lte(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,caption.size.x,"three-part line fits measured arrow gap")
        assert_not_null(previous_button)
        assert_not_null(next_button)
        assert_not_null(facade_button)
        if previous_button != null and next_button != null and facade_button != null:
            var caption_rect := caption.get_global_rect()
            assert_gte(caption_rect.position.x,previous_button.get_global_rect().end.x,"caption clears previous arrow")
            assert_lte(caption_rect.end.x,next_button.get_global_rect().position.x,"caption clears next arrow")
            assert_lte(caption_rect.end.y,facade_button.get_global_rect().position.y,"caption clears facade control")

func test_brick_arch_part_is_dormant_across_material_switch_and_can_be_cleared():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 100
    state.growth.brick_lines = 3
    state.growth.metal_lines = 3
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"1":"brick"}
    state.growth.segment_parts = {"1":["brick_arch_window"]}
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen._open_tower()
    screen.selected_segment = 1
    screen._layout()
    assert_eq(screen.tower_segment_style(1),"brick")
    screen._set_tower_style("metal")
    screen.controller.settle()
    assert_eq(screen.tower_segment_style(1),"metal")
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_arch_window"]})
    screen._set_tower_style("brick")
    screen.controller.settle()
    assert_eq(screen.tower_segment_style(1),"brick")
    screen._set_tower_style("metal")
    screen.controller.settle()
    screen._show_facade_sheet()
    var dormant: Button
    for child in screen.modal_content.get_children():
        if child is Button and child.text.contains("아치 창문 숨김"): dormant = child
    assert_not_null(dormant)
    assert_false(dormant.disabled)
    dormant.pressed.emit()
    assert_eq(session.snapshot().growth.segment_parts,{})

func test_assist_nearest_edge_hysteresis_and_exact_release_share_validator():
    var state: Dictionary = session.snapshot()
    state.queue = ["single_v0","single_v0","single_v0"]
    install(state)
    var board := Rect2(12,120,336,336)
    var grab := Vector2(21,21)
    assert_true(controller.begin_drag(0,0))
    var at: Vector2i = controller.assisted_origin(board.position+grab+Vector2(-.2,2)*42,board,grab,Vector2.ZERO)
    assert_eq(at,Vector2i(0,2),"Near edge can acquire a valid anchor")
    controller.move_drag(0,at)
    at = controller.assisted_origin(board.position+grab+Vector2(.6,2)*42,board,grab,Vector2.ZERO)
    assert_eq(at,Vector2i(0,2),"Small border movement retains the ghost")
    at = controller.assisted_origin(board.position+grab+Vector2(1.05,2)*42,board,grab,Vector2.ZERO)
    assert_eq(at,Vector2i(1,2),"Release radius permits the next anchor")
    controller.move_drag(0,at)
    var result: Dictionary = controller.release_drag(0,true)
    assert_true(result.ok)
    assert_eq(session.snapshot().occupancy[17],1)
    assert_eq(session.snapshot().revision,1)

func test_assist_does_not_pull_from_outside_or_write_during_preview():
    var state: Dictionary = session.snapshot()
    state.queue = ["single_v0","single_v0","single_v0"]
    state.occupancy[0] = 1
    state.cell_style[0] = 1
    install(state)
    var before: Dictionary = session.snapshot()
    var board := Rect2(12,120,336,336)
    var grab := Vector2(21,21)
    controller.begin_drag(0,0)
    var at: Vector2i = controller.assisted_origin(board.position+grab+Vector2(.45,0)*42,board,grab,Vector2.ZERO)
    assert_eq(at,Vector2i(1,0),"Only a nearby legal neighbor is eligible")
    at = controller.assisted_origin(Vector2(-100,-100),board,grab,Vector2.ZERO)
    assert_lt(at.x,0)
    controller.move_drag(0,at)
    assert_false(controller.release_drag(0,false).ok)
    assert_eq(session.snapshot(),before)

func test_assist_all_catalog_shapes_preview_and_commit_same_bottom_edge_cells():
    var catalog: Array = session._generator.catalog()
    var base: Dictionary = session.snapshot()
    var board := Rect2(12,120,336,336)
    for piece in catalog:
        var state: Dictionary = base.duplicate(true)
        state.queue = [piece.id,"single_v0","single_v0"]
        install(state)
        var before: Dictionary = session.snapshot()
        var expected := Vector2i(8-piece.width,8-piece.height)
        var grab := Vector2(piece.width,piece.height)*21
        assert_true(controller.begin_drag(0,0),piece.id)
        var point := board.position+grab+(Vector2(expected)+Vector2(.2,.15))*42
        var anchor: Vector2i = controller.assisted_origin(point,board,grab,Vector2.ZERO)
        assert_eq(anchor,expected,piece.id)
        var preview: Dictionary = controller.move_drag(0,anchor)
        assert_true(preview.ok,piece.id)
        assert_eq(session.snapshot(),before,"Preview does not mutate "+piece.id)
        var result: Dictionary = controller.release_drag(0,true)
        assert_true(result.ok,piece.id)
        assert_eq(result.events[0].cells,preview.cells,piece.id)
        assert_eq(session.snapshot().revision,before.revision+1,piece.id)

func test_full_width_board_and_top_navigation_fit_compact_and_tall():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    for dims in [Vector2(320,568),Vector2(360,800),Vector2(412,915)]:
        screen.size = dims
        screen._layout()
        assert_gt(screen.board_rect.size.x/dims.x,.92)
        assert_lt(screen.tower_button.position.y+screen.tower_button.size.y,screen.board_rect.position.y)
        assert_lte(screen.clear_button.position.y+screen.clear_button.size.y,dims.y)
        assert_gte(screen.clear_button.size.y,48.0)
    await get_tree().process_frame

func test_clear_unlocks_before_tail_and_interruption_cannot_repeat_reward():
    install(crossing())
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    screen._clear()
    var committed: Dictionary = session.snapshot()
    assert_eq(screen.effect_rows,[3])
    assert_eq(screen.effect_columns,[5])
    screen._process(.29)
    assert_eq(screen.controller.phase,"idle")
    assert_gt(screen.effect_alpha,0.0)
    screen.interrupt()
    assert_eq(screen.remnants.size(),0)
    assert_eq(session.snapshot(),committed)

func test_compact_safe_insets_fit_board_and_action():
    var screen := preload("res://tests/integration/inset_puzzle_screen.gd").new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen._layout()
    assert_eq(screen.board_rect.size.x,296.0)
    assert_gte(screen.tower_button.position.y,24.0)
    assert_lte(screen.clear_button.get_rect().end.y,544.0)
    assert_eq(screen.clear_button.size.y,48.0)

func test_reward_stays_off_board_and_new_pick_restores_hint():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    screen.controller.submit("PLACE",{"batch_id":session.snapshot().batch_id,"slot":0,"x":0,"y":0})
    assert_gte(screen.toast_label.position.y,screen.board_rect.end.y)
    screen._process(.15)
    var before: Dictionary = session.snapshot()
    screen._pointer(-1,screen.tray_rects[1].get_center(),true,false)
    assert_eq(screen.controller.phase,"dragging")
    assert_eq(screen.toast_label.modulate.a,0.0)
    assert_true(screen.hint_label.visible)
    assert_eq(session.snapshot(),before)

func _crossing_at_floors(floors: int) -> Dictionary:
    var state := crossing()
    state.growth.total_floors = floors
    state.growth.brick_lines = 0
    state.growth.metal_lines = 0
    state.growth.crystal_lines = 0
    state.growth.representative_segment = 1 if floors >= 10 else 0
    return state

func test_real_segment_crossings_and_unlocks_are_announced_in_large_compact_strip():
    for floors in [9,19]:
        install(_crossing_at_floors(floors))
        var screen := Screen.new()
        add_child_autofree(screen)
        screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
        screen.size = Vector2(320,568)
        screen.attach(session,path)
        screen.preferences.values.large_text = true
        screen._layout()
        await get_tree().process_frame
        screen._clear()
        var total_after: int = floors+2
        assert_eq(session.snapshot().growth.total_floors,total_after)
        assert_true(screen.last_event_announcements.has("[완료] 2줄 · +240점 · +2층"))
        assert_true(screen.last_event_announcements.has("구간 +1 · 해금 1종"),"%d-floor crossing notices: %s" % [floors,str(screen.last_event_announcements)])
        assert_true(screen.last_growth_details.has("새 구간: %d" % (floors/10+1)))
        assert_true(screen.last_growth_details.has("새 재료: 벽돌"))
        assert_eq(screen.toast_label.position.y,screen.board_rect.end.y)
        assert_lte(screen.toast_label.get_rect().end.y,screen.tray_rects[0].position.y)
        assert_lte(screen.last_event_announcements.size(),Screen.MAX_EVENT_ANNOUNCEMENTS)
        assert_lte(screen.last_event_announcements.size()*(Screen.EVENT_NOTICE_HOLD+Screen.Tokens.TOAST_FADE),Screen.MAX_EVENT_ANNOUNCEMENT_SECONDS)
        var actual_size := screen.toast_label.get_theme_font_size("font_size")
        for announcement in screen.last_event_announcements:
            assert_lte(screen.strong.get_string_size(announcement,HORIZONTAL_ALIGNMENT_LEFT,-1,actual_size).x,screen.toast_label.size.x,announcement)

func test_sixteen_line_clear_has_bounded_notices_and_tower_unlock_details_survive_fast_pick():
    var state := _crossing_at_floors(9)
    state.occupancy.fill(1)
    state.cell_style.fill(1)
    install(state)
    var screen := preload("res://tests/integration/inset_puzzle_screen.gd").new()
    add_child_autofree(screen)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen.attach(session,path)
    screen.preferences.values.large_text = true
    screen.preferences.values.reduced_motion = true
    screen.preferences.values.muted = true
    screen._layout()
    screen._clear()
    assert_eq(session.snapshot().score,2560)
    assert_eq(session.snapshot().growth.total_floors,25)
    assert_true(screen.last_event_announcements.has("구간 +2 · 해금 4종"))
    assert_lte(screen.last_event_announcements.size(),Screen.MAX_EVENT_ANNOUNCEMENTS)
    assert_lte(screen.last_event_announcements.size()*(Screen.EVENT_NOTICE_HOLD+Screen.Tokens.TOAST_FADE),Screen.MAX_EVENT_ANNOUNCEMENT_SECONDS)
    assert_true(screen.last_growth_details.has("새 구간: 1, 2"))
    assert_true(screen.last_growth_details.has("새 재료: 벽돌, 금속, 수정"))
    assert_true(screen.last_growth_details.has("새 장식: 아치 창문"))
    assert_true(screen.hint_label.visible == false)
    assert_lte(screen.toast_queue.size()+1,Screen.MAX_EVENT_ANNOUNCEMENTS)
    var before: Dictionary = session.snapshot()
    screen._pointer(-1,screen.tray_rects[1].get_center(),true,false)
    assert_eq(screen.controller.phase,"dragging")
    assert_true(screen.toast_queue.is_empty())
    assert_eq(screen.toast_label.modulate.a,0.0)
    assert_true(screen.hint_label.visible)
    assert_eq(session.snapshot(),before)
    assert_true(screen.last_growth_details.has("새 구간: 1, 2"),"fast next pick must not discard the award facts")
    screen._cancel_drag()
    screen._open_tower()
    assert_not_null(screen.growth_details_button)
    screen.growth_details_button.pressed.emit()
    var details: Label = screen.modal_content.get_child(1)
    for fact in ["새 구간: 1, 2","새 재료: 벽돌, 금속, 수정","새 장식: 아치 창문"]:
        assert_true(details.text.contains(fact),"tower detail flow retains "+fact)

func test_fixed_combined_event_is_bounded_and_keeps_every_fact_in_result_dialog():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    var before: Dictionary = session.snapshot()
    var after: Dictionary = before.duplicate(true)
    after.score = 500
    after.best = 500
    after.growth.total_floors = 11
    after.growth.representative_segment = 1
    var events: Array = [
        {"type":"PLACED","points":1},
        {"type":"CLEARED","lines":2,"points":240,"floors":2,"new_segments":1,"materials":["brick"],"parts":["brick_arch_window"]},
        {"type":"BATCH_SETTLED","streak":1},
        {"type":"SUPPLIED"},
        {"type":"GAME_OVER"}
    ]
    screen.last_event_announcements = screen._event_announcements(events,before,after)
    screen.last_growth_details = screen._growth_detail_lines(events[1],before,after)
    screen.last_event_details = screen._event_detail_lines(events,before,after)
    assert_lte(screen.last_event_announcements.size(),Screen.MAX_EVENT_ANNOUNCEMENTS)
    assert_true(screen.last_event_announcements.has("구간 +1 · 해금 2종"))
    assert_true(screen.last_event_announcements.has("기록 갱신 · 새 조각 · 게임 종료"))
    screen.state = after
    screen._results()
    # 결과 시트는 점수/탑 카드 뒤에 안내 문구를 둔다. 모든 사실이 시트 안에 남아야 한다.
    var body := _modal_text(screen)
    assert_true(body.contains("이번 결과 안내"))
    for fact in ["새 구간: 1","새 재료: 벽돌","새 장식: 아치 창문","새 최고 기록: 500점","연속 완성: 1묶음","새 조각 3개를 받았어요","게임 종료 · 500점 · 최고 500점"]:
        assert_true(body.contains(fact),"result dialog retains "+fact)

func _modal_text(screen) -> String:
    var texts: Array[String] = []
    var pending: Array[Node] = [screen.modal_content]
    while not pending.is_empty():
        var node: Node = pending.pop_front()
        if node is Label: texts.append(node.text)
        pending.append_array(node.get_children())
    return "\n".join(texts)

func _game_over_state() -> Dictionary:
    # 줄이 하나도 완성되지 않은 체커보드. 2칸 이상 조각은 어디에도 놓을 수 없다.
    var state: Dictionary = session.snapshot()
    for i in range(64):
        var filled := ((i/8)+(i%8))%2 == 0
        state.occupancy[i] = 1 if filled else 0
        state.cell_style[i] = 2 if filled else 0
    state.queue = ["square2_v0","square2_v0","square2_v0"]
    return state

func test_hud_chip_score_and_streak_follow_committed_state():
    var state := _crossing_at_floors(9)
    state.score = 12340
    state.best = 12340
    state.streak = 3
    state.best_streak = 3
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(360,800)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    assert_eq(screen.score_label.text,"12,340")
    assert_eq(screen.best_label.text,"최고 12,340")
    assert_eq(screen.chip_name.text,"내 탑 9층")
    assert_eq(screen.chip_remaining.text,"1층 남음")
    assert_true(screen.tower_button.accessibility_name.contains("다음 구간까지 1층"))
    assert_true(screen.streak_chip.visible)
    assert_eq(screen.streak_text.text,"3묶음 연속")
    assert_lt(screen.tower_button.get_rect().end.x,size_settings_left(screen),"chip never covers settings")
    screen._clear()
    assert_eq(screen.chip_name.text.ends_with("11층"),true)
    assert_true(screen.growth_badge.visible)
    assert_eq(screen.growth_badge.text,"+2층")
    assert_gt(screen.growth_glow,0.0)
    screen.interrupt()
    assert_false(screen.growth_badge.visible,"interruption hides cosmetic growth badge")
    assert_eq(session.snapshot().growth.total_floors,11)

func size_settings_left(screen) -> float:
    return screen.size.x-60

func test_streak_chip_hidden_below_two_and_in_compact():
    var state: Dictionary = session.snapshot()
    state.streak = 1
    state.best_streak = 4
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(360,800)
    screen.attach(session,path)
    assert_false(screen.streak_chip.visible)
    state = session.snapshot()
    state.streak = 4
    state.best_streak = 4
    install(state)
    screen.attach(session,path)
    assert_true(screen.streak_chip.visible)
    screen.size = Vector2(320,568)
    screen._layout()
    assert_true(screen.compact_layout)
    assert_false(screen.streak_chip.visible,"compact layout keeps the score row uncluttered")

func test_clear_dock_states_and_auto_switch_text():
    install(crossing())
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(360,800)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    screen.preferences.values.reduced_motion = true
    assert_false(screen.clear_button.disabled)
    assert_true(screen.clear_button.text.begins_with("2줄 클리어"))
    assert_true(screen.clear_button.text.contains("+240점 · 탑 +2층"))
    assert_eq(screen.auto_state.text,"끔")
    assert_eq(screen.auto_button.accessibility_name,"자동 클리어 꺼짐")
    screen._pointer(-1,screen.tray_rects[0].get_center(),true,false)
    assert_eq(screen.controller.phase,"dragging")
    assert_true(screen.clear_button.disabled)
    assert_true(screen.clear_button.text.contains("놓는 동안 잠겨요"))
    assert_eq(screen.auto_state.text,"대기")
    screen._cancel_drag()
    screen._clear()
    assert_true(screen.clear_button.disabled)
    assert_true(screen.clear_button.text.begins_with("대기"))
    screen._toggle_auto()
    assert_true(session.snapshot().auto_clear)
    assert_eq(screen.auto_state.text,"켬")
    assert_true(screen.clear_button.text.begins_with("자동"))

func test_pending_hint_and_must_clear_emphasis():
    install(crossing())
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    assert_true(screen.hint_label.text.begins_with("[완성] 2줄 대기"))
    assert_false(screen._must_clear_emphasis())
    var blocked := _game_over_state()
    for i in range(8):
        blocked.occupancy[i] = 1
        blocked.cell_style[i] = 2
    install(blocked)
    screen.attach(session,path)
    assert_eq(session.view().status,"MUST_CLEAR")
    assert_true(screen.hint_label.text.begins_with("[완성] 1줄"))
    assert_true(screen._must_clear_emphasis())
    assert_false(screen.clear_button.disabled)
    for slot_index in range(3): assert_false(screen.slot_fits[slot_index],"no square fits the blocked board")

func test_unplaceable_piece_is_marked_but_still_pickable_without_commit():
    var state: Dictionary = session.snapshot()
    state.occupancy.fill(0)
    state.cell_style.fill(0)
    for i in range(64):
        if i%8 != 7 and (i/8)%2 == 0:
            state.occupancy[i] = 1
            state.cell_style[i] = 2
    state.queue = ["square2_v0","single_v0","single_v0"]
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(360,800)
    screen.attach(session,path)
    assert_false(screen.slot_fits[0])
    assert_true(screen.slot_fits[1])
    assert_true(screen.tray_notes[0].visible)
    assert_eq(screen.tray_notes[0].text,"놓을 곳 없음")
    assert_false(screen.tray_notes[1].visible)
    var before: Dictionary = session.snapshot()
    screen._pointer(-1,screen.tray_rects[0].get_center(),true,false)
    assert_eq(screen.controller.phase,"dragging","blocked pieces remain pickable")
    assert_false(screen.tray_notes[0].visible,"dragged lane hides its note")
    screen._cancel_drag()
    assert_eq(session.snapshot(),before)

func test_drag_hint_counts_only_newly_completed_lines():
    var state := crossing()
    state.occupancy[3*8+0] = 0
    state.cell_style[3*8+0] = 0
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(360,800)
    screen.attach(session,path)
    assert_eq(session.view().clear_lines,1,"column 5 is already pending")
    screen._pointer(-1,screen.tray_rects[0].get_center(),true,false)
    var step: float = screen.board_rect.size.x/8
    screen._pointer(-1,screen.board_rect.position+Vector2(.5,3.5)*step,false,false)
    assert_true(screen.preview.ok)
    assert_eq(screen.preview_rows,[3])
    assert_eq(screen.preview_columns,[])
    assert_eq(screen.hint_label.text,"[가능] +1점 · 1줄 완성")
    screen._cancel_drag()
    assert_eq(screen.preview_rows,[])

func test_sheets_fit_safe_area_and_confirmation_order():
    install(crossing())
    for dims in [Vector2(320,568),Vector2(360,800)]:
        var screen := preload("res://tests/integration/inset_puzzle_screen.gd").new()
        add_child_autofree(screen)
        screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
        screen.size = dims
        screen.attach(session,path)
        screen._toggle_auto()
        var panel: Control = screen.modal.get_child(0)
        assert_gte(panel.position.y,24.0)
        assert_almost_eq(panel.position.y+panel.size.y,dims.y-24-8,1.0,"auto confirmation is a bottom sheet")
        assert_lt(panel.size.y,dims.y*.6,"sheet height follows its content")
        assert_true(screen.modal_actions is HBoxContainer)
        assert_eq(screen.modal_actions.get_child(0).text,"지우고 자동 전환","primary action stays first")
        assert_eq(screen.modal_actions.get_child(1).text,"수동 유지")
        assert_eq(screen.modal_actions.layout_direction,Control.LAYOUT_DIRECTION_RTL,"primary is drawn on the right")
        assert_true(_modal_text(screen).contains("이번 클리어 +240점 · 탑 +2층"))
        screen._close_modal()
        screen._settings()
        panel = screen.modal.get_child(0)
        assert_gte(panel.position.y,24.0)
        assert_lte(panel.position.y+panel.size.y,dims.y-24)
        var close: Control = screen.modal.get_meta("close_button")
        assert_true(panel.get_global_rect().encloses(close.get_global_rect()),"close control sits inside the sheet")
        var labels: Array[String] = []
        for child in screen.modal_content.get_children():
            if child is CheckButton: labels.append(child.text)
        assert_eq(labels,["효과음","진동","움직임 줄이기","큰 글씨"])
        assert_eq(screen.modal_actions.get_child(0).text,"계속하기")
        screen._close_modal()

func test_sound_switch_is_inverse_of_saved_muted_value():
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.attach(session,path)
    screen._settings()
    var sound: CheckButton
    for child in screen.modal_content.get_children():
        if child is CheckButton and child.text == "효과음": sound = child
    assert_true(sound.button_pressed)
    sound.emit_signal("toggled",false)
    assert_true(screen.preferences.values.muted)
    assert_false(screen.volume_slider.editable)
    assert_true((JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary).muted)

func test_results_sheet_restart_and_tower_actions():
    var state := _game_over_state()
    state.growth.total_floors = 15
    state.growth.brick_lines = 0
    state.growth.representative_segment = 1
    state.score = 4160
    state.best = 12340
    install(state)
    assert_eq(session.view().status,"GAME_OVER")
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(360,800)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    assert_eq(screen.clear_button.text,"결과 보기")
    screen._clear()
    var text := _modal_text(screen)
    for fact in ["더 놓을 곳이 없어요","이번 점수","4,160","최고 기록","12,340","내 탑 누적","15층","다음 구간까지 5층"]:
        assert_true(text.contains(fact),"results show "+fact)
    assert_false(text.contains("이번 판 +"),"no invented per-run floor counter")
    assert_eq(screen.modal_actions.get_child(0).text,"다시 하기")
    var secondary: HBoxContainer = screen.modal_actions.get_child(1)
    var actions: Array[String] = []
    for child in secondary.get_children(): actions.append(child.text)
    assert_eq(actions,["내 탑 보기","보드 보기"])
    secondary.get_child(0).pressed.emit()
    assert_eq(screen.screen_id,"tower")
    assert_null(screen.modal)
    screen._open_puzzle()
    screen._clear()
    var run_before: int = session.snapshot().run_id
    screen.modal_actions.get_child(0).pressed.emit()
    assert_eq(session.snapshot().run_id,run_before+1,"restart commits one NEW_RUN")
    assert_eq(session.snapshot().growth.total_floors,15)
    assert_eq(screen.score_label.text,"0")

func test_phase3_overview_counts_sparse_facades_and_navigation_is_read_only():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 3003
    state.growth.representative_segment = 150
    state.growth.segment_styles = {"1":"brick","150":"metal","300":"crystal"}
    state.best = 12340
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    var before: Dictionary = session.snapshot()
    screen._open_tower()
    screen._open_tower_overview()
    assert_eq(screen.screen_id,"tower_overview")
    assert_eq(screen._maximum_tower_segment(),301)
    assert_eq(screen._overview_floor_counts(),{"wood":2973,"brick":10,"metal":10,"crystal":10})
    assert_true(screen.controls.get_children().any(func(child):return child is Label and child.text.contains("3,003층")))
    assert_true(screen.controls.get_children().any(func(child):return child is Label and child.text.contains("벽돌 0.3%")),"small nonzero facade share remains visible")
    screen._show_segment_jump()
    assert_eq(screen.controller.phase,"modal")
    assert_eq(screen.segment_jump_input.get_selected_text(),"150","prefilled jump target is ready to replace")
    screen.segment_jump_input.text = "302"
    screen._confirm_segment_jump()
    assert_eq(screen.screen_id,"tower_overview")
    assert_true(screen.segment_jump_status.text.contains("1~301"))
    assert_eq(screen.segment_jump_input.get_selected_text(),"302","invalid target is ready to correct")
    screen.segment_jump_input.text = "301"
    screen._confirm_segment_jump()
    assert_eq(screen.screen_id,"tower")
    assert_eq(screen.selected_segment,301)
    assert_eq(screen.tower_segment_view().count,3)
    screen._open_tower_focus()
    assert_eq(screen.screen_id,"tower_focus")
    assert_eq(screen.tower_segment_view().count,3)
    assert_true(screen.handle_back())
    assert_eq(screen.screen_id,"tower")
    assert_eq(screen.selected_segment,301)
    screen._open_tower_overview()
    screen._overview_to_representative()
    assert_eq(screen.selected_segment,150)
    assert_eq(screen.screen_id,"tower")
    assert_eq(session.snapshot(),before,"overview and jump do not save or advance supply")

func test_phase3_copy_sheet_validates_target_and_selects_committed_copy():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 63
    state.growth.brick_lines = 10
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"1":"brick"}
    state.growth.segment_parts = {"1":["brick_arch_window"]}
    install(state)
    var screen := Screen.new()
    add_child_autofree(screen)
    screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
    screen.size = Vector2(320,568)
    screen.attach(session,path)
    screen.preferences.values.muted = true
    screen._open_tower()
    var before: Dictionary = session.snapshot()
    screen._show_segment_copy()
    assert_eq(screen.controller.phase,"modal")
    assert_eq(screen.segment_copy_input.get_selected_text(),"2","prefilled copy target is ready to replace")
    assert_true(screen.segment_copy_preview.text.contains("대상 구간 2"))
    screen.segment_copy_input.text = "7"
    screen._confirm_segment_copy()
    assert_eq(screen.controller.phase,"modal")
    assert_eq(screen.segment_copy_input.get_selected_text(),"7","invalid copy target is ready to correct")
    assert_eq(session.snapshot(),before,"partial target never commits")
    screen.segment_copy_input.text = "2"
    screen._refresh_segment_copy_preview()
    assert_true(screen.segment_copy_preview.text.contains("복사 후: 벽돌"))
    screen._confirm_segment_copy()
    assert_eq(screen.screen_id,"tower")
    assert_eq(screen.selected_segment,2)
    assert_eq(session.snapshot().growth.segment_styles["2"],"brick")
    assert_eq(session.snapshot().growth.segment_parts["2"],["brick_arch_window"])
    assert_eq(session.snapshot().revision,before.revision+1)

func test_format_int_is_exact():
    assert_eq(Screen.format_int(0),"0")
    assert_eq(Screen.format_int(999),"999")
    assert_eq(Screen.format_int(1000),"1,000")
    assert_eq(Screen.format_int(12340),"12,340")
    assert_eq(Screen.format_int(9000000000000000000),"9,000,000,000,000,000,000")
    assert_eq(Screen.format_int(-4160),"-4,160")
