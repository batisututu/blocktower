extends RefCounted
## 정수·바이트의 명시적 인코딩과 완전한 세션 검증을 함께 수행한다.
const Session = preload("res://scripts/core/game_session.gd")
const Generator = preload("res://scripts/core/generation/piece_generator.gd")
const FORMAT := "bt_save_envelope_v1"
const MAX_BYTES := 2097152
const COUNTERS := ["revision", "last_event_id", "run_id", "batch_id", "streak", "best_streak", "score", "best"]
const GROWTH_COUNTERS := ["total_floors", "brick_lines", "metal_lines", "crystal_lines", "representative_segment"]
const LEGACY_GROWTH_KEYS := ["total_floors", "brick_lines", "metal_lines", "crystal_lines", "representative_segment", "segment_styles"]
const HEX := "0123456789abcdef"
var _config: Variant

func _init(config: Variant = null):
    _config = config.duplicate(true) if config is Resource else config

static func failure(code: String) -> Dictionary:
    return {"ok": false, "error": code}

static func _exact(value: Variant, keys: Array) -> bool:
    return typeof(value) == TYPE_DICTIONARY and value.size() == keys.size() and keys.all(func(k): return value.has(k))

static func _hex(value: Variant, length: int) -> bool:
    if typeof(value) != TYPE_STRING or value.length() != length: return false
    for c in value:
        if c not in HEX: return false
    return true

static func valid_utf8(bytes: PackedByteArray) -> bool:
    var i := 0
    while i < bytes.size():
        var lead: int = bytes[i]
        if lead < 128:
            i += 1
            continue
        var count := 0
        if lead >= 194 and lead <= 223: count = 1
        elif lead >= 224 and lead <= 239: count = 2
        elif lead >= 240 and lead <= 244: count = 3
        else: return false
        if i + count >= bytes.size(): return false
        for offset in range(1, count + 1):
            if bytes[i + offset] < 128 or bytes[i + offset] > 191: return false
        if lead == 224 and bytes[i + 1] < 160: return false
        if lead == 237 and bytes[i + 1] > 159: return false
        if lead == 240 and bytes[i + 1] < 144: return false
        if lead == 244 and bytes[i + 1] > 143: return false
        i += count + 1
    return true

func _wire(state: Dictionary) -> Dictionary:
    var wire := state.duplicate(true)
    if wire.schema_version == "bt_session_v1":
        wire.growth.erase("segment_parts")
    for key in COUNTERS: wire[key] = str(state[key])
    for key in GROWTH_COUNTERS: wire.growth[key] = str(state.growth[key])
    wire.occupancy = state.occupancy.hex_encode()
    wire.cell_style = state.cell_style.hex_encode()
    return wire

func encode(state: Variant) -> Dictionary:
    var valid := Session.validate_snapshot(state, _config)
    if not valid.ok: return valid
    var payload := JSON.stringify(_wire(state), "", true)
    var envelope := {"format": FORMAT, "payload": payload, "checksum": payload.sha256_text()}
    var text := JSON.stringify(envelope, "", true)
    if text.to_utf8_buffer().size() > MAX_BYTES: return failure("SAVE_TOO_LARGE")
    return {"ok": true, "text": text, "checksum": envelope.checksum}

func decode(bytes: PackedByteArray) -> Dictionary:
    if bytes.size() > MAX_BYTES: return failure("SAVE_TOO_LARGE")
    if not valid_utf8(bytes): return failure("CORRUPT_UTF8")
    var text := bytes.get_string_from_utf8()
    var json := JSON.new()
    if json.parse(text) != OK: return failure("CORRUPT_JSON")
    var envelope: Variant = json.data
    if typeof(envelope) == TYPE_DICTIONARY and envelope.has("format") and envelope.format != FORMAT:
        return failure("UNSUPPORTED_FORMAT")
    if not _exact(envelope, ["format", "payload", "checksum"]): return failure("CORRUPT_ENVELOPE")
    if typeof(envelope.payload) != TYPE_STRING or not _hex(envelope.checksum, 64): return failure("CORRUPT_ENVELOPE")
    if envelope.payload.sha256_text() != envelope.checksum: return failure("CORRUPT_CHECKSUM")
    if JSON.stringify(envelope, "", true) != text: return failure("CORRUPT_CANONICAL")
    if json.parse(envelope.payload) != OK: return failure("CORRUPT_PAYLOAD")
    var state: Variant = json.data
    if not _exact(state, Session.STATE_KEYS): return failure("CORRUPT_STATE")
    var legacy: bool = state.schema_version == "bt_session_v1"
    if not legacy and state.schema_version != "bt_session_v2": return failure("UNSUPPORTED_VERSION")
    if state.rule_version != "bt_rules_v1": return failure("UNSUPPORTED_VERSION")
    if not _exact(state.growth, LEGACY_GROWTH_KEYS if legacy else Session.GROWTH_KEYS): return failure("CORRUPT_STATE")
    for key in COUNTERS:
        var parsed := Generator.parse_int64(state[key])
        if not parsed.ok: return failure("CORRUPT_COUNTER")
        state[key] = parsed.value
    for key in GROWTH_COUNTERS:
        var parsed := Generator.parse_int64(state.growth[key])
        if not parsed.ok: return failure("CORRUPT_COUNTER")
        state.growth[key] = parsed.value
    for key in ["occupancy", "cell_style"]:
        if not _hex(state[key], 128): return failure("CORRUPT_CELLS")
        var buffer := PackedByteArray()
        for i in range(64): buffer.append(HEX.find(state[key][i * 2]) * 16 + HEX.find(state[key][i * 2 + 1]))
        state[key] = buffer
    if JSON.stringify(_wire(state), "", true) != envelope.payload: return failure("CORRUPT_CANONICAL")
    if legacy:
        state.schema_version = "bt_session_v2"
        state.growth.segment_parts = {}
    var valid := Session.validate_snapshot(state, _config)
    if not valid.ok:
        if valid.error in ["CHECKPOINT_VERSION_MISMATCH", "UNSUPPORTED_VERSION"]: return valid
        return failure("CORRUPT_STATE")
    return {"ok": true, "snapshot": state, "checksum": envelope.checksum}
