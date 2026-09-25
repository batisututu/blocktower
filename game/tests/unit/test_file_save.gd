extends "res://addons/gut/test.gd"
const Repository = preload("res://scripts/persistence/file_save_repository.gd")
const Codec = preload("res://scripts/persistence/save_codec.gd")
const Session = preload("res://scripts/core/game_session.gd")
const Memory = preload("res://scripts/core/memory_save_repository.gd")
const SavedGame = preload("res://scripts/application/saved_game.gd")
var directory: String
var repo
var session
var codec

class FaultRepository:
    extends "res://scripts/persistence/file_save_repository.gd"
    var fail_at := ""
    func _checkpoint(stage: String) -> String:
        return "SAVE_INJECTED_FAILURE" if stage == fail_at else ""

class OwnerRepository:
    extends "res://scripts/persistence/file_save_repository.gd"
    var status := -1
    func _owner_status(_pid: int) -> int:
        return status

func test_legacy_owner_checks_fail_closed_and_preserve_committed_bytes():
    var legacy := directory.path_join(".writer_2147483647.lock")
    assert_eq(DirAccess.make_dir_absolute(legacy), OK)
    var bytes := FileAccess.get_file_as_bytes(directory.path_join("slot_a.json"))
    for status in [1, -1]:
        var contender := OwnerRepository.new()
        assert_eq(contender.configure(directory), "")
        contender.status = status
        var result: Dictionary = contender.load_snapshot()
        assert_false(result.ok)
        assert_eq(result.error, "SAVE_BUSY" if status == 1 else "SAVE_PROCESS_CHECK_FAILED")
        assert_true(DirAccess.dir_exists_absolute(legacy))
        assert_eq(FileAccess.get_file_as_bytes(directory.path_join("slot_a.json")), bytes)
    var recovered := OwnerRepository.new()
    recovered.configure(directory)
    recovered.status = 0
    assert_true(recovered.load_snapshot().ok)
    assert_false(DirAccess.dir_exists_absolute(legacy))

func test_legacy_nonempty_and_invalid_claims_are_never_deleted():
    var legacy := directory.path_join(".writer_2147483647.lock")
    assert_eq(DirAccess.make_dir_absolute(legacy), OK)
    write_raw(".writer_2147483647.lock/keep", "keep")
    var contender := OwnerRepository.new()
    contender.configure(directory)
    contender.status = 0
    assert_eq(contender.load_snapshot().error, "SAVE_LOCK_FAILED")
    assert_eq(FileAccess.get_file_as_string(legacy.path_join("keep")), "keep")
    DirAccess.remove_absolute(legacy.path_join("keep"))
    DirAccess.remove_absolute(legacy)
    var malformed := directory.path_join(".writer_unknown.lock")
    assert_eq(DirAccess.make_dir_absolute(malformed), OK)
    assert_eq(contender.load_snapshot().error, "SAVE_LOCK_INVALID")
    assert_true(DirAccess.dir_exists_absolute(malformed))

func before_each():
    directory = ProjectSettings.globalize_path("user://w3_tests/" + str(Time.get_ticks_usec()) + "_" + str(randi()))
    var opened: Dictionary = Repository.open(directory)
    assert_true(opened.ok)
    repo = opened.repository
    codec = Codec.new()
    var created: Dictionary = Session.start(repo, "테스트-profile", "-9223372036854775808")
    assert_true(created.ok, str(created))
    if created.ok: session = created.session

func toggle() -> Dictionary:
    var s: Dictionary = session.snapshot()
    return {"type": "SET_AUTO", "session_id": s.session_id, "event_id": s.last_event_id + 1,
        "enabled": not s.auto_clear, "confirmed": true}

func write_raw(name: String, data: String):
    var f := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
    assert_not_null(f)
    f.store_string(data)
    f.close()

func rewrite_payload(text: String, edit: Callable) -> String:
    var envelope: Dictionary = JSON.parse_string(text)
    var payload: Dictionary = JSON.parse_string(envelope.payload)
    edit.call(payload)
    envelope.payload = JSON.stringify(payload, "", true)
    envelope.checksum = envelope.payload.sha256_text()
    return JSON.stringify(envelope, "", true)

