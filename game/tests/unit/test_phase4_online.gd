extends "res://addons/gut/test.gd"
## 주간 도전 기록은 개인 저장과 분리하고 행동으로만 다시 만든다.
const Session = preload("res://scripts/core/game_session.gd")
const ChallengeRepository = preload("res://scripts/online/challenge_repository.gd")
var _challenge: Dictionary
var _root := ""

func before_each() -> void:
    var id := Crypto.new().generate_random_bytes(16).hex_encode()
    _challenge = {"challenge_id":id,"session_id":id,"seed":"20260925"}
    _root = ProjectSettings.globalize_path("user://phase4_challenges/"+id)

func after_each() -> void:
    for name in ["trace_a.json","trace_b.json"]:
        var path := _root.path_join(name)
        if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
    if DirAccess.dir_exists_absolute(_root): DirAccess.remove_absolute(_root)

func _session() -> Dictionary:
    var opened: Dictionary = ChallengeRepository.open(_challenge)
    assert_true(opened.ok)
    if not opened.ok: return opened
    var started: Dictionary = Session.start(opened.repository,_challenge.session_id,_challenge.seed,opened.repository.supply_config())
    assert_true(started.ok)
    if not started.ok: return started
    return {"ok":true,"repository":opened.repository,"session":started.session}

func test_committed_action_survives_new_repository_and_replay() -> void:
    var made := _session()
    if not made.ok: return
    var action := {"type":"SET_AUTO","session_id":_challenge.session_id,"event_id":1,"enabled":true,"confirmed":true}
    var result: Dictionary = made.session.dispatch(action)
    assert_true(result.ok)
    assert_eq(made.repository.actions().size(),1)
    assert_eq(made.repository.actions()[0].event_id,"1")
    var reopened: Dictionary = ChallengeRepository.open(_challenge)
    assert_true(reopened.ok)
    if not reopened.ok: return
    var resumed: Dictionary = Session.resume(reopened.repository)
    assert_true(resumed.ok)
    if resumed.ok:
        assert_eq(resumed.session.snapshot(),result.snapshot)
        assert_true(resumed.session.snapshot().auto_clear)

func test_new_run_is_rejected_without_a_trace_write() -> void:
    var made := _session()
    if not made.ok: return
    var before: Dictionary = made.session.snapshot()
    var action := {"type":"NEW_RUN","session_id":_challenge.session_id,"event_id":1,"seed_text":"1","confirmed":true}
    var result: Dictionary = made.session.dispatch(action)
    assert_false(result.ok)
    assert_eq(result.error,"ONLINE_NEW_RUN_DISABLED")
    assert_eq(made.session.snapshot(),before)
    assert_true(made.repository.actions().is_empty())

func test_damaged_latest_generation_recovers_previous_trace() -> void:
    var made := _session()
    if not made.ok: return
    var action := {"type":"SET_AUTO","session_id":_challenge.session_id,"event_id":1,"enabled":true,"confirmed":true}
    assert_true(made.session.dispatch(action).ok)
    var file := FileAccess.open(_root.path_join("trace_b.json"),FileAccess.WRITE)
    assert_not_null(file)
    if file == null: return
    file.store_string("damaged")
    file.close()
    var reopened: Dictionary = ChallengeRepository.open(_challenge)
    assert_true(reopened.ok)
    if not reopened.ok: return
    var loaded: Dictionary = reopened.repository.load_snapshot()
    assert_true(loaded.ok)
    if loaded.ok:
        assert_true(loaded.recovered)
        assert_eq(loaded.snapshot.revision,0)
        assert_false(loaded.snapshot.auto_clear)

func test_reduced_single_challenge_reopens_with_issued_profile() -> void:
    _challenge["supply_profile"] = "reduced_single"
    var made := _session()
    if not made.ok: return
    var expected_hash: String = made.session.snapshot().checkpoint.config_hash
    var action := {"type":"SET_AUTO","session_id":_challenge.session_id,"event_id":1,"enabled":true,"confirmed":true}
    assert_true(made.session.dispatch(action).ok)
    var reopened: Dictionary = ChallengeRepository.open(_challenge)
    assert_true(reopened.ok)
    if not reopened.ok: return
    var resumed: Dictionary = Session.resume(reopened.repository,reopened.repository.supply_config())
    assert_true(resumed.ok)
    if resumed.ok:
        assert_eq(resumed.session.snapshot().checkpoint.config_hash,expected_hash)
        assert_eq(resumed.session.snapshot(),made.session.snapshot())
