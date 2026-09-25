extends RefCounted
## 입력 소유권과 커밋 경계를 화면 효과에서 분리한다.
signal committed(result: Dictionary, before: Dictionary)
signal rejected(error: String)
const Tokens = preload("res://scripts/presentation/feedback_tokens.gd")
var assisted_anchor := Vector2i(-99,-99)
var session: RefCounted
var phase := "idle"
var pointer := -2
var slot := -1
var origin := Vector2i(-99, -99)
var drag_revision := -1
var drag_batch := -1
var modal_revision := -1
var last_presented := -1
var last_identity := ""
var application_active := true

func set_application_active(active: bool) -> void:
    application_active = active
    if not active: cancel()

func attach(value: RefCounted) -> void:
    session = value
    phase = "idle"
    pointer = -2
    slot = -1
    var state: Dictionary = session.snapshot()
    last_presented = state.revision
    last_identity = state.session_id

static func cell_origin(position: Vector2, board: Rect2, grab: Vector2, lift: Vector2) -> Vector2i:
    var p := position - grab + lift - board.position
    var step := board.size.x / 8.0
    return Vector2i(floori(p.x / step), floori(p.y / step))

func begin_drag(id: int, selected: int) -> bool:
    if not application_active or phase != "idle" or session == null: return false
    if session.view().status == "GAME_OVER" or session.piece_for_slot(selected).is_empty(): return false
    var state: Dictionary = session.snapshot()
    pointer = id
    slot = selected
    drag_revision = state.revision
    drag_batch = state.batch_id
    assisted_anchor = Vector2i(-99,-99)
    phase = "dragging"
    return true

func assisted_origin(position: Vector2, board: Rect2, grab: Vector2, lift: Vector2) -> Vector2i:
    var strict := cell_origin(position,board,grab,lift)
    if phase != "dragging" or not board.has_point(position+lift):
        assisted_anchor = Vector2i(-99,-99)
        return strict
    var q := (position-grab+lift-board.position)/(board.size.x/8.0)
    if q.distance_to(Vector2(assisted_anchor)) <= Tokens.SNAP_RELEASE and session.preview_placement(slot,assisted_anchor.x,assisted_anchor.y).ok:
        return assisted_anchor
    var rounded := Vector2i(roundi(q.x),roundi(q.y))
    var best := strict
    var distance := Tokens.SNAP_ACQUIRE
    assisted_anchor = Vector2i(-99,-99)
    for y in range(rounded.y-1,rounded.y+2):
        for x in range(rounded.x-1,rounded.x+2):
            var candidate := Vector2i(x,y)
            var d := q.distance_to(Vector2(candidate))
            if d <= distance and session.preview_placement(slot,x,y).ok:
                best = candidate
                distance = d
                assisted_anchor = candidate
    return best

func move_drag(id: int, at: Vector2i) -> Dictionary:
    if phase != "dragging" or id != pointer: return {"ok": false, "error": "NOT_OWNER"}
    origin = at
    return session.preview_placement(slot, at.x, at.y)

func release_drag(id: int, inside_board: bool = true) -> Dictionary:
    if phase != "dragging" or id != pointer: return {"ok": false, "error": "NOT_OWNER"}
    var selected := slot
    var at := origin
    cancel()
    if not inside_board: return {"ok": false, "error": "CANCELLED"}
    if session.snapshot().revision != drag_revision: return _reject("STALE_INPUT")
    return submit("PLACE", {"batch_id": drag_batch, "slot": selected, "x": at.x, "y": at.y})

func cancel() -> void:
    pointer = -2
    slot = -1
    if phase in ["dragging", "settling", "modal"]: phase = "idle"

func open_modal() -> void:
    if not application_active: return
    cancel()
    if phase == "recovery" or phase == "committing": return
    modal_revision = session.snapshot().revision
    phase = "modal"

func submit_modal(kind: String, extra: Dictionary) -> Dictionary:
    if not application_active: return {"ok": false, "error": "SUSPENDED", "events": []}
    if phase != "modal": return _reject("STALE_INPUT")
    phase = "idle"
    if session.snapshot().revision != modal_revision: return _reject("STALE_INPUT")
    return submit(kind, extra)

func submit(kind: String, extra: Dictionary = {}) -> Dictionary:
    if not application_active: return {"ok": false, "error": "SUSPENDED", "events": []}
    if phase != "idle": return _reject("RECOVERY_REQUIRED" if phase == "recovery" else "BUSY")
    var before: Dictionary = session.snapshot()
    var action := {"type": kind, "session_id": before.session_id, "event_id": before.last_event_id + 1}
    action.merge(extra)
    phase = "committing"
    var result: Dictionary = session.dispatch(action)
    if not result.ok:
        phase = "recovery" if result.error in ["COMMIT_UNCERTAIN", "SAVE_CONFLICT", "RECOVERY_REQUIRED"] else "idle"
        return _reject(result.error)
    phase = "settling"
    if result.snapshot.session_id != last_identity or result.snapshot.revision > last_presented:
        last_presented = result.snapshot.revision
        last_identity = result.snapshot.session_id
        committed.emit(result, before)
    return result

func settle() -> void:
    if phase == "settling": phase = "idle"

func _reject(error: String) -> Dictionary:
    rejected.emit(error)
    return {"ok": false, "error": error, "events": []}