func test_disk_roundtrip_new_repository_and_growth_integer_precision():
    var state: Dictionary = session.snapshot()
    state.score = Session.MAX_COUNTER
    state.best = Session.MAX_COUNTER
    state.growth.total_floors = Session.MAX_COUNTER
    state.growth.representative_segment = 1
    state.checkpoint.rng_state = "9223372036854775807"
    var encoded: Dictionary = codec.encode(state)
    assert_true(encoded.ok)
    var decoded: Dictionary = codec.decode(encoded.text.to_utf8_buffer())
    assert_true(decoded.ok)
    assert_eq(decoded.snapshot, state)
    assert_true(encoded.text.contains("9000000000000000"))
    assert_eq(Repository.open(directory).repository.load_snapshot().snapshot, session.snapshot())
    assert_eq(Session.resume(Repository.open(directory).repository).session.snapshot(), session.snapshot())
    write_raw("slot_a.json", encoded.text)
    assert_eq(Session.resume(Repository.open(directory).repository).session.snapshot(), state)

func test_v1_file_migration_is_read_only_until_next_successful_v2_action():
    var bytes := FileAccess.get_file_as_bytes("res://tests/fixtures/save_v1_cleared_cross.json")
    assert_gt(bytes.size(), 0)
    write_raw("slot_a.json", bytes.get_string_from_utf8())
    write_raw("slot_b.json", bytes.get_string_from_utf8())
    var original_a := FileAccess.get_file_as_bytes(directory.path_join("slot_a.json"))
    var original_b := FileAccess.get_file_as_bytes(directory.path_join("slot_b.json"))
    var resumed := Session.resume(repo)
    assert_true(resumed.ok, str(resumed))
    assert_eq(resumed.session.snapshot().schema_version, "bt_session_v2")
    assert_eq(resumed.session.snapshot().growth.segment_parts, {})
    assert_eq(FileAccess.get_file_as_bytes(directory.path_join("slot_a.json")), original_a)
    assert_eq(FileAccess.get_file_as_bytes(directory.path_join("slot_b.json")), original_b)
    assert_eq(resumed.session.snapshot().revision, 2)
    session = resumed.session
    assert_true(session.dispatch(toggle()).ok)
    var stored: Dictionary = repo.load_snapshot()
    assert_true(stored.ok)
    assert_eq(stored.snapshot.schema_version, "bt_session_v2")
    assert_eq(stored.snapshot.growth.segment_parts, {})
    var decoded: Dictionary = codec.decode(FileAccess.get_file_as_bytes(directory.path_join(stored.selected_file)))
    assert_true(decoded.ok)
    assert_eq(decoded.snapshot, session.snapshot())

func test_corrupt_latest_recovers_previous_preserves_bytes_before_next_commit():
    var previous: Dictionary = session.snapshot()
    assert_true(session.dispatch(toggle()).ok)
    write_raw("slot_b.json", "{truncated")
    var damaged_hash := FileAccess.get_sha256(directory.path_join("slot_b.json"))
    var opened: Dictionary = Session.resume(Repository.open(directory).repository)
    assert_true(opened.ok)
    assert_true(opened.recovered)
    assert_eq(opened.session.snapshot(), previous)
    session = opened.session
    assert_true(session.dispatch(toggle()).ok)
    assert_eq(FileAccess.get_sha256(directory.path_join("preserved/slot_b.json." + damaged_hash + ".bad")), damaged_hash)
    assert_false(Repository.open(directory).repository.load_snapshot().recovered)

func test_both_corrupt_and_future_versions_never_start_over():
    write_raw("slot_a.json", "bad")
    write_raw("slot_b.json", "also bad")
    assert_eq(repo.load_snapshot().error, "SAVE_CORRUPT")
    assert_eq(Session.start(repo, "new", "1").error, "SAVE_CORRUPT")
    assert_eq(FileAccess.get_file_as_string(directory.path_join("slot_a.json")), "bad")

