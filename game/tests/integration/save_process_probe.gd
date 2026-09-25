extends SceneTree
## 별도 Godot 프로세스에서 저장/재개하고 지정 커밋 지점에서 강제 종료를 기다린다.
const Repository = preload("res://scripts/persistence/file_save_repository.gd")
const Session = preload("res://scripts/core/game_session.gd")
const Memory = preload("res://scripts/core/memory_save_repository.gd")
const Codec = preload("res://scripts/persistence/save_codec.gd")
const SavedGame = preload("res://scripts/application/saved_game.gd")
var args: PackedStringArray

class PausedRepository:
    extends "res://scripts/persistence/file_save_repository.gd"
    var stop_at := ""
    var marker := ""
    func _checkpoint(stage: String) -> String:
        if stage != stop_at: return ""
        var f := FileAccess.open(marker, FileAccess.WRITE)
        f.store_string(JSON.stringify({"stage": stage, "pid": OS.get_process_id()}))
        f.flush()
        f.close()
        for i in range(600): OS.delay_msec(100)
        return "SAVE_PROBE_TIMEOUT"

func _initialize():
    args = OS.get_cmdline_user_args()
    _run.call_deferred()

func _finish(result: Dictionary, expected_text: String = ""):
    var report := {"ok": result.ok, "pid": OS.get_process_id(), "mode": args[0],
        "error": result.get("error", ""), "recovered": result.get("recovered", false),
        "recovery": result.get("recovery", {}), "expected_clear_text": expected_text}
    if result.ok and result.has("session"):
        report["state_text"] = Codec.new().encode(result.session.snapshot()).text
    var f := FileAccess.open(args[2], FileAccess.WRITE)
    if f == null:
        quit(2)
        return
    f.store_string(JSON.stringify(report, "\t"))
    f.close()
    print("SAVE_PROCESS_PROBE ", args[0], " ok=", result.ok)
    quit(0)

