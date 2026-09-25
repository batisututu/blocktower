extends "res://scripts/presentation/puzzle_screen.gd"
## Isolated safe-area adapter for native screenshot/unit fixtures, excluded from APK.
func _safe_vertical() -> Vector2:
    return Vector2(24,24)