func test_future_schema_and_policy_mismatch_block_fallback_to_supported_slot():
    assert_true(session.dispatch(toggle()).ok)
    var original := FileAccess.get_file_as_string(directory.path_join("slot_b.json"))
    var future := rewrite_payload(original, func(p): p.schema_version = "bt_session_v3")
    write_raw("slot_b.json", future)
    assert_eq(repo.load_snapshot().error, "UNSUPPORTED_VERSION")
    assert_eq(FileAccess.get_file_as_string(directory.path_join("slot_b.json")), future)
    var mismatch := rewrite_payload(original, func(p): p.checkpoint.config_hash = "different")
    write_raw("slot_b.json", mismatch)
    assert_eq(repo.load_snapshot().error, "CHECKPOINT_VERSION_MISMATCH")

func test_codec_rejects_bad_hash_types_utf8_and_noncanonical_ints():
    var encoded: Dictionary = codec.encode(session.snapshot())
    for bad in ["", "{", encoded.text + " "]:
        assert_false(codec.decode(bad.to_utf8_buffer()).ok)
    var bytes := PackedByteArray([255, 254, 0])
    assert_eq(codec.decode(bytes).error, "CORRUPT_UTF8")
    for value in [1, 1.0, "01", "-0", "9223372036854775808", "1.5", "-1"]:
        var text := rewrite_payload(encoded.text, func(p): p.score = value)
        assert_false(codec.decode(text.to_utf8_buffer()).ok, str(value))
    var invalid := rewrite_payload(encoded.text, func(p): p.occupancy = "ff".repeat(64))
    assert_eq(codec.decode(invalid.to_utf8_buffer()).error, "CORRUPT_STATE")
    var envelope: Dictionary = JSON.parse_string(encoded.text)
    envelope.checksum = "0".repeat(64)
    assert_eq(codec.decode(JSON.stringify(envelope, "", true).to_utf8_buffer()).error, "CORRUPT_CHECKSUM")

func test_inactive_generation_removal_and_publication_faults_recover_whole_state():
    assert_true(session.dispatch(toggle()).ok)
    var original: Dictionary = session.snapshot()
    var original_a := FileAccess.get_file_as_string(directory.path_join("slot_a.json"))
    var original_b := FileAccess.get_file_as_string(directory.path_join("slot_b.json"))
    for stage in ["before_write", "after_write", "after_verify", "after_preserve", "after_remove_target", "after_publish"]:
        write_raw("slot_a.json", original_a)
        write_raw("slot_b.json", original_b)
        var faulty = FaultRepository.new()
        assert_eq(faulty.configure(directory), "")
        session = Session.resume(faulty).session
        faulty.fail_at = stage
        var request := toggle()
        var result: Dictionary = session.dispatch(request)
        assert_false(result.ok, stage)
        assert_eq(result.events, [])
        assert_eq(session.snapshot(), original)
        var loaded: Dictionary = Repository.open(directory).repository.load_snapshot()
        assert_true(loaded.ok, stage)
        assert_eq(loaded.snapshot.revision, original.revision + (1 if stage == "after_publish" else 0), stage)
        if stage == "after_publish":
            assert_eq(result.error, "COMMIT_UNCERTAIN")
            assert_eq(session.dispatch(request).error, "RECOVERY_REQUIRED")
            assert_eq(Session.resume(Repository.open(directory).repository).session.dispatch(request).error, "ALREADY_APPLIED")

func test_real_write_path_failure_does_not_commit_or_publish():
    assert_eq(DirAccess.make_dir_absolute(directory.path_join("pending.json")), OK)
    var before: Dictionary = session.snapshot()
    var failed: Dictionary = session.dispatch(toggle())
    assert_eq(failed.error, "SAVE_WRITE_FAILED")
    assert_eq(failed.events, [])
    assert_eq(session.snapshot(), before)
    assert_eq(repo.load_snapshot().snapshot, before)

