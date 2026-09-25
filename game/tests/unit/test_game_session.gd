extends "res://addons/gut/test.gd"
## 상태 전이와 커밋 경계를 사용자 결과 중심으로 검증한다.
const Session = preload("res://scripts/core/game_session.gd")
const Repository = preload("res://scripts/core/memory_save_repository.gd")
const Growth = preload("res://scripts/core/growth_rules.gd")
var repo
var session

class ReentrantRepository:
    extends "res://scripts/core/memory_save_repository.gd"
    var callback: Callable
    var nested_result: Dictionary
    func commit(candidate: Dictionary, expected_revision: int) -> Dictionary:
        if callback.is_valid(): nested_result = callback.call()
        return super.commit(candidate, expected_revision)

func before_each():
    repo = Repository.new()
    var made: Dictionary = Session.start(repo, "test-session", "20260921")
    assert_true(made.ok)
    session = made.session

func action(kind: String, extra: Dictionary = {}) -> Dictionary:
    var state: Dictionary = session.snapshot()
    var result := {"type": kind, "session_id": state.session_id, "event_id": state.last_event_id + 1}
    result.merge(extra)
    return result

func place(slot: int, x: int, y: int) -> Dictionary:
    return action("PLACE", {"batch_id": session.snapshot().batch_id, "slot": slot, "x": x, "y": y})

func install(state: Dictionary) -> void:
    for i in range(64): state.cell_style[i] = 1 if state.occupancy[i] else 0
    repo = Repository.new()
    assert_true(repo.commit(state, -1).ok)
    var resumed: Dictionary = Session.resume(repo)
    assert_true(resumed.ok, str(resumed))
    if resumed.ok: session = resumed.session

func with_lines(count: int, total: int = 0) -> Dictionary:
    var state: Dictionary = session.snapshot()
    state.occupancy.fill(0)
    for row in range(count):
        for x in range(8): state.occupancy[row * 8 + x] = 1
    state.queue = ["single_v0", "single_v0", "single_v0"]
    state.auto_clear = false
    state.growth = Growth.initial()
    state.growth.total_floors = total
    state.growth.representative_segment = 1 if total >= 10 else 0
    return state

func test_initial_supply_commits_before_exposure_and_resume_draws_nothing():
    assert_eq(session.snapshot(), repo.load_snapshot().snapshot)
    assert_eq(Session.resume(repo).session.snapshot(), session.snapshot())
    assert_eq(Session.start(repo, "different", "1").error, "SAVE_ALREADY_EXISTS")
    var empty = Repository.new()
    empty.fail_next_commit = true
    assert_eq(Session.start(empty, "test", "1").error, "SAVE_FAILED")
    assert_false(empty.load_snapshot().found)
    assert_eq(Session.resume(empty).error, "SAVE_NOT_FOUND")

func test_invalid_placements_preserve_board_queue_score_rng_and_event_id():
    var state: Dictionary = session.snapshot()
    state.queue = ["square2_v0", "single_v0", "single_v0"]
    state.occupancy[0] = 1
    install(state)
    var before: Dictionary = session.snapshot()
    for move in [place(0, -1, 0), place(0, 7, 7), place(0, 0, 0), place(3, 0, 0), place(0, 9223372036854775807, 0)]:
        var result: Dictionary = session.dispatch(move)
        assert_false(result.ok)
        assert_eq(result.events, [])
        assert_eq(session.snapshot(), before)
        assert_eq(repo.load_snapshot().snapshot, before)
    var bad := place(0, 1, 1)
    bad.x = 1.5
    assert_eq(session.dispatch(bad).error, "INVALID_ACTION")
    assert_eq(session.snapshot(), before)

func test_manual_crossing_clear_counts_union_and_keeps_tray_checkpoint():
    var state: Dictionary = session.snapshot()
    for i in range(8):
        state.occupancy[3 * 8 + i] = 1
        state.occupancy[i * 8 + 5] = 1
    install(state)
    var before: Dictionary = session.snapshot()
    var result: Dictionary = session.dispatch(action("CLEAR"))
    assert_true(result.ok)
    var after: Dictionary = session.snapshot()
    assert_eq(after.occupancy.count(1), 0)
    assert_eq(after.cell_style.count(0), 64)
    assert_eq(after.score, 240)
    assert_eq(after.growth.total_floors, 2)
    assert_eq(after.growth.brick_lines, 2)
    assert_eq(after.queue, before.queue)
    assert_eq(after.checkpoint, before.checkpoint)
    assert_false(after.batch_success)
    assert_eq(result.events[0].lines, 2)
    assert_eq(session.dispatch(action("CLEAR")).error, "NO_LINES")

