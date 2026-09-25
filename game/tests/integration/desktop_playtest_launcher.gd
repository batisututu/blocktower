extends SceneTree
## W6 데스크톱 첫 플레이 실행기와 격리 저장 경로 스모크 검사.
const SavedGame = preload("res://scripts/application/saved_game.gd")
const AppRoot = preload("res://scripts/application/app_root.gd")
const Generator = preload("res://scripts/core/generation/piece_generator.gd")

func _initialize() -> void:
	var parsed := _parse_options(OS.get_cmdline_user_args())
	if not parsed.ok:
		print("DESKTOP_PLAYTEST_FAIL ", parsed.error)
		quit(2)
		return
	_run.call_deferred(parsed.options)

func _parse_options(args: PackedStringArray) -> Dictionary:
	var options := {"auto": false, "smoke": false, "probe": false}
	var index := 0
	while index < args.size():
		var key: String = args[index]
		if key in ["--seed", "--save-dir", "--build-id", "--probe-root"]:
			if index+1 >= args.size(): return {"ok": false, "error": "MISSING_VALUE_"+key}
			options[key.trim_prefix("--").replace("-", "_")] = args[index+1]
			index += 2
		elif key == "--auto":
			options.auto = true
			index += 1
		elif key == "--smoke":
			options.smoke = true
			index += 1
		elif key == "--probe":
			options.probe = true
			index += 1
		else:
			return {"ok": false, "error": "UNKNOWN_ARGUMENT_"+key}
	if not options.has("seed") or not options.has("build_id"):
		return {"ok": false, "error": "SEED_AND_BUILD_ID_REQUIRED"}
	if options.probe:
		if not options.has("probe_root") or options.has("save_dir") or options.auto or options.smoke:
			return {"ok": false, "error": "INVALID_PROBE_ARGUMENTS"}
	else:
		if not options.has("save_dir") or options.has("probe_root"):
			return {"ok": false, "error": "SAVE_DIRECTORY_REQUIRED"}
	return {"ok": true, "options": options}

func _run(options: Dictionary) -> void:
	if OS.get_name() != "Windows":
		_fail("WINDOWS_ONLY")
		return
	var seed_check: Dictionary = Generator.parse_int64(str(options.seed))
	if not seed_check.ok:
		_fail("INVALID_INT64_SEED")
		return
	if options.probe:
		await _run_probe(options)
		return
	await _run_launch(options)

func _run_launch(options: Dictionary) -> void:
	var save_path := _normalize_save_path(str(options.save_dir))
	if save_path.is_empty():
		_fail("SAVE_PATH_MUST_BE_ISOLATED_ABSOLUTE_PATH")
		return
	if _path_exists(save_path):
		_fail("SAVE_PATH_ALREADY_EXISTS_REFUSED")
		return
	var booted: Dictionary = SavedGame.new().boot(save_path, "", str(options.seed))
	if not booted.ok or not booted.get("created", false):
		_fail("INITIAL_SAVE_FAILED_"+str(booted.get("error", "SAVE_REUSED")))
		return
	var session = booted.session
	if options.auto:
		var auto_result := _set_auto(session)
		if not auto_result.ok:
			_fail("AUTO_SETUP_FAILED_"+str(auto_result.error))
			return
	var initial: Dictionary = session.snapshot()
	var metadata := _metadata(initial, save_path, str(options.build_id))
	if not _write_metadata(save_path, metadata):
		_fail("METADATA_WRITE_FAILED")
		return
	print("DESKTOP_PLAYTEST_METADATA ", JSON.stringify(metadata))
	var app = _attach_app(save_path)
	await process_frame
	await process_frame
	if not _app_is_wired(app, initial):
		_fail("APP_ROOT_SMOKE_FAILED")
		app.queue_free()
		return
	if options.smoke:
		print("DESKTOP_PLAYTEST_SMOKE PASS")
		app.queue_free()
		await process_frame
		quit(0)
		return
	print("DESKTOP_PLAYTEST_UI_READY")

