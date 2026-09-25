extends "res://addons/gut/test.gd"
## 새 개인 저장의 공급 변경과 이전 저장의 재현성을 함께 확인한다.
const SavedGame = preload("res://scripts/application/saved_game.gd")
const Session = preload("res://scripts/core/game_session.gd")
const Repository = preload("res://scripts/persistence/file_save_repository.gd")
const Generator = preload("res://scripts/core/generation/piece_generator.gd")
const LowSingle = preload("res://data/piece_generator_low_single.tres")
const Classic = preload("res://data/piece_generator_default.tres")
var _root := ""

func before_each() -> void:
    _root = ProjectSettings.globalize_path("user://supply_profile_test_"+Crypto.new().generate_random_bytes(8).hex_encode())

func after_each() -> void:
    for name in ["slot_a.json","slot_b.json","pending.json"]:
        var path := _root.path_join(name)
        if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
    if DirAccess.dir_exists_absolute(_root): DirAccess.remove_absolute(_root)

func test_new_personal_save_uses_lower_single_profile_after_restart() -> void:
    var created: Dictionary = SavedGame.new().boot(_root,"new-profile","20260925")
    assert_true(created.ok)
    if not created.ok: return
    assert_true(created.created)
    assert_eq(created.supply_profile,"reduced_single")
    var expected: String = Generator.create(LowSingle).generator.config_snapshot().config_hash
    assert_eq(created.session.snapshot().checkpoint.config_hash,expected)
    var resumed: Dictionary = SavedGame.new().boot(_root)
    assert_true(resumed.ok)
    if resumed.ok:
        assert_false(resumed.created)
        assert_eq(resumed.supply_profile,"reduced_single")
        assert_eq(resumed.session.snapshot(),created.session.snapshot())

func test_existing_classic_save_keeps_its_original_profile() -> void:
    var opened: Dictionary = Repository.open(_root,Classic)
    assert_true(opened.ok)
    if not opened.ok: return
    var started: Dictionary = Session.start(opened.repository,"classic-profile","20260925",Classic)
    assert_true(started.ok)
    if not started.ok: return
    var previous: Dictionary = started.session.snapshot()
    var resumed: Dictionary = SavedGame.new().boot(_root)
    assert_true(resumed.ok)
    if resumed.ok:
        assert_eq(resumed.supply_profile,"classic")
        assert_eq(resumed.session.snapshot(),previous)