func test_full_board_clear_sixteen_lines_and_two_segment_crossings():
    var state := with_lines(8, 9)
    install(state)
    assert_eq(session.view().status, "MUST_CLEAR")
    var result: Dictionary = session.dispatch(action("CLEAR"))
    assert_true(result.ok)
    assert_eq(session.snapshot().score, 2560)
    assert_eq(session.snapshot().growth.total_floors, 25)
    assert_eq(result.events[0].new_segments, 2)
    assert_eq(session.view().growth.partial_floors, 5)
    assert_eq(session.view().growth.materials, ["wood", "brick", "metal", "crystal"])
    assert_eq(session.snapshot().growth.representative_segment, 1)

func test_auto_confirmation_cancel_and_confirm_are_one_commit():
    install(with_lines(2))
    var before: Dictionary = session.snapshot()
    var request := action("SET_AUTO", {"enabled": true, "confirmed": false})
    assert_eq(session.dispatch(request).error, "CONFIRMATION_REQUIRED")
    assert_eq(session.snapshot(), before)
    request.confirmed = true
    var result: Dictionary = session.dispatch(request)
    assert_true(result.ok)
    assert_true(session.snapshot().auto_clear)
    assert_eq(session.snapshot().score, 240)
    assert_eq(session.snapshot().revision, before.revision + 1)
    assert_eq(session.snapshot().checkpoint, before.checkpoint)
    assert_eq(session.dispatch(request).error, "ALREADY_APPLIED")
    assert_eq(session.snapshot().score, 240)
    assert_eq(session.dispatch(action("CLEAR")).error, "MANUAL_ONLY")

func test_auto_placement_detects_success_before_clear_and_refills_once():
    var state: Dictionary = session.snapshot()
    for x in range(7): state.occupancy[x] = 1
    state.auto_clear = true
    state.queue = ["", "", "single_v0"]
    state.streak = 2
    state.best_streak = 2
    install(state)
    var before: Dictionary = session.snapshot()
    assert_eq(session.view().witness.slot, 2)
    var result: Dictionary = session.dispatch(place(2, 7, 0))
    assert_true(result.ok)
    var after: Dictionary = session.snapshot()
    assert_eq(after.score, 101)
    assert_eq(after.growth.total_floors, 1)
    assert_eq(after.streak, 3)
    assert_eq(after.best_streak, 3)
    assert_eq(after.batch_id, before.batch_id + 1)
    assert_eq(after.queue.size(), 3)
    assert_ne(after.checkpoint, before.checkpoint)
    assert_false(after.batch_success)
    assert_eq(result.events.map(func(e): return e.type), ["PLACED", "CLEARED", "BATCH_SETTLED", "SUPPLIED"])

func test_old_pending_line_does_not_count_as_new_batch_success():
    var state := with_lines(1)
    state.queue = ["single_v0", "", ""]
    state.streak = 2
    state.best_streak = 2
    install(state)
    assert_true(session.dispatch(place(0, 0, 2)).ok)
    assert_eq(session.snapshot().streak, 0)
    assert_eq(session.snapshot().best_streak, 2)
    assert_eq(session.view().pending_rows, [0])
    assert_eq(session.snapshot().growth.total_floors, 0)

func test_failed_save_rolls_back_refill_and_retry_matches_control():
    var state: Dictionary = session.snapshot()
    state.queue = ["single_v0", "", ""]
    install(state)
    var before: Dictionary = session.snapshot()
    var control_repo = Repository.new()
    control_repo.commit(before, -1)
    var control = Session.resume(control_repo).session
    var move := place(0, 0, 0)
    var expected: Dictionary = control.dispatch(move)
    repo.fail_next_commit = true
    var failed: Dictionary = session.dispatch(move)
    assert_eq(failed.error, "SAVE_FAILED")
    assert_eq(failed.events, [])
    assert_eq(session.snapshot(), before)
    assert_eq(repo.load_snapshot().snapshot, before)
    assert_eq(session.dispatch(move), expected)
    assert_eq(Session.resume(repo).session.snapshot(), expected.snapshot)

