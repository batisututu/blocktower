extends Node
## 제한된 효과음 풀. 게임 공급 RNG는 사용하지 않는다.
const SOUND_NAMES := ["pick", "snap", "reject", "clear", "lock", "over", "button", "air", "chime"]
const PLAYER_LIMIT := 6
const HAPTIC_GAP_MS := 45
var preferences: RefCounted
var players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var last_haptic := 0
var cue_sequence := 0
var played: Array[String] = []
var application_active := true

func _ready() -> void:
    for name in SOUND_NAMES:
        var path := "res://assets/audio/%s.wav" % name
        if name in ["snap","clear","button","air","chime"]: path = "res://assets/audio/gamefeel/%s.wav" % name
        if ResourceLoader.exists(path): sounds[name] = load(path)
    for i in range(PLAYER_LIMIT):
        var player := AudioStreamPlayer.new()
        add_child(player)
        players.append(player)

func cue(name: String, strength: int = 1) -> void:
    if preferences == null or not application_active: return
    cue_sequence += 1
    # 로그는 테스트/진단용 최근 항목만 보존한다.
    played.append(name)
    if played.size() > 32: played.pop_front()
    if name == "clear":
        _play("snap",strength,-8.0)
        _play("clear",strength)
        _play("air",strength)
        if strength >= 2: _play("chime",strength)
    else:
        _play(name,strength)
    _haptic(name,strength)

static func haptic_profile(name: String, strength: int = 1) -> Dictionary:
    match name:
        "pick": return {"duration": 9, "amplitude": 0.18}
        "snap": return {"duration": 15, "amplitude": 0.32}
        "clear": return {"duration": 20 + 6 * mini(maxi(strength, 1), 4), "amplitude": minf(0.65, 0.35 + 0.08 * mini(maxi(strength, 1), 4))}
        "lock": return {"duration": 30, "amplitude": 0.55}
    return {}

func _haptic(name: String, strength: int) -> void:
    if not preferences.values.haptics or OS.get_name() not in ["Android", "iOS"]: return
    var profile := haptic_profile(name,strength)
    if profile.is_empty(): return
    var now := Time.get_ticks_msec()
    if now - last_haptic < HAPTIC_GAP_MS: return
    Input.vibrate_handheld(profile.duration,profile.amplitude)
    last_haptic = now

static func sound_priority(name: String) -> int:
    if name in ["clear", "lock", "over"]: return 3
    if name in ["snap", "chime"]: return 2
    if name in ["pick", "air"]: return 1
    return 0

func _play(name: String, strength: int, trim_db: float = 0.0) -> void:
    if not preferences.values.muted and preferences.values.volume > 0 and sounds.has(name):
        var target: AudioStreamPlayer
        for player in players:
            if not player.playing:
                target = player
                break
        if target == null:
            var priority := sound_priority(name)
            for player in players:
                if int(player.get_meta("priority",0)) < priority:
                    target = player
                    break
        if target != null:
            target.stop()
            target.stream = sounds[name]
            target.set_meta("priority",sound_priority(name))
            target.pitch_scale = 1.0 + 0.045 * mini(strength - 1, 3) if name in ["clear", "chime"] else 1.0 + 0.02 * (cue_sequence % 3 - 1)
            var layer_db: float = float({"pick": -5.0, "snap": -3.0, "button": -7.0, "air": -10.0, "chime": -6.0}.get(name,0.0))
            target.volume_db = linear_to_db(preferences.values.volume / 100.0) + layer_db + trim_db
            target.play()

func stop_all() -> void:
    for player in players: player.stop()