func _run():
    if args.size() < 3:
        quit(2)
        return
    var mode := args[0]
    var path := args[1]
    if mode == "app_boot":
        var app = load("res://scenes/app.tscn").instantiate()
        app.save_directory = path
        root.add_child(app)
        await process_frame
        var result: Dictionary = app.startup_result
        _finish(result)
        return
    var opened: Dictionary = Repository.open(path)
    if not opened.ok:
        _finish(opened)
        return
    var repository = opened.repository
    if mode == "init":
        var made: Dictionary = SavedGame.new().boot(path, "process-test", "-9223372036854775808")
        if not made.ok:
            _finish(made)
            return
        var state: Dictionary = made.session.snapshot()
        state.occupancy.fill(0)
        state.cell_style.fill(0)
        for i in range(8):
            state.occupancy[3 * 8 + i] = 1
            state.occupancy[i * 8 + 5] = 1
            state.cell_style[3 * 8 + i] = 1
            state.cell_style[i * 8 + 5] = 1
        state.growth.total_floors = 9
        state.queue = ["single_v0", "single_v0", "single_v0"]
        state.revision = 1
        state.last_event_id = 1
        var committed: Dictionary = repository.commit(state, 0)
        if not committed.ok:
            _finish(committed)
            return
        var control_repo = Memory.new()
        control_repo.commit(state, -1)
        var control = Session.resume(control_repo).session
        var cleared: Dictionary = control.dispatch({"type": "CLEAR", "session_id": state.session_id, "event_id": 2})
        _finish(Session.resume(repository), Codec.new().encode(cleared.snapshot).text)
        return
    if mode == "init_terrace_v2":
        var made: Dictionary = SavedGame.new().boot(path, "terrace-process-test", "424242")
        if not made.ok:
            _finish(made)
            return
        var state: Dictionary = made.session.snapshot()
        state.growth.total_floors = 120
        state.growth.brick_lines = 30
        state.growth.segment_styles = {"1":"brick"}
        state.growth.segment_parts = {"1":["brick_arch_window","brick_terrace"]}
        state.growth.representative_segment = 1
        state.revision = 1
        state.last_event_id = 1
        var committed: Dictionary = repository.commit(state, 0)
        if not committed.ok:
            _finish(committed)
            return
        _finish(Session.resume(repository))
        return
    if mode == "init_cornice_v2":
        var made: Dictionary = SavedGame.new().boot(path, "cornice-process-test", "424242")
        if not made.ok:
            _finish(made)
            return
        var state: Dictionary = made.session.snapshot()
        state.growth.total_floors = 200
        state.growth.brick_lines = 60
        state.growth.segment_styles = {"20":"brick"}
        state.growth.segment_parts = {"20":["brick_arch_window","brick_cornice","brick_terrace"]}
        state.growth.representative_segment = 20
        state.revision = 1
        state.last_event_id = 1
        var committed: Dictionary = repository.commit(state, 0)
        if not committed.ok:
            _finish(committed)
            return
        _finish(Session.resume(repository))
        return
    if mode == "init_landmark_v2":
        var made: Dictionary = SavedGame.new().boot(path, "landmark-process-test", "424242")
        if not made.ok:
            _finish(made)
            return
        var state: Dictionary = made.session.snapshot()
        state.growth.total_floors = 300
        state.growth.brick_lines = 100
        state.growth.segment_styles = {"1":"brick"}
        state.growth.segment_parts = {"1":["brick_arch_window","brick_cornice","brick_landmark","brick_terrace"]}
        state.growth.representative_segment = 1
        state.revision = 1
        state.last_event_id = 1
        var committed: Dictionary = repository.commit(state, 0)
        if not committed.ok:
            _finish(committed)
            return
        _finish(Session.resume(repository))
        return
    if mode == "init_copy_v2":
        var made: Dictionary = SavedGame.new().boot(path,"copy-process-test","424242")
        if not made.ok:
            _finish(made)
            return
        var state: Dictionary = made.session.snapshot()
        state.growth.total_floors = 300
        state.growth.brick_lines = 100
        state.growth.representative_segment = 3
        state.growth.segment_styles = {"1":"brick","2":"metal","3":"crystal"}
        state.growth.segment_parts = {"1":["brick_arch_window","brick_cornice","brick_landmark","brick_terrace"],"2":["brick_arch_window"]}
        state.revision = 1
        state.last_event_id = 1
        var committed: Dictionary = repository.commit(state,0)
        if not committed.ok:
            _finish(committed)
            return
        _finish(Session.resume(repository))
        return
    if mode == "clear" and args.size() >= 5:
        var paused = PausedRepository.new()
        var error := paused.configure(path)
        if not error.is_empty():
            _finish({"ok": false, "error": error})
            return
        paused.stop_at = args[3]
        paused.marker = args[4]
        repository = paused
    var resumed: Dictionary = Session.resume(repository)
    if not resumed.ok:
        _finish(resumed)
        return
    if mode == "toggle_auto":
        var state: Dictionary = resumed.session.snapshot()
        var action := {"type":"SET_AUTO","session_id":state.session_id,"event_id":state.last_event_id+1,
            "enabled":not state.auto_clear,"confirmed":false}
        var result: Dictionary = resumed.session.dispatch(action)
        if not result.ok:
            _finish(result)
            return
        _finish(resumed)
        return
    if mode == "copy_appearance":
        var state: Dictionary = resumed.session.snapshot()
        var action := {"type":"COPY_SEGMENT_APPEARANCE","session_id":state.session_id,
            "event_id":state.last_event_id+1,"source":1,"target":2,"confirmed":true}
        var result: Dictionary = resumed.session.dispatch(action)
        if not result.ok:
            _finish(result)
            return
        _finish(resumed)
        return
    if mode in ["clear", "duplicate"]:
        var state: Dictionary = resumed.session.snapshot()
        var event_id: int = 2 if mode == "duplicate" else state.last_event_id + 1
        var result: Dictionary = resumed.session.dispatch({"type": "CLEAR", "session_id": state.session_id, "event_id": event_id})
        if not result.ok:
            _finish(result)
            return
    _finish(resumed)