func test_ambiguous_commit_requires_resume_and_never_reawards():
    install(with_lines(2))
    var before: Dictionary = session.snapshot()
    var request := action("CLEAR")
    repo.uncertain_next_commit = true
    var result: Dictionary = session.dispatch(request)
    assert_eq(result.error, "COMMIT_UNCERTAIN")
    assert_eq(result.events, [])
    assert_eq(session.snapshot(), before)
    assert_eq(session.dispatch(request).error, "RECOVERY_REQUIRED")
    session = Session.resume(repo).session
    assert_eq(session.snapshot().score, 240)
    assert_eq(session.snapshot().growth.total_floors, 2)
    assert_eq(session.dispatch(request).error, "ALREADY_APPLIED")
    assert_eq(session.snapshot().score, 240)

func test_competing_writer_cannot_overwrite_committed_state():
    var other = Session.resume(repo).session
    var request := action("SET_AUTO", {"enabled": true, "confirmed": false})
    assert_true(other.dispatch(request).ok)
    assert_eq(session.dispatch(request).error, "SAVE_CONFLICT")
    assert_eq(session.dispatch(request).error, "RECOVERY_REQUIRED")
    assert_true(Session.resume(repo).session.snapshot().auto_clear)

func test_duplicate_out_of_order_and_stale_batch_do_not_consume():
    var state: Dictionary = session.snapshot()
    state.queue = ["single_v0", "single_v0", "single_v0"]
    install(state)
    var request := place(0, 0, 0)
    var gap := request.duplicate()
    gap.event_id = 2
    assert_eq(session.dispatch(gap).error, "EVENT_OUT_OF_ORDER")
    var wrong := request.duplicate()
    wrong.session_id = "other"
    assert_eq(session.dispatch(wrong).error, "SESSION_MISMATCH")
    assert_true(session.dispatch(request).ok)
    assert_eq(session.dispatch(request).error, "ALREADY_APPLIED")
    assert_eq(session.dispatch(place(0, 1, 0)).error, "SLOT_CONSUMED")
    var stale := place(1, 1, 0)
    stale.batch_id += 1
    assert_eq(session.dispatch(stale).error, "STALE_BATCH")
    assert_eq(session.snapshot().score, 1)
    assert_eq(session.snapshot().last_event_id, 1)

func test_new_run_preserves_growth_records_mode_and_advances_identity():
    install(with_lines(2, 19))
    assert_true(session.dispatch(action("SET_AUTO", {"enabled": true, "confirmed": true})).ok)
    var before: Dictionary = session.snapshot()
    var request := action("NEW_RUN", {"seed_text": "-9223372036854775808", "confirmed": false})
    assert_eq(session.dispatch(request).error, "CONFIRMATION_REQUIRED")
    request.confirmed = true
    assert_true(session.dispatch(request).ok)
    var after: Dictionary = session.snapshot()
    assert_eq(after.score, 0)
    assert_eq(after.best, before.best)
    assert_eq(after.growth, before.growth)
    assert_true(after.auto_clear)
    assert_eq(after.run_id, before.run_id + 1)
    assert_eq(after.batch_id, before.batch_id + 1)
    assert_eq(after.session_id, before.session_id)
    assert_eq(after.checkpoint.rng_seed, "-9223372036854775808")
    assert_eq(after.occupancy.count(0), 64)

func test_materials_and_every_defined_part_have_cumulative_route():
    for spec in [{"threshold": 30, "id": "brick"}, {"threshold": 100, "id": "metal"}, {"threshold": 250, "id": "crystal"}]:
        install(with_lines(1, spec.threshold - 1))
        assert_true(session.dispatch(action("CLEAR")).ok)
        assert_has(session.view().growth.materials, spec.id)
        assert_eq(session.snapshot().growth.brick_lines, 0)
    for part in Growth.PARTS:
        install(with_lines(1, part.total - 1))
        assert_true(session.dispatch(action("CLEAR")).ok)
        assert_has(session.view().growth.parts, part.id)