func _run_probe(options: Dictionary) -> void:
	var probe_root := _normalize_save_path(str(options.probe_root))
	if probe_root.is_empty():
		_fail("PROBE_PATH_MUST_BE_ISOLATED_ABSOLUTE_PATH")
		return
	if _path_exists(probe_root):
		_fail("PROBE_PATH_ALREADY_EXISTS_REFUSED")
		return
	if DirAccess.make_dir_recursive_absolute(probe_root) != OK:
		_fail("PROBE_DIRECTORY_CREATE_FAILED")
		return
	var manual_path := probe_root.path_join("manual")
	var auto_path := probe_root.path_join("auto")
	var manual_boot: Dictionary = SavedGame.new().boot(manual_path, "", str(options.seed))
	if not manual_boot.ok or not manual_boot.get("created", false):
		_fail("MANUAL_BOOT_FAILED_"+str(manual_boot.get("error", "SAVE_REUSED")))
		return
	var auto_boot: Dictionary = SavedGame.new().boot(auto_path, "", str(options.seed))
	if not auto_boot.ok or not auto_boot.get("created", false):
		_fail("AUTO_BOOT_FAILED_"+str(auto_boot.get("error", "SAVE_REUSED")))
		return
	var manual_initial: Dictionary = manual_boot.session.snapshot()
	var auto_initial: Dictionary = auto_boot.session.snapshot()
	if manual_initial.queue != auto_initial.queue or manual_initial.checkpoint != auto_initial.checkpoint:
		_fail("IDENTICAL_SEED_INITIAL_SUPPLY_MISMATCH")
		return
	if not _write_metadata(manual_path, _metadata(manual_initial, manual_path, str(options.build_id))):
		_fail("MANUAL_METADATA_WRITE_FAILED")
		return
	if not _write_metadata(auto_path, _metadata(auto_initial, auto_path, str(options.build_id))):
		_fail("AUTO_METADATA_WRITE_FAILED")
		return
	var auto_toggle: Dictionary = _set_auto(auto_boot.session)
	if not auto_toggle.ok:
		_fail("AUTO_CONDITION_SETUP_FAILED_"+str(auto_toggle.error))
		return
	var manual_reload: Dictionary = SavedGame.new().boot(manual_path, "", str(options.seed))
	var auto_reload: Dictionary = SavedGame.new().boot(auto_path, "", str(options.seed))
	if not manual_reload.ok or not auto_reload.ok:
		_fail("ISOLATED_SAVE_REOPEN_FAILED")
		return
	var manual_state: Dictionary = manual_reload.session.snapshot()
	var auto_state: Dictionary = auto_reload.session.snapshot()
	if manual_state.auto_clear or not auto_state.auto_clear or manual_state.revision != 0 or auto_state.revision != 1:
		_fail("SAVE_STATE_CROSSED_CONDITIONS")
		return
	if manual_state.queue != auto_state.queue or manual_state.checkpoint != auto_state.checkpoint:
		_fail("MODE_SETUP_CHANGED_INITIAL_SUPPLY")
		return
	var app = _attach_app(manual_path)
	await process_frame
	await process_frame
	if not _app_is_wired(app, manual_state):
		_fail("PROBE_APP_ROOT_WIRING_FAILED")
		app.queue_free()
		return
	app.queue_free()
	await process_frame
	print("DESKTOP_PLAYTEST_PROBE PASS identical_seed_initial_queue_and_checkpoint=true isolated_manual_auto_saves=true app_root_wired=true")
	quit(0)

func _normalize_save_path(path: String) -> String:
	if not path.is_absolute_path() or path.begins_with("user://") or path.begins_with("res://"):
		return ""
	var normalized := path.simplify_path().trim_suffix("/").trim_suffix("\\")
	var default_path := ProjectSettings.globalize_path("user://save_v1").simplify_path().replace("\\", "/").trim_suffix("/")
	var lower_path := normalized.replace("\\", "/").to_lower()
	var lower_default := default_path.to_lower()
	if lower_path == lower_default or lower_path.begins_with(lower_default+"/"):
		return ""
	return normalized

func _path_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path)

func _set_auto(session) -> Dictionary:
	var snapshot: Dictionary = session.snapshot()
	return session.dispatch({"type": "SET_AUTO", "session_id": snapshot.session_id,
		"event_id": snapshot.last_event_id+1, "enabled": true, "confirmed": false})

func _metadata(snapshot: Dictionary, save_path: String, build_id: String) -> Dictionary:
	var checkpoint: Dictionary = snapshot.checkpoint
	return {
		"seed": snapshot.checkpoint.rng_seed,
		"rule_version": snapshot.rule_version,
		"engine_version": checkpoint.engine_version,
		"catalog_version": checkpoint.catalog_version,
		"supply_policy_version": checkpoint.supply_policy_version,
		"definition_hash": checkpoint.definition_hash,
		"config_hash": checkpoint.config_hash,
		"save_path": save_path,
		"build_id": build_id
	}

func _write_metadata(save_path: String, metadata: Dictionary) -> bool:
	var file := FileAccess.open(save_path.path_join("playtest_metadata.json"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(metadata, "\t")+"\n")
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok

func _attach_app(save_path: String):
	var app := AppRoot.new()
	app.save_directory = save_path
	root.add_child(app)
	return app

func _app_is_wired(app, expected: Dictionary) -> bool:
	if not is_instance_valid(app) or app.game_session == null or app.screen == null or not app.startup_result.ok:
		return false
	if not app.screen.is_inside_tree() or not app.screen.is_visible_in_tree(): return false
	var actual: Dictionary = app.game_session.snapshot()
	return actual.queue == expected.queue and actual.checkpoint == expected.checkpoint and actual.auto_clear == expected.auto_clear

func _fail(reason: String) -> void:
	print("DESKTOP_PLAYTEST_FAIL ", reason)
	quit(1)
