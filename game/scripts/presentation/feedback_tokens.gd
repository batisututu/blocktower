extends RefCounted
## 첫 체험용 시간 가안. 입력 해제와 장식 지속 시간을 분리한다.
const BUTTON := 0.12
const SNAP := 0.14
const CLEAR_SETTLE := 0.28
const CLEAR_VISUAL := 0.42
const SNAP_ACQUIRE := 0.70
const SNAP_RELEASE := 0.90
const TOAST_HOLD := 1.8
const TOAST_FADE := 0.15
const TOUCH_MOUSE_SUPPRESSION_MS := 250

static func touch_lift_cells(piece_height: int) -> float:
    return maxf(1.4, float(piece_height) * 0.5 + 0.65)