func test_material_progress_counts_lower_tiers_and_unlocks_parts_same_event():
    var state := with_lines(4, 9)
    state.growth.brick_lines = 9
    install(state)
    assert_true(session.dispatch(action("CLEAR")).ok)
    var growth: Dictionary = session.snapshot().growth
    assert_eq(growth.total_floors, 13)
    assert_eq(growth.brick_lines, 13)
    assert_eq(growth.metal_lines, 4)
    assert_eq(growth.crystal_lines, 4)
    assert_has(session.view().growth.parts, "brick_arch_window")
    assert_eq(session.view().growth.completed_segments, 1)

func test_segment_edits_representative_and_new_wood_segments_are_preserved():
    install(with_lines(1, 29))
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment": 1, "material": "brick"})).ok == false)
    assert_true(session.dispatch(action("CLEAR")).ok)
    assert_eq(session.view().growth.floors_to_next, 10)
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment": 1, "material": "brick"})).ok)
    assert_true(session.dispatch(action("SET_REPRESENTATIVE", {"segment": 2})).ok)
    var state := with_lines(1, 39)
    state.growth.segment_styles = {"1": "brick"}
    state.growth.representative_segment = 2
    install(state)
    assert_true(session.dispatch(action("CLEAR")).ok)
    assert_eq(session.snapshot().growth.segment_styles, {"1": "brick"})
    assert_eq(session.snapshot().growth.representative_segment, 2)
    assert_eq(session.dispatch(action("SET_REPRESENTATIVE", {"segment": 5})).error, "INVALID_SEGMENT")
    assert_eq(session.dispatch(action("SET_SEGMENT_STYLE", {"segment": 2, "material": "crystal"})).error, "MATERIAL_LOCKED")

func test_brick_arch_part_unlock_equip_dormancy_independence_and_no_puzzle_mutation():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 60
    state.growth.brick_lines = 2
    state.growth.representative_segment = 6
    state.growth.segment_styles = {"1":"brick"}
    install(state)
    var before: Dictionary = session.snapshot()
    var equipped: Dictionary = session.dispatch(action("SET_SEGMENT_PART", {"segment":1,"part":"brick_arch_window","enabled":true}))
    assert_true(equipped.ok, str(equipped))
    assert_eq(equipped.events.map(func(e):return e.type), ["TOWER_CHANGED"])
    var after: Dictionary = session.snapshot()
    assert_eq(after.growth.segment_parts, {"1":["brick_arch_window"]})
    assert_eq(after.score, before.score)
    assert_eq(after.growth.total_floors, before.growth.total_floors)
    assert_eq(after.checkpoint, before.checkpoint)
    assert_eq(after.queue, before.queue)
    assert_eq(session.dispatch(action("SET_SEGMENT_PART", {"segment":1,"part":"brick_arch_window","enabled":true})).error, "NO_CHANGE")
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment":1,"material":"wood"})).ok)
    assert_eq(session.snapshot().growth.segment_parts, {"1":["brick_arch_window"]})
    assert_true(session.dispatch(action("SET_SEGMENT_PART", {"segment":1,"part":"brick_arch_window","enabled":false})).ok)
    assert_eq(session.snapshot().growth.segment_parts, {})
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment":1,"material":"brick"})).ok)
    assert_true(session.dispatch(action("SET_SEGMENT_PART", {"segment":1,"part":"brick_arch_window","enabled":true})).ok)
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment":2,"material":"brick"})).ok)
    assert_false(session.snapshot().growth.segment_parts.has("2"))

func test_brick_arch_part_progress_lock_and_save_failure_have_no_phantom_change():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 30
    state.growth.brick_lines = 2
    state.growth.representative_segment = 3
    state.growth.segment_styles = {"1":"brick"}
    install(state)
    var attempt: Dictionary = action("SET_SEGMENT_PART", {"segment":1,"part":"brick_arch_window","enabled":true})
    var before: Dictionary = session.snapshot()
    assert_eq(session.dispatch(attempt).error, "PART_LOCKED")
    assert_eq(session.snapshot(), before)
    var progress: Dictionary = state.duplicate(true)
    progress.growth.total_floors = 30
    progress.growth.brick_lines = 9
    progress.occupancy.fill(0)
    for row in range(2):
        for x in range(8): progress.occupancy[row*8+x] = 1
    progress.queue = ["single_v0","single_v0","single_v0"]
    install(progress)
    assert_true(session.dispatch(action("CLEAR")).ok)
    assert_has(session.view().growth.parts,"brick_arch_window")
    var unlocked_attempt: Dictionary = action("SET_SEGMENT_PART", {"segment":1,"part":"brick_arch_window","enabled":true})
    before = session.snapshot()
    repo.fail_next_commit = true
    assert_eq(session.dispatch(unlocked_attempt).error,"SAVE_FAILED")
    assert_eq(session.snapshot(),before)
    assert_true(session.dispatch(unlocked_attempt).ok)

