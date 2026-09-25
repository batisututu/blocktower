extends SceneTree
## 같은 스크립트를 본 프로젝트와 고정 v1 프로젝트에서 실행해 상태/공급 호환성을 비교한다.
const Session = preload("res://scripts/core/game_session.gd")
const Memory = preload("res://scripts/core/memory_save_repository.gd")
const Classic = preload("res://data/piece_generator_default.tres")
const LowSingle = preload("res://data/piece_generator_low_single.tres")

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 1:
        quit(2)
        return
    var cases: Array = []
    for profile in ["classic", "reduced_single"]:
        for seed_text in ["1", "20260921", "20260926"]:
            for auto_mode in [false, true]:
                var result := _trace(profile, seed_text, auto_mode)
                if not result.ok:
                    push_error(str(result))
                    quit(1)
                    return
                cases.append(result)
    var view_benchmark := _benchmark_view()
    var dispatch_benchmark := _benchmark_dispatch()
    if not dispatch_benchmark.has("median_usec"):
        push_error(str(dispatch_benchmark))
        quit(1)
        return
    var report := {"engine": Engine.get_version_info().string, "cases": cases,
        "repeated_view": view_benchmark, "dispatch": dispatch_benchmark}
    var file := FileAccess.open(args[0], FileAccess.WRITE)
    if file == null:
        quit(3)
        return
    file.store_string(JSON.stringify(report, "  ", true))
    file.close()
    print("OPTIMIZATION_PROBE ", args[0])
    quit()

func _trace(profile: String, seed_text: String, auto_mode: bool) -> Dictionary:
    var config: Resource = Classic if profile == "classic" else LowSingle
    var made := Session.start(Memory.new(), "optimization-parity", seed_text, config)
    if not made.ok: return made
    var session: RefCounted = made.session
    var history := PackedStringArray()
    for step in range(120):
        var state: Dictionary = session.snapshot()
        var view: Dictionary = session.view()
        history.append(JSON.stringify({"state": state, "view": view}, "", true))
        var action := {"session_id": state.session_id, "event_id": state.last_event_id + 1}
        if step == 0 and auto_mode:
            action.merge({"type": "SET_AUTO", "enabled": true, "confirmed": true})
        elif view.clear_lines > 0:
            action["type"] = "CLEAR"
        elif view.status == "GAME_OVER":
            break
        else:
            if view.witness.is_empty(): return {"ok": false, "error": "MISSING_WITNESS"}
            action.merge({"type": "PLACE", "batch_id": state.batch_id,
                "slot": view.witness.slot, "x": view.witness.x, "y": view.witness.y})
        var committed: Dictionary = session.dispatch(action)
        if not committed.ok: return committed
        history.append(JSON.stringify(committed, "", true))
    var final_state: Dictionary = session.snapshot()
    return {"ok": true, "profile": profile, "seed": seed_text, "auto": auto_mode,
        "revision": final_state.revision, "floors": final_state.growth.total_floors,
        "history_sha256": "\n".join(history).sha256_text()}

func _benchmark_view() -> Dictionary:
    var session: RefCounted = Session.start(Memory.new(), "view-bench", "20260926").session
    for i in range(100): session.view()
    var samples: Array[int] = []
    for sample in range(7):
        var start := Time.get_ticks_usec()
        for i in range(2000): session.view()
        samples.append(Time.get_ticks_usec() - start)
    samples.sort()
    return {"calls_per_sample": 2000, "samples": 7, "median_usec": samples[3]}

func _benchmark_dispatch() -> Dictionary:
    var samples: Array[int] = []
    for sample in range(7):
        var session: RefCounted = Session.start(Memory.new(), "dispatch-bench", "20260926").session
        var start := Time.get_ticks_usec()
        for i in range(200):
            var result: Dictionary = session.dispatch({"type": "SET_AUTO", "session_id": "dispatch-bench",
                "event_id": i + 1, "enabled": i % 2 == 0, "confirmed": true})
            if not result.ok:
                return result
        samples.append(Time.get_ticks_usec() - start)
    samples.sort()
    return {"actions_per_sample": 200, "samples": 7, "median_usec": samples[3]}
