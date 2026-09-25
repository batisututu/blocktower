extends "res://addons/gut/test.gd"
# docs/examples/check_piece_supply.gd 의 109개 기초 검사를 game 대상에서 GUT로 실행한다.
# 검사 개수가 109와 다르면 이식 누락 또는 원본 변경이므로 실패로 본다.
const Checks = preload("res://tests/support/piece_supply_checks.gd")
const EXPECTED_CHECK_COUNT := 109

func test_ported_baseline_checks_pass_on_game_target():
	var result: Dictionary = Checks.new().run()
	var failures: Array = result["failures"]
	assert_eq(int(result["checks"]), EXPECTED_CHECK_COUNT,
		"all ported baseline checks executed")
	assert_true(failures.is_empty(), "no failed baseline check: " + str(failures))
	# Engine.get_version_info()["string"]는 "4.7.2-stable (official)" 형식이며
	# --version 출력("4.7.2.stable.official.…")과 다르다. 엔진 고정은 tools/test.ps1이 담당하고
	# 여기서는 주 버전만 확인한다.
	var info := Engine.get_version_info()
	assert_eq([int(info["major"]), int(info["minor"]), int(info["patch"]), String(info["status"])],
		[4, 7, 2, "stable"], "executed on Godot 4.7.2 stable: " + str(result["engine"]))
	assert_eq(int(result["sample_pieces"]), 30000, "diagnostic sample size preserved")