func test_brick_terrace_unlock_thresholds_coexistence_order_dormancy_and_save_failure():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 119
    state.growth.brick_lines = 29
    state.growth.representative_segment = 11
    state.growth.segment_styles = {"1":"brick"}
    state.growth.segment_parts = {"1":["brick_arch_window"]}
    install(state)
    assert_false("brick_terrace" in session.view().growth.parts)
    var action_terrace := action("SET_SEGMENT_PART", {"segment":1,"part":"brick_terrace","enabled":true})
    var before: Dictionary = session.snapshot()
    assert_eq(session.dispatch(action_terrace).error,"PART_LOCKED")
    assert_eq(session.snapshot(),before)

    var quick_unlock: Dictionary = state.duplicate(true)
    quick_unlock.growth.brick_lines = 30
    install(quick_unlock)
    assert_has(session.view().growth.parts,"brick_terrace")
    before = session.snapshot()
    repo.fail_next_commit = true
    assert_eq(session.dispatch(action_terrace).error,"SAVE_FAILED")
    assert_eq(session.snapshot(),before,"failed terrace commit leaves no phantom state or event")
    assert_true(session.dispatch(action_terrace).ok)
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_arch_window","brick_terrace"]})
    assert_eq(session.dispatch(action("SET_SEGMENT_PART", {"segment":1,"part":"brick_terrace","enabled":true})).error,"NO_CHANGE")
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment":1,"material":"metal"})).ok)
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_arch_window","brick_terrace"]},"decorations remain dormant across material changes")
    assert_true(session.dispatch(action("SET_SEGMENT_PART", {"segment":1,"part":"brick_arch_window","enabled":false})).ok)
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_terrace"]})
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment":1,"material":"brick"})).ok)
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment":2,"material":"brick"})).ok)
    assert_true(session.dispatch(action("SET_SEGMENT_PART", {"segment":2,"part":"brick_terrace","enabled":true})).ok)
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_terrace"],"2":["brick_terrace"]},"parts are independent per completed segment")

    var cumulative: Dictionary = state.duplicate(true)
    cumulative.growth.total_floors = 120
    cumulative.growth.brick_lines = 2
    install(cumulative)
    assert_has(session.view().growth.parts,"brick_terrace","cumulative 120-floor path unlocks terrace")

func test_brick_cornice_unlock_paths_and_three_part_commit_failure_and_restore():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 199
    state.growth.brick_lines = 59
    state.growth.representative_segment = 19
    state.growth.segment_styles = {"19":"brick"}
    state.growth.segment_parts = {"19":["brick_arch_window","brick_terrace"]}
    install(state)
    assert_false("brick_cornice" in session.view().growth.parts)
    var equip := action("SET_SEGMENT_PART", {"segment":19,"part":"brick_cornice","enabled":true})
    assert_eq(session.dispatch(equip).error,"PART_LOCKED")

    var unlocked: Dictionary = session.snapshot()
    unlocked.growth.total_floors = 200
    install(unlocked)
    assert_has(session.view().growth.parts,"brick_cornice","cumulative 200-floor path unlocks cornice")
    var before: Dictionary = session.snapshot()
    repo.fail_next_commit = true
    var failure: Dictionary = session.dispatch(equip)
    assert_eq(failure.error,"SAVE_FAILED")
    assert_eq(failure.events,[])
    assert_eq(session.snapshot(),before,"failed save cannot publish or persist the cornice")
    assert_true(session.dispatch(equip).ok)
    assert_eq(session.snapshot().growth.segment_parts["19"],["brick_arch_window","brick_cornice","brick_terrace"])
    assert_eq(session.dispatch(action("SET_SEGMENT_PART", {"segment":19,"part":"brick_cornice","enabled":true})).error,"NO_CHANGE")
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment":19,"material":"metal"})).ok)
    assert_eq(session.snapshot().growth.segment_parts["19"],["brick_arch_window","brick_cornice","brick_terrace"],"parts remain dormant across facade changes")
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment":19,"material":"brick"})).ok)

    var fast: Dictionary = session.snapshot()
    fast.growth.total_floors = 60
    fast.growth.brick_lines = 60
    fast.growth.representative_segment = 6
    fast.growth.segment_styles = {"6":"brick"}
    fast.growth.segment_parts = {}
    install(fast)
    assert_has(session.view().growth.parts,"brick_cornice","brick 60-line path unlocks cornice")

