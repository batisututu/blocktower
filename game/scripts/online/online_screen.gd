extends Control
## 개인 퍼즐과 분리된 주간 도전·검증 순위 화면.
signal start_requested(challenge: Dictionary)
signal submit_requested
signal exit_requested
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const BACKGROUND = preload("res://assets/visual_bible/backgrounds/architecture_b.png")
const Art = preload("res://scripts/presentation/visual_bible_theme.gd")
const Preview = preload("res://scripts/online/representative_preview.gd")
var art := Art.new()
var client: Node
var challenge_active := false
var _server_input: LineEdit
var _status: Label
var _entries: VBoxContainer
var _detail: VBoxContainer
var _busy := false

func _ready() -> void:
    set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    var background := TextureRect.new()
    background.texture = BACKGROUND
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_SCALE
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    add_child(background)
    var tint := ColorRect.new()
    tint.color = Color(0.08,0.05,0.03,0.91)
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    add_child(tint)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    add_child(scroll)
    var panel := MarginContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_constant_override("margin_left",20)
    panel.add_theme_constant_override("margin_right",20)
    panel.add_theme_constant_override("margin_top",30)
    panel.add_theme_constant_override("margin_bottom",30)
    scroll.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",12)
    panel.add_child(column)
    _label(column,"주간 건축 기록",24)
    _label(column,"서버가 재생 확인한 이번 주 증축만 공개됩니다. 개인 탑은 그대로 유지됩니다.",14)
    var server_row := HBoxContainer.new()
    column.add_child(server_row)
    _server_input = LineEdit.new()
    _server_input.text = client.server_url
    _server_input.editable = not challenge_active
    _server_input.custom_minimum_size = Vector2(180,48)
    _server_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var field_style := StyleBoxFlat.new()
    field_style.bg_color = Color("342b22")
    field_style.border_color = Color("b69562")
    field_style.set_border_width_all(1)
    field_style.set_corner_radius_all(8)
    for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: field_style.set_content_margin(side,8)
    _server_input.add_theme_stylebox_override("normal",field_style)
    _server_input.add_theme_color_override("font_color",Color("f3e4ca"))
    _server_input.add_theme_font_override("font",FONT)
    _server_input.add_theme_font_size_override("font_size",14)
    server_row.add_child(_server_input)
    _button(server_row,"서버 적용",_set_server)
    var actions := HBoxContainer.new()
    column.add_child(actions)
    _button(actions,"순위 새로고침",_refresh)
    _button(actions,"도전 시작/이어가기",_start)
    if challenge_active: _button(column,"현재 도전 제출",func(): submit_requested.emit())
    _button(column,"개인 탑으로" if challenge_active else "닫기",func(): exit_requested.emit())
    _status = _label(column,"서버 연결 전",14)
    _entries = VBoxContainer.new()
    _entries.add_theme_constant_override("separation",6)
    column.add_child(_entries)
    _detail = VBoxContainer.new()
    column.add_child(_detail)
    _refresh.call_deferred()

func _label(parent: Node, value: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_override("font",FONT)
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",Color("f3e4ca"))
    parent.add_child(label)
    return label

func _button(parent: Node, value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0,48)
    button.add_theme_font_override("font",FONT)
    button.add_theme_font_size_override("font_size",14)
    button.add_theme_color_override("font_color",Color("f3e4ca"))
    button.add_theme_color_override("font_hover_color",Color("ffdc91"))
    button.add_theme_stylebox_override("normal",art.panel("button"))
    button.add_theme_stylebox_override("hover",art.panel("button","hover"))
    button.add_theme_stylebox_override("pressed",art.panel("button","pressed"))
    button.add_theme_stylebox_override("focus",art.panel("button","hover"))
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func show_status(value: String) -> void:
    if is_instance_valid(_status): _status.text = value

func error_text(code: String) -> String:
    var messages := {
        "NETWORK_UNAVAILABLE":"서버에 연결할 수 없습니다.",
        "UNAUTHORIZED":"임시 계정 정보가 유효하지 않습니다.",
        "ACCOUNT_REQUIRED":"임시 계정을 먼저 만들어 주세요.",
        "CHALLENGE_CLOSED":"이번 주 도전의 제출 시간이 끝났습니다.",
        "CHALLENGE_NOT_FOUND":"도전 정보를 찾을 수 없습니다.",
        "TRACE_NOT_EXTENSION":"이미 제출된 기록과 달라 자동으로 합칠 수 없습니다.",
        "VERIFIER_UNAVAILABLE":"서버 검증을 잠시 사용할 수 없습니다.",
        "TRACE_TOO_LARGE":"도전 기록이 너무 커서 제출할 수 없습니다."
    }
    return messages.get(code,"요청을 완료하지 못했습니다. ("+code+")")

func _set_server() -> void:
    if challenge_active:
        show_status("도전 중에는 서버를 바꿀 수 없습니다.")
        return
    var result: Dictionary = client.configure_server(_server_input.text)
    show_status("서버 주소를 적용했습니다." if result.ok else "HTTPS 주소 또는 로컬 개발 서버만 사용할 수 있습니다.")

func _start() -> void:
    if _busy: return
    _busy = true
    show_status("계정과 주간 시드를 확인하는 중…")
    var account: Dictionary = await client.ensure_account()
    if not is_inside_tree(): return
    if not account.ok:
        show_status(error_text(str(account.error)))
        _busy = false
        return
    var challenge: Dictionary = await client.call_api(HTTPClient.METHOD_POST,"/v1/challenges/current",{},true)
    if not is_inside_tree(): return
    _busy = false
    if not challenge.ok:
        show_status(error_text(str(challenge.error)))
        return
    start_requested.emit(challenge)

func _refresh() -> void:
    if _busy: return
    _busy = true
    show_status("검증된 기록을 불러오는 중…")
    var result: Dictionary = await client.call_api(HTTPClient.METHOD_GET,"/v1/leaderboard/current")
    if not is_inside_tree(): return
    _busy = false
    if not result.ok:
        show_status(error_text(str(result.error)))
        return
    for child in _entries.get_children(): child.queue_free()
    for child in _detail.get_children(): child.queue_free()
    show_status("%s 시작 주간 · 검증된 기록 %d개" % [str(result.week),result.entries.size()])
    if result.entries.is_empty():
        _label(_entries,"아직 제출된 도전이 없습니다.",14)
    for entry in result.entries:
        var title := "%d위  %s  ·  %d층" % [entry.rank,entry.alias,entry.floor_count]
        var current: Dictionary = entry.duplicate(true)
        _button(_entries,title,_show_entry.bind(current))

func _show_entry(entry: Dictionary) -> void:
    for child in _detail.get_children(): child.queue_free()
    _label(_detail,"%s의 대표 구간" % entry.alias,18)
    var tower: Dictionary = entry.tower
    if int(tower.representative_segment) <= 0:
        _label(_detail,"완성된 대표 구간이 아직 없습니다.",14)
        return
    _label(_detail,"%d번 구간 · %s · 누적 %d층" % [tower.representative_segment,tower.material,tower.total_floors],14)
    if not tower.parts.is_empty(): _label(_detail,"장식: "+", ".join(PackedStringArray(tower.parts)),12)
    var preview := Preview.new()
    preview.custom_minimum_size = Vector2(0,350)
    _detail.add_child(preview)
    preview.resized.connect(preview.queue_redraw)
    preview.show_tower(tower)
