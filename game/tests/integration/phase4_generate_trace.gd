extends SceneTree
## 서버 도전 시드에서 실제 규칙 행동만 만들어 대표 구간 화면을 검증한다.
const Session = preload("res://scripts/core/game_session.gd")
const Repository = preload("res://scripts/core/memory_save_repository.gd")
const LowSingleConfig = preload("res://data/piece_generator_low_single.tres")
const ClassicConfig = preload("res://data/piece_generator_default.tres")

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 2:
        quit(2)
        return
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    if typeof(source) != TYPE_DICTIONARY:
        quit(2)
        return
    var profile: String = str(source.get("supply_profile","classic"))
    if profile not in ["classic","reduced_single"]:
        quit(2)
        return
    var best := {"floors":-1,"actions":[]}
    for attempt in range(24):
        var result := _generate(source.session_id,source.seed,profile,attempt)
        if result.floors > best.floors: best = result
        if best.floors >= 10: break
    var file := FileAccess.open(args[1],FileAccess.WRITE)
    if file == null:
        quit(3)
        return
    file.store_string(JSON.stringify(best))
    file.close()
    quit(0)

func _generate(session_id: String, seed: String, profile: String, attempt: int) -> Dictionary:
    var config: Resource = LowSingleConfig if profile == "reduced_single" else ClassicConfig
    var started := Session.start(Repository.new(),session_id,seed,config)
    if not started.ok: return {"floors":-1,"actions":[]}
    var session: RefCounted = started.session
    var actions: Array = []
    var first := {"type":"SET_AUTO","session_id":session_id,"event_id":1,"enabled":true,"confirmed":true}
    if not session.dispatch(first).ok: return {"floors":-1,"actions":[]}
    actions.append(_wire(first))
    var rng := RandomNumberGenerator.new()
    rng.seed = 123456+attempt*997
    for step in range(500):
        var state: Dictionary = session.snapshot()
        if state.growth.total_floors >= 10 or session.view().status == "GAME_OVER": break
        var best_move := {}
        var best_value := -INF
        for slot in range(3):
            var piece: Dictionary = session.piece_for_slot(slot)
            if piece.is_empty(): continue
            for y in range(9-piece.height):
                for x in range(9-piece.width):
                    var preview: Dictionary = session.preview_placement(slot,x,y)
                    if not preview.ok: continue
                    var value := _value(state.occupancy,preview.cells,attempt,rng)
                    if value > best_value:
                        best_value = value
                        best_move = {"type":"PLACE","session_id":session_id,"event_id":state.last_event_id+1,
                            "batch_id":state.batch_id,"slot":slot,"x":x,"y":y}
        if best_move.is_empty(): break
        if not session.dispatch(best_move).ok: break
        actions.append(_wire(best_move))
    return {"floors":session.snapshot().growth.total_floors,"actions":actions}

func _value(occupancy: PackedByteArray, cells: Array, attempt: int, rng: RandomNumberGenerator) -> float:
    var board := occupancy.duplicate()
    for index in cells: board[index] = 1
    var rows: Array[int] = []
    var columns: Array[int] = []
    for line in range(8):
        var row := true
        var column := true
        for offset in range(8):
            row = row and board[line*8+offset] == 1
            column = column and board[offset*8+line] == 1
        if row: rows.append(line)
        if column: columns.append(line)
    for line in rows:
        for x in range(8): board[line*8+x] = 0
    for line in columns:
        for y in range(8): board[y*8+line] = 0
    var potential := 0.0
    var occupied := 0
    for line in range(8):
        var row_count := 0
        var column_count := 0
        for offset in range(8):
            row_count += board[line*8+offset]
            column_count += board[offset*8+line]
        potential += pow(float(row_count),3.0)+pow(float(column_count),3.0)
        occupied += row_count
    var clear_weight := 900.0 + float(attempt%6)*80.0
    var compact_weight := 0.12 + float(attempt/6)*0.08
    return float(rows.size()+columns.size())*clear_weight + potential*compact_weight - float(occupied)*0.8 + rng.randf_range(-3.0,3.0)

func _wire(action: Dictionary) -> Dictionary:
    var result := action.duplicate(true)
    for field in ["event_id","batch_id","slot","x","y"]:
        if result.has(field): result[field] = str(result[field])
    return result