func test_brick_landmark_unlock_and_four_part_sparse_commit_failure_and_dormancy():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 299
    state.growth.brick_lines = 99
    state.growth.representative_segment = 29
    state.growth.segment_styles = {"29":"brick"}
    state.growth.segment_parts = {"29":["brick_arch_window","brick_cornice","brick_terrace"]}
    install(state)
    assert_false("brick_landmark" in session.view().growth.parts)
    var equip := action("SET_SEGMENT_PART", {"segment":29,"part":"brick_landmark","enabled":true})
    assert_eq(session.dispatch(equip).error,"PART_LOCKED")

    var unlocked: Dictionary = session.snapshot()
    unlocked.growth.total_floors = 300
    install(unlocked)
    assert_has(session.view().growth.parts,"brick_landmark","300-floor route unlocks landmark after base brick")
    var before: Dictionary = session.snapshot()
    repo.fail_next_commit = true
    var failed: Dictionary = session.dispatch(equip)
    assert_eq(failed.error,"SAVE_FAILED")
    assert_eq(failed.events,[])
    assert_eq(session.snapshot(),before,"failed commit has no phantom landmark part")
    assert_true(session.dispatch(equip).ok)
    assert_eq(session.snapshot().growth.segment_parts["29"],["brick_arch_window","brick_cornice","brick_landmark","brick_terrace"])
    assert_eq(session.dispatch(action("SET_SEGMENT_PART", {"segment":29,"part":"brick_landmark","enabled":true})).error,"NO_CHANGE")
    assert_true(session.dispatch(action("SET_SEGMENT_STYLE", {"segment":29,"material":"metal"})).ok)
    assert_eq(session.snapshot().growth.segment_parts["29"].size(),4,"all four parts stay dormant on a different material")
    assert_true(session.dispatch(action("SET_SEGMENT_PART", {"segment":29,"part":"brick_landmark","enabled":false})).ok)
    assert_eq(session.snapshot().growth.segment_parts["29"],["brick_arch_window","brick_cornice","brick_terrace"],"dormant landmark can be removed")

    var fast: Dictionary = session.snapshot()
    fast.growth.total_floors = 100
    fast.growth.brick_lines = 100
    fast.growth.representative_segment = 10
    fast.growth.segment_styles = {"10":"brick"}
    fast.growth.segment_parts = {}
    install(fast)
    assert_has(session.view().growth.parts,"brick_landmark","100-line route unlocks landmark")

func test_copy_segment_appearance_commits_one_target_and_preserves_game_progress():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 300
    state.growth.brick_lines = 100
    state.growth.representative_segment = 3
    state.growth.segment_styles = {"1":"brick","2":"metal","3":"crystal"}
    state.growth.segment_parts = {"1":["brick_arch_window","brick_cornice","brick_landmark","brick_terrace"],"2":["brick_arch_window"]}
    install(state)
    var before: Dictionary = session.snapshot()
    var copied: Dictionary = session.dispatch(action("COPY_SEGMENT_APPEARANCE",{"source":1,"target":2,"confirmed":true}))
    assert_true(copied.ok,str(copied))
    assert_eq(copied.events,[{"type":"TOWER_CHANGED","segment":2,"copied_from":1}])
    var after: Dictionary = session.snapshot()
    assert_eq(after.revision,before.revision+1)
    assert_eq(after.growth.segment_styles,{"1":"brick","2":"brick","3":"crystal"})
    assert_eq(after.growth.segment_parts["2"],before.growth.segment_parts["1"])
    assert_eq(after.growth.segment_parts["1"],before.growth.segment_parts["1"])
    assert_eq(after.growth.representative_segment,3)
    assert_eq(after.growth.total_floors,before.growth.total_floors)
    for key in ["score","best","queue","occupancy","cell_style","checkpoint"]:
        assert_eq(after[key],before[key],"appearance copy preserves "+key)
    assert_eq(Session.resume(repo).session.snapshot(),after)
    assert_eq(session.dispatch(action("COPY_SEGMENT_APPEARANCE",{"source":1,"target":2,"confirmed":true})).error,"NO_CHANGE")
    assert_eq(session.snapshot(),after)