func test_recovery_preservation_failure_keeps_damaged_original():
    assert_true(session.dispatch(toggle()).ok)
    write_raw("slot_b.json", "damaged")
    write_raw("preserved", "blocked directory")
    session = Session.resume(Repository.open(directory).repository).session
    var result: Dictionary = session.dispatch(toggle())
    assert_eq(result.error, "SAVE_PRESERVE_FAILED")
    assert_eq(FileAccess.get_file_as_string(directory.path_join("slot_b.json")), "damaged")
    assert_eq(session.snapshot().revision, 0)

func test_stale_session_and_unobserved_recovery_cannot_overwrite():
    var other = Session.resume(Repository.open(directory).repository).session
    assert_true(other.dispatch(toggle()).ok)
    assert_eq(session.dispatch(toggle()).error, "SAVE_CONFLICT")
    session = Session.resume(Repository.open(directory).repository).session
    write_raw("slot_a.json", "old damaged backup")
    assert_eq(session.dispatch(toggle()).error, "RECOVERY_REQUIRED")
    assert_eq(session.snapshot().revision, 1)

func test_same_process_claim_busy_and_pending_only_initial_save():
    var claim := directory.path_join(".writer_%d.lock" % OS.get_process_id())
    assert_eq(DirAccess.make_dir_absolute(claim), OK)
    assert_eq(repo.load_snapshot().error, "SAVE_BUSY")
    assert_eq(DirAccess.remove_absolute(claim), OK)
    var fresh := directory.path_join("pending_only")
    DirAccess.make_dir_absolute(fresh)
    var f := FileAccess.open(fresh.path_join("pending.json"), FileAccess.WRITE)
    f.store_string("interrupted initial write")
    f.close()
    var loaded: Dictionary = Repository.open(fresh).repository.load_snapshot()
    assert_true(loaded.ok)
    assert_false(loaded.found)
    assert_true(loaded.ignored_pending)

func test_boot_uses_existing_identity_and_retains_recovery_notice():
    var result: Dictionary = SavedGame.new().boot(directory, "ignored-new-id", "99")
    assert_true(result.ok)
    assert_false(result.created)
    assert_eq(result.session.snapshot(), session.snapshot())
    assert_true(session.dispatch(toggle()).ok)
    write_raw("slot_b.json", "bad")
    result = SavedGame.new().boot(directory)
    assert_true(result.ok)
    assert_true(result.recovered)
    assert_eq(result.session.snapshot().revision, 0)

func test_divergent_same_revision_and_session_identity_fail_closed():
    var encoded: Dictionary = codec.encode(session.snapshot())
    write_raw("slot_b.json", rewrite_payload(encoded.text, func(p): p.auto_clear = true))
    assert_eq(repo.load_snapshot().error, "SAVE_DIVERGED")

    write_raw("slot_b.json", rewrite_payload(encoded.text, func(p): p.session_id = "different"))
    assert_eq(repo.load_snapshot().error, "SAVE_DIVERGED")

func test_saved_v1_fixtures_roundtrip_and_replay_clear_exactly():
    var pending := FileAccess.get_file_as_bytes("res://tests/fixtures/save_v1_pending_cross.json")
    var cleared := FileAccess.get_file_as_bytes("res://tests/fixtures/save_v1_cleared_cross.json")
    var before: Dictionary = codec.decode(pending)
    var after: Dictionary = codec.decode(cleared)
    assert_true(before.ok)
    assert_true(after.ok)
    assert_eq(before.snapshot.schema_version,"bt_session_v2")
    assert_eq(before.snapshot.growth.segment_parts,{})
    var migrated_roundtrip: Dictionary = codec.decode(codec.encode(before.snapshot).text.to_utf8_buffer())
    assert_true(migrated_roundtrip.ok)
    assert_eq(migrated_roundtrip.snapshot,before.snapshot)
    var memory = Memory.new()
    memory.commit(before.snapshot, -1)
    var fixture_session = Session.resume(memory).session
    assert_true(fixture_session.dispatch({"type": "CLEAR", "session_id": before.snapshot.session_id, "event_id": 2}).ok)
    assert_eq(fixture_session.snapshot(), after.snapshot)