func test_copy_segment_appearance_rejects_invalid_and_failed_saves_without_change():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 25
    state.growth.brick_lines = 2
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"1":"brick"}
    install(state)
    var before: Dictionary = session.snapshot()
    for extra in [
        {"source":0,"target":2,"confirmed":true},
        {"source":1,"target":3,"confirmed":true},
        {"source":3,"target":2,"confirmed":true},
        {"source":1,"target":2,"confirmed":false},
        {"source":1,"target":1,"confirmed":true}]:
        var result: Dictionary = session.dispatch(action("COPY_SEGMENT_APPEARANCE",extra))
        assert_false(result.ok)
        assert_eq(result.events,[])
        assert_eq(session.snapshot(),before)
    var invalid_type := action("COPY_SEGMENT_APPEARANCE",{"source":1.0,"target":2,"confirmed":true})
    assert_eq(session.dispatch(invalid_type).error,"INVALID_SEGMENT")
    assert_eq(session.snapshot(),before)
    repo.fail_next_commit = true
    assert_eq(session.dispatch(action("COPY_SEGMENT_APPEARANCE",{"source":1,"target":2,"confirmed":true})).error,"SAVE_FAILED")
    assert_eq(session.snapshot(),before)
    assert_eq(repo.load_snapshot().snapshot,before)
    assert_true(session.dispatch(action("COPY_SEGMENT_APPEARANCE",{"source":1,"target":2,"confirmed":true})).ok)
    assert_eq(session.snapshot().growth.segment_styles,{"1":"brick","2":"brick"})

func test_copy_nonbrick_appearance_discards_dormant_parts_at_target():
    var state: Dictionary = session.snapshot()
    state.growth.total_floors = 60
    state.growth.brick_lines = 10
    state.growth.representative_segment = 1
    state.growth.segment_styles = {"2":"brick"}
    state.growth.segment_parts = {"1":["brick_arch_window"],"2":["brick_arch_window"]}
    install(state)
    var copied: Dictionary = session.dispatch(action("COPY_SEGMENT_APPEARANCE",{"source":1,"target":2,"confirmed":true}))
    assert_true(copied.ok,str(copied))
    assert_eq(session.snapshot().growth.segment_styles,{})
    assert_eq(session.snapshot().growth.segment_parts,{"1":["brick_arch_window"]})
    assert_eq(Session.resume(repo).session.snapshot(),session.snapshot())

func test_memory_repository_v1_resume_migrates_without_write_then_action_commits_v2():
    var legacy: Dictionary = session.snapshot()
    legacy.schema_version = "bt_session_v1"
    legacy.growth.erase("segment_parts")
    var old_repository = Repository.new()
    assert_true(old_repository.commit(legacy,-1).ok)
    var old_bytes: Dictionary = old_repository._stored.duplicate(true)
    var resumed := Session.resume(old_repository)
    assert_true(resumed.ok,str(resumed))
    assert_eq(resumed.session.snapshot().schema_version,"bt_session_v2")
    assert_eq(resumed.session.snapshot().growth.segment_parts,{})
    assert_eq(old_repository._stored,old_bytes)
    var request := {"type":"SET_AUTO","session_id":resumed.session.snapshot().session_id,"event_id":1,"enabled":true,"confirmed":false}
    assert_true(resumed.session.dispatch(request).ok)
    assert_eq(old_repository._stored.schema_version,"bt_session_v2")

func test_bad_snapshots_versions_numeric_types_and_styles_are_rejected():
    var baseline: Dictionary = session.snapshot()
    var changes := [{"schema_version": "future"}, {"score": 0.0}, {"queue": ["", "", ""]}, {"revision": 1}, {"best": -1}]
    for change in changes:
        var state := baseline.duplicate(true)
        state.merge(change, true)
        var bad_repo = Repository.new()
        bad_repo.commit(state, -1)
        assert_false(Session.resume(bad_repo).ok)
        assert_eq(bad_repo.load_snapshot().snapshot, state)
    var state := baseline.duplicate(true)
    state.cell_style[0] = 2
    var bad_repo = Repository.new()
    bad_repo.commit(state, -1)
    assert_eq(Session.resume(bad_repo).error, "INVALID_STATE")
    state = baseline.duplicate(true)
    state.checkpoint.config_hash = "wrong"
    bad_repo = Repository.new()
    bad_repo.commit(state, -1)
    assert_eq(Session.resume(bad_repo).error, "CHECKPOINT_VERSION_MISMATCH")

func test_repository_reentrancy_is_rejected_until_commit_finishes():
    var reentrant = ReentrantRepository.new()
    var current = Session.start(reentrant, "nested", "42").session
    var request := {"type": "SET_AUTO", "session_id": "nested", "event_id": 1, "enabled": true, "confirmed": false}
    reentrant.callback = func(): return current.dispatch(request)
    assert_true(current.dispatch(request).ok)
    assert_eq(reentrant.nested_result.error, "BUSY")
    assert_eq(current.snapshot().revision, 1)
    reentrant.callback = Callable()

func test_mid_tray_game_over_ends_streak_without_settling_or_losing_growth():
    var state: Dictionary = session.snapshot()
    for y in range(8):
        for x in range(8): state.occupancy[y * 8 + x] = (x + y) % 2
    state.occupancy[1] = 0
    state.queue = ["line2_v0", "line2_v0", "line2_v0"]
    state.streak = 4
    state.best_streak = 4
    state.growth.total_floors = 9
    install(state)
    var result: Dictionary = session.dispatch(place(0, 0, 0))
    assert_true(result.ok)
    assert_eq(session.view().status, "GAME_OVER")
    assert_eq(session.snapshot().streak, 0)
    assert_eq(session.snapshot().best_streak, 4)
    assert_eq(session.snapshot().growth.total_floors, 9)
    assert_eq(result.events.map(func(e): return e.type), ["PLACED", "GAME_OVER"])
    assert_eq(session.dispatch(place(1, 0, 0)).error, "GAME_OVER")
    assert_true(session.dispatch(action("NEW_RUN", {"seed_text": "7", "confirmed": false})).ok)
    assert_eq(session.snapshot().growth.total_floors, 9)

func test_action_sequence_replay_matches_across_forty_session_resumes():
    var replay_repo = Repository.new()
    var replay = Session.start(replay_repo, "test-session", "20260921").session
    var clears := 0
    var supplies := 0
    for step in range(200):
        var state: Dictionary = session.snapshot()
        var visible: Dictionary = session.view()
        var request: Dictionary
        if visible.status == "GAME_OVER":
            request = action("NEW_RUN", {"seed_text": str(step), "confirmed": false})
        elif step % 13 == 0:
            request = action("SET_AUTO", {"enabled": not state.auto_clear, "confirmed": true})
        elif visible.status == "MUST_CLEAR" or (not state.auto_clear and (not visible.pending_rows.is_empty() or not visible.pending_columns.is_empty())):
            request = action("CLEAR")
        else:
            var w: Dictionary = visible.witness
            request = place(w.slot, w.x, w.y)
        var result: Dictionary = session.dispatch(request)
        if step % 5 == 0: replay = Session.resume(replay_repo).session
        assert_true(result.ok, "step %d" % step)
        assert_eq(replay.dispatch(request), result, "same action after resume at %d" % step)
        assert_eq(repo.load_snapshot().snapshot, replay_repo.load_snapshot().snapshot)
        for event in result.events:
            if event.type == "CLEARED": clears += 1
            if event.type == "SUPPLIED": supplies += 1
    assert_gt(clears, 0)
    assert_gt(supplies, 0)

func test_counter_boundary_rejects_entire_candidate_without_commit():
    var state: Dictionary = session.snapshot()
    state.score = Session.MAX_COUNTER
    state.best = Session.MAX_COUNTER
    state.queue = ["single_v0", "single_v0", "single_v0"]
    install(state)
    var before: Dictionary = session.snapshot()
    var result: Dictionary = session.dispatch(place(0, 0, 0))
    assert_eq(result.error, "INVALID_STATE")
    assert_eq(result.events, [])
    assert_eq(session.snapshot(), before)
    assert_eq(repo.load_snapshot().snapshot, before)
