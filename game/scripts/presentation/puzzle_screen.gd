extends Control
## 실제 저장 세션을 그리는 화면. 연출은 확정 상태 위의 일시적인 표현이다.
signal reload_requested
signal online_requested
const Controller = preload("res://scripts/presentation/presentation_controller.gd")
const Preferences = preload("res://scripts/presentation/presentation_preferences.gd")
const Feedback = preload("res://scripts/presentation/feedback_player.gd")
const Tokens = preload("res://scripts/presentation/feedback_tokens.gd")
const Art = preload("res://scripts/presentation/visual_bible_theme.gd")
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const BACKGROUND = preload("res://assets/visual_bible/backgrounds/architecture_b.png")
const Effects = preload("res://scripts/presentation/board_effects.gd")
const Session = preload("res://scripts/core/game_session.gd")
const TOWER_PATH := "res://assets/visual_bible/tower/"
const INK := Color("f8ead2")
const MUTED := Color("d8c5a6")
const GOLD := Color("efc06b")
const READY := Color("d2e8b1")
const INVALID := Color("f4a591")
const PRIMARY_TEXT := Color("21180f")
const DISABLED_TEXT := Color("b8ac98")
const NOTE_TEXT := Color("e9d6b4")
const ICON_GOLD := Color(0.98,0.89,0.66)
const LANE_LINE := Color(0.914,0.839,0.706,0.12)
# 건축 배경판을 낮춰 보드와 HUD에 시선을 모은다. 배경판 자체는 수정하지 않는다.
const BACKGROUND_DIM := Color(0.078,0.051,0.027,0.38)
const PILL_FILL := Color(0.094,0.067,0.039,0.66)
const QUIET_FILL := Color(0.094,0.067,0.039,0.62)
const CHIP_FILL := Color(0.129,0.094,0.059,0.78)
const MODAL_SCRIM := Color(0.08,0.06,0.04,0.82)
const DIMMED_PIECE := Color(0.62,0.6,0.56,0.45)
const AUTO_SWITCH_WIDTH := 96.0
const LANE_NOTE_MIN_HEIGHT := 80.0
const LANE_NOTE_SHIFT := 7.0
const GROWTH_BADGE_HOLD := 1.4
const STREAK_MIN := 2
const MAX_EVENT_ANNOUNCEMENTS := 3
const EVENT_NOTICE_HOLD := 0.72
const MAX_EVENT_ANNOUNCEMENT_SECONDS := 3.0
const OVERVIEW_BANDS := 64
var controller := Controller.new()
var art := Art.new()
var tower_art: Dictionary = {}
var tower_geometry: Dictionary = {}
var preferences := Preferences.new()
var feedback: Node
var state: Dictionary = {}
var analysis: Dictionary = {}
var board_rect := Rect2()
var shelf_rect := Rect2()
var tray_rects: Array[Rect2] = []
var screen_id := "puzzle"
var online_mode := false
var controls: Control
var drag_layer: Control
var modal: Control
var modal_content: VBoxContainer
var modal_actions: BoxContainer
var background: TextureRect
var score_label: Label
var best_label: Label
var best_row: HBoxContainer
var streak_chip: PanelContainer
var streak_text: Label
var hint_label: Label
var toast_label: Label
var clear_button: Button
var auto_button: Button
var auto_title: Label
var auto_state: Label
var auto_switch: TextureRect
var tower_button: Button
var chip_name: Label
var chip_remaining: Label
var chip_progress: Control
var growth_badge: Label
var growth_glow := 0.0
var growth_motion: Tween
var tray_notes: Array[Label] = []
var slot_fits: Array[bool] = [true,true,true]
var tray_pieces: Array[Dictionary] = [{},{},{}]
var _tray_session: RefCounted
var _tray_revision := -1
var preview_rows: Array[int] = []
var preview_columns: Array[int] = []
var compact_layout := false
var drag_position := Vector2.ZERO
var grab := Vector2.ZERO
var lift := Vector2.ZERO
var preview: Dictionary = {}
var drag_piece: Dictionary = {}
var touch_active := false
var remnants: Array = []
var remnant_styles: Array = []
var effect_alpha := 0.0
var effect_progress := 0.0
var snap_cells: Array = []
var motion: Tween
var toast_motion: Tween
var settle_left := 0.0
var best_announced := false
var toast_queue: Array[String] = []
var last_event_announcements: Array[String] = []
var last_event_details: Array[String] = []
var last_growth_details: Array[String] = []
var modal_action := ""
var new_run_seed := ""
var last_focus: Control
var background_focus: Array[Control] = []
var selected_segment := 1
var segment_jump_input: LineEdit
var segment_jump_status: Label
var segment_copy_input: LineEdit
var segment_copy_preview: Label
var regular: FontVariation
var strong: FontVariation
var touch_until := 0
var settings_status: Label
var volume_slider: HSlider
var growth_details_button: Button
var effect_rows: Array = []
var effect_columns: Array = []
var tray_cell_size := 18.0
var pick_age := 1.0
var _ui_epoch := 0
var _quiet_style_cache: StyleBoxFlat

func _ready() -> void:
    tower_geometry = JSON.parse_string(FileAccess.get_file_as_string(TOWER_PATH+"geometry.json"))
    for part in ["floor_entry","floor_wide","floor_mid","floor_top","roof_wide","roof_mid","roof_top","cornice","base"]:
        tower_art[part] = load(TOWER_PATH+part+".png")
    for part in ["floor_entry","floor_wide","floor_mid","floor_top"]:
        tower_art["brick_"+part] = load(TOWER_PATH+"brick_"+part+".png")
        tower_art["brick_arch_"+part] = load(TOWER_PATH+"brick_arch_"+part+".png")
        if part in ["floor_entry","floor_wide"]:
            var terrace_suffix: String = part.trim_prefix("floor_")
            tower_art["brick_terrace_"+terrace_suffix] = load(TOWER_PATH+"brick_terrace_floor_"+terrace_suffix+".png")
            tower_art["brick_arch_terrace_"+terrace_suffix] = load(TOWER_PATH+"brick_arch_terrace_floor_"+terrace_suffix+".png")
        tower_art["metal_"+part] = load(TOWER_PATH+"metal_"+part+".png")
        tower_art["crystal_"+part] = load(TOWER_PATH+"crystal_"+part+".png")
    for part in ["brick_cornice","brick_cornice_roof_wide","brick_cornice_roof_mid","brick_cornice_roof_top"]:
        tower_art[part] = load(TOWER_PATH+part+".png")
    for part in ["brick_landmark_floor_mid","brick_arch_landmark_floor_mid"]:
        tower_art[part] = load(TOWER_PATH+part+".png")
    regular = FontVariation.new()
    regular.base_font = FONT
    regular.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
    strong = FontVariation.new()
    strong.base_font = FONT
    strong.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    background = TextureRect.new()
    background.texture = BACKGROUND
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    # 건축 가장자리를 잘라내지 않고 세로 비율에 맞춰 전체 배경판을 늘린다.
    background.stretch_mode = TextureRect.STRETCH_SCALE
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    move_child(background, 0)
    # 배경은 _draw보다 앞에 그리므로 명확한 보드를 별도 CanvasItem에 그린다.
    var canvas := Control.new()
    canvas.name = "BoardCanvas"
    canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.draw.connect(_draw_board.bind(canvas))
    add_child(canvas)
    controls = Control.new()
    controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(controls)
    # 끌고 있는 조각은 안내 알약과 트레이 문구보다 위에 그린다.
    drag_layer = Control.new()
    drag_layer.name = "DragLayer"
    drag_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    drag_layer.draw.connect(_draw_drag.bind(drag_layer))
    add_child(drag_layer)
    feedback = Feedback.new()
    feedback.preferences = preferences
    add_child(feedback)
    controller.committed.connect(_committed)
    controller.rejected.connect(_rejected)
    resized.connect(_layout)

func attach(session: RefCounted, settings_path: String) -> void:
    interrupt()
    preferences = Preferences.new()
    preferences.configure(settings_path)
    feedback.preferences = preferences
    controller.attach(session)
    state = session.snapshot()
    analysis = session.view()
    best_announced = state.score > 0 and state.score == state.best
    _layout()
    if not preferences.warning.is_empty(): _toast(preferences.warning)

static func format_int(value: int) -> String:
    # 정확한 정수를 천 단위 쉼표로만 나눈다. 반올림이나 축약은 하지 않는다.
    var digits := str(absi(value))
    var grouped := ""
    while digits.length() > 3:
        grouped = ","+digits.substr(digits.length()-3)+grouped
        digits = digits.substr(0,digits.length()-3)
    return ("-" if value < 0 else "")+digits+grouped

func _style(fill: Color, border: Color = Color("927653"), radius: int = 8) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 8
    style.content_margin_right = 8
    return style

func _chip_style() -> StyleBoxFlat:
    var style := _style(CHIP_FILL,Color(GOLD,.5),12)
    style.content_margin_left = 9
    style.content_margin_right = 9
    style.content_margin_top = 2
    style.content_margin_bottom = 2
    return style

func _pill_style(gold_edge: bool) -> StyleBoxFlat:
    var style := _style(PILL_FILL,Color(GOLD,.45) if gold_edge else Color.TRANSPARENT,14)
    if not gold_edge: style.set_border_width_all(0)
    return style

func _quiet_style() -> StyleBoxFlat:
    if _quiet_style_cache == null:
        _quiet_style_cache = _style(QUIET_FILL,Color(MUTED,.42),12)
        _quiet_style_cache.content_margin_top = 4
        _quiet_style_cache.content_margin_bottom = 4
    return _quiet_style_cache

func _ring_style(color: Color, glow: float) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.draw_center = false
    style.border_color = color
    style.set_border_width_all(2)
    style.set_corner_radius_all(11)
    style.shadow_color = Color(GOLD,.45*color.a)
    style.shadow_size = int(glow)
    return style

func _sheet_style() -> StyleBox:
    var style := art.panel("panel").duplicate() as StyleBoxTexture
    style.set_content_margin(SIDE_LEFT,16)
    style.set_content_margin(SIDE_RIGHT,16)
    style.set_content_margin(SIDE_TOP,14)
    style.set_content_margin(SIDE_BOTTOM,14)
    return style

func _font_size(base: int) -> int:
    return ceili(base * 1.2) if preferences.values.get("large_text", false) else base

func _text_width(text: String, font_size: int, bold: bool) -> float:
    var font: Font = strong if bold else regular
    var widest := 0.0
    for line in text.split("\n"):
        widest = maxf(widest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
    return widest

func _make_label(text: String, font_size: int, color: Color, bold: bool) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_override("font", strong if bold else regular)
    label.add_theme_font_size_override("font_size", _font_size(font_size))
    label.add_theme_color_override("font_color", color)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _label(text: String, rect: Rect2, font_size: int, color: Color = INK) -> Label:
    var label := _make_label(text,font_size,color,font_size >= 20)
    label.position = rect.position
    label.size = rect.size
    controls.add_child(label)
    return label

func _child_label(parent: Control, font_size: int, color: Color, bold: bool) -> Label:
    var label := _make_label("",font_size,color,bold)
    parent.add_child(label)
    return label

func _wrapped_label(text: String, font_size: int, color: Color, bold: bool) -> Label:
    var label := _make_label(text,font_size,color,bold)
    var actual := label.get_theme_font_size("font_size")
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var font: Font = strong if bold else regular
    # Label은 줄 사이에 line_spacing을 더하므로 측정 높이에도 반영한다.
    var measured := font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,size.x-56,actual).y
    var lines := maxi(1,roundi(measured/maxf(1,font.get_height(actual))))
    label.custom_minimum_size.y = maxf(actual*1.35,measured+label.get_theme_constant("line_spacing")*(lines-1)+2)
    return label

func _button(text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
    var button := Button.new()
    button.text = text
    button.position = rect.position
    button.size = rect.size
    button.add_theme_font_override("font", strong)
    button.add_theme_font_size_override("font_size", _font_size(14))
    button.custom_minimum_size.y = 48
    button.set_meta("primary",primary)
    var material_name := "button" if primary else "panel"
    for style_state in ["normal","hover","pressed","disabled"]:
        button.add_theme_stylebox_override(style_state,art.panel(material_name,style_state))
    button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, READY))
    for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        button.add_theme_color_override(k, PRIMARY_TEXT if primary else INK)
    button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
    var epoch := _ui_epoch
    button.pressed.connect(func():
        if not _ui_callback_allowed(button,epoch) or button.disabled: return
        feedback.cue("button")
        callback.call())
    button.button_down.connect(func(): _button_feedback(button,0.82))
    button.button_up.connect(func(): _button_feedback(button,1.0))
    button.mouse_exited.connect(func(): _button_feedback(button,1.0))
    controls.add_child(button)
    return button

func _icon_button(icon_name: String, rect: Rect2, callback: Callable, accessible: String) -> Button:
    var button := _button("",rect,callback)
    button.icon = art.texture(icon_name)
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.expand_icon = true
    button.add_theme_constant_override("icon_max_width",22)
    button.accessibility_name = accessible
    button.tooltip_text = accessible
    return button

func _rail_button(text: String, icon_name: String, rect: Rect2, callback: Callable) -> Button:
    var button := _button("\n"+text,rect,callback)
    button.add_theme_font_size_override("font_size",_font_size(11))
    var icon := TextureRect.new()
    icon.texture = art.texture("icon_"+icon_name)
    icon.position = Vector2((rect.size.x-24)/2,7)
    icon.size = Vector2(24,24)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(icon)
    return button

func _button_feedback(button: Button, brightness: float) -> void:
    if not controller.application_active or button.disabled or not button.is_visible_in_tree(): return
    if button.has_meta("motion"):
        var previous: Tween = button.get_meta("motion")
        if previous != null: previous.kill()
    button.pivot_offset = button.size/2
    var pressed := brightness < 1.0
    if preferences.values.reduced_motion:
        button.modulate = Color(.88,.88,.88) if pressed else Color.WHITE
        button.scale = Vector2.ONE
        return
    var tween := button.create_tween().set_parallel(true)
    button.set_meta("motion",tween)
    tween.tween_property(button,"scale",Vector2.ONE*(.955 if pressed else 1.0),.065 if pressed else Tokens.BUTTON).set_trans(Tween.TRANS_CUBIC if pressed else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(button,"modulate",Color(.9,.9,.9) if pressed else Color.WHITE,.07)

func _safe_vertical() -> Vector2:
    if OS.get_name() != "Android": return Vector2.ZERO
    var area := DisplayServer.get_display_safe_area()
    var display := DisplayServer.screen_get_size()
    if display.y <= 0 or area.size.y <= 0: return Vector2.ZERO
    var ratio := size.y/float(display.y)
    return Vector2(area.position.y,maxi(0,display.y-area.end.y))*ratio

func _layout() -> void:
    if controls == null or state.is_empty(): return
    _ui_epoch += 1
    interrupt()
    for child in controls.get_children():
        controls.remove_child(child)
        child.queue_free()
    modal = null
    modal_content = null
    modal_actions = null
    segment_jump_input = null
    segment_jump_status = null
    segment_copy_input = null
    segment_copy_preview = null
    background_focus.clear()
    tray_notes.clear()
    var w := size.x
    var h := size.y
    if screen_id == "tower_focus":
        _build_tower_focus()
        _redraw()
        if controller.phase == "recovery": _save_error_dialog()
        return
    if screen_id in ["tower","tower_overview"]:
        var tower_insets := _safe_vertical()
        var tower_top := tower_insets.x
        _label("주간 도전 탑" if online_mode else "Blocktower", Rect2(12,tower_top+8,w-184,48),18,INK)
        growth_details_button = _button("해금 보기",Rect2(w-152,tower_top+8,84,48),_show_growth_details)
        _button("설정", Rect2(w-60,tower_top+8,48,48),_settings)
        if screen_id == "tower": _build_tower()
        else: _build_tower_overview()
        _redraw()
        if controller.phase == "recovery": _save_error_dialog()
        return
    var insets := _safe_vertical()
    var side := w-24
    var usable_h := h-insets.x-insets.y
    # 기본 배치의 최소 높이(보드+344)를 못 채우면 두 줄 상단과 낮은 트레이를 쓴다.
    compact_layout = usable_h < side+344
    var top := insets.x
    var score_height := 80.0
    var tray_height := 120.0
    var dock_height := 56.0
    var hint_gap := 6.0
    var hint_height := 28.0
    var dock_gap := 12.0
    if compact_layout:
        score_height = 48.0
        dock_height = 48.0
        hint_gap = 2.0
        hint_height = 22.0
        dock_gap = 2.0
        # 최소 트레이 48px를 먼저 보장하고 남는 높이는 트레이, 위쪽 여백 순으로 준다.
        var spare := maxf(0,usable_h-(48+score_height+4+side+hint_gap+hint_height+2+48+dock_gap+dock_height))
        var tray_extra := minf(56,spare*.7)
        tray_height = 48+tray_extra
        top += minf(8,(spare-tray_extra)*.5)
    else:
        # 공간이 모자라면 트레이, 점수 영역 순으로 줄이고 남는 공간은 위아래에 나눈다.
        var spare := usable_h-(side+384)
        var tray_cut := clampf(-spare,0,24)
        tray_height -= tray_cut
        spare += tray_cut
        var score_cut := clampf(-spare,0,16)
        score_height -= score_cut
        spare += score_cut
        top += 8+maxf(0,spare)*.35
    var score_y := top+(48 if compact_layout else 52)
    board_rect = Rect2(12,score_y+score_height+(4 if compact_layout else 6),side,side)
    var tray_y := board_rect.end.y+hint_gap+hint_height+(2 if compact_layout else 8)
    shelf_rect = Rect2(12,tray_y,side,tray_height)
    tray_rects.clear()
    for i in range(3): tray_rects.append(Rect2(12+i*side/3.0,tray_y,side/3.0,tray_height))
    var dock_y := tray_y+tray_height+dock_gap
    _build_tower_chip(top)
    _button("도전" if online_mode else "주간",Rect2(w-128,top,60,48),_open_online)
    _icon_button("icon_settings",Rect2(w-60,top,48,48),_settings,"설정")
    _build_score(score_y,score_height)
    # 안내 줄은 보드 바로 아래에서 시작하고, 위쪽 간격은 내용 여백으로 둔다.
    hint_label = _strip_label(Rect2(12,board_rect.end.y,side,hint_gap+hint_height),hint_gap,false)
    toast_label = _strip_label(Rect2(12,board_rect.end.y,side,hint_gap+hint_height),hint_gap,true)
    toast_label.modulate.a = 0
    for i in range(3):
        var lane: Rect2 = tray_rects[i]
        var note := _label("놓을 곳 없음",Rect2(lane.position.x,lane.end.y-24,lane.size.x,18),11,NOTE_TEXT)
        note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        note.hide()
        tray_notes.append(note)
    clear_button = _button("",Rect2(12,dock_y,side-AUTO_SWITCH_WIDTH-8,dock_height),_clear,true)
    clear_button.autowrap_mode = TextServer.AUTOWRAP_OFF
    _build_auto_switch(Rect2(w-12-AUTO_SWITCH_WIDTH,dock_y,AUTO_SWITCH_WIDTH,dock_height))
    _refresh_text()
    _sync_buttons()
    _redraw()
    if controller.phase == "recovery": _save_error_dialog()

func _strip_label(rect: Rect2, gap: float, gold: bool) -> Label:
    var label := _label("",rect,(12 if compact_layout else 14) if gold else (11 if compact_layout else 13),GOLD if gold else INK)
    if gold: label.add_theme_font_override("font",strong)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var inset := StyleBoxEmpty.new()
    inset.content_margin_top = gap
    label.add_theme_stylebox_override("normal",inset)
    if gold:
        label.add_theme_color_override("font_shadow_color",Color("1a140d"))
        label.add_theme_constant_override("shadow_offset_x",1)
        label.add_theme_constant_override("shadow_offset_y",2)
    # 알약 배경은 글자 폭에 맞추고, 부모 글자보다 뒤에 그린다.
    var pill := Panel.new()
    pill.show_behind_parent = true
    pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pill.add_theme_stylebox_override("panel",_pill_style(gold))
    label.add_child(pill)
    return label

func _fit_pill(label: Label) -> void:
    if not is_instance_valid(label) or label.get_child_count() == 0: return
    var pill := label.get_child(0) as Control
    var gap: float = label.get_theme_stylebox("normal").content_margin_top
    var font_size := label.get_theme_font_size("font_size")
    var font: Font = label.get_theme_font("font")
    var width := minf(label.size.x,font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+26)
    pill.position = Vector2((label.size.x-width)/2,gap)
    pill.size = Vector2(width,label.size.y-gap)
    pill.visible = not label.text.is_empty()

func _set_hint(text: String) -> void:
    if not is_instance_valid(hint_label): return
    hint_label.text = text
    var font_size := _font_size(11 if compact_layout else 13)
    while font_size > 9 and regular.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > hint_label.size.x-26:
        font_size -= 1
    hint_label.add_theme_font_size_override("font_size",font_size)
    _fit_pill(hint_label)

func _build_tower_chip(top: float) -> void:
    tower_button = _button("",Rect2(12,top,160,48),_open_tower)
    var icon := TextureRect.new()
    icon.texture = art.texture("icon_tower")
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.position = Vector2(10,11)
    icon.size = Vector2(26,26)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tower_button.add_child(icon)
    chip_name = _child_label(tower_button,14,INK,true)
    chip_remaining = _child_label(tower_button,12,MUTED,false)
    chip_progress = Control.new()
    chip_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip_progress.draw.connect(_draw_chip_progress.bind(chip_progress))
    tower_button.add_child(chip_progress)
    growth_badge = _child_label(tower_button,12,PRIMARY_TEXT,true)
    var badge_style := _style(GOLD,GOLD,10)
    badge_style.content_margin_top = 1
    badge_style.content_margin_bottom = 1
    badge_style.shadow_color = Color(0,0,0,.45)
    badge_style.shadow_size = 3
    growth_badge.add_theme_stylebox_override("normal",badge_style)
    growth_badge.hide()

func _build_score(score_y: float, score_height: float) -> void:
    var w := size.x
    best_row = HBoxContainer.new()
    best_row.add_theme_constant_override("separation",5)
    best_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    best_row.alignment = BoxContainer.ALIGNMENT_BEGIN if compact_layout else BoxContainer.ALIGNMENT_CENTER
    var trophy := TextureRect.new()
    trophy.texture = art.texture("icon_best")
    trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    trophy.custom_minimum_size = Vector2(15,15)
    trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    trophy.modulate = ICON_GOLD
    trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
    best_row.add_child(trophy)
    best_label = _make_label("",11 if compact_layout else 13,MUTED if compact_layout else GOLD,not compact_layout)
    best_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.6))
    best_label.add_theme_constant_override("shadow_offset_y",1)
    best_row.add_child(best_label)
    controls.add_child(best_row)
    if compact_layout:
        best_row.position = Vector2(12,score_y)
        best_row.size = Vector2(96,score_height)
        score_label = _label("",Rect2(12,score_y,w-24,score_height),28,INK)
    else:
        best_row.position = Vector2(12,score_y)
        best_row.size = Vector2(w-24,18)
        score_label = _label("",Rect2(12,score_y+18,w-24,score_height-18),52,INK)
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    score_label.add_theme_color_override("font_shadow_color",Color(0.13,0.094,0.059,.6))
    score_label.add_theme_constant_override("shadow_offset_y",2)
    streak_chip = PanelContainer.new()
    streak_chip.add_theme_stylebox_override("panel",_chip_style())
    streak_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",4)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var icon := TextureRect.new()
    icon.texture = art.texture("icon_streak")
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.custom_minimum_size = Vector2(14,14)
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    icon.modulate = ICON_GOLD
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)
    streak_text = _make_label("",12,GOLD,true)
    row.add_child(streak_text)
    streak_chip.add_child(row)
    controls.add_child(streak_chip)
    streak_chip.hide()

func _build_auto_switch(rect: Rect2) -> void:
    auto_button = _button("",rect,_toggle_auto)
    auto_title = _child_label(auto_button,12,INK,true)
    auto_title.text = "자동 클리어"
    auto_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    auto_switch = TextureRect.new()
    auto_switch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    auto_switch.stretch_mode = TextureRect.STRETCH_SCALE
    auto_switch.mouse_filter = Control.MOUSE_FILTER_IGNORE
    auto_button.add_child(auto_switch)
    auto_state = _child_label(auto_button,12,MUTED,true)

func _refresh_chip(locked: bool = false) -> void:
    if screen_id != "puzzle" or not is_instance_valid(tower_button) or not is_instance_valid(chip_name): return
    var floors: int = state.growth.total_floors
    var to_next: int = analysis.growth.floors_to_next
    chip_name.text = ("대기 · %s층" if locked else ("도전 탑 %s층" if online_mode else "내 탑 %s층")) % format_int(floors)
    chip_remaining.text = "%d층 남음" % to_next
    var name_size := _font_size(14)
    var rest_size := _font_size(12)
    var bar_width := 44.0 if size.x < 340 else 52.0
    # 설정 버튼과 겹치지 않는 최대 폭 안에서 이름 글자만 줄인다.
    var max_content := size.x-12-128-8-42-14
    while name_size > 9 and _text_width(chip_name.text,name_size,true) > max_content:
        name_size -= 1
    chip_name.add_theme_font_size_override("font_size",name_size)
    var name_width := _text_width(chip_name.text,name_size,true)
    var rest_width := _text_width(chip_remaining.text,rest_size,false)
    var content := maxf(name_width,bar_width+6+rest_width)
    var name_height := strong.get_height(name_size)
    var rest_height := regular.get_height(rest_size)
    var gap := 2.0 if name_height+rest_height+2 <= tower_button.size.y else 0.0
    var y := (tower_button.size.y-(name_height+gap+rest_height))/2
    chip_name.position = Vector2(42,y)
    chip_name.size = Vector2(name_width+2,name_height)
    chip_progress.position = Vector2(42,y+name_height+gap+(rest_height-6)/2)
    chip_progress.size = Vector2(bar_width,6)
    chip_remaining.position = Vector2(42+bar_width+6,y+name_height+gap)
    chip_remaining.size = Vector2(rest_width+2,rest_height)
    tower_button.size.x = minf(ceilf(42+content+14),size.x-12-128-4)
    chip_progress.queue_redraw()
    var description := "%s %s층, 다음 구간까지 %d층" % ["도전 탑" if online_mode else "내 탑",format_int(floors),to_next]
    tower_button.tooltip_text = description
    tower_button.accessibility_name = "탑 보기: "+description
    _place_growth_badge()

func _place_growth_badge() -> void:
    if not is_instance_valid(growth_badge) or not is_instance_valid(tower_button): return
    growth_badge.reset_size()
    growth_badge.position = Vector2(tower_button.size.x-growth_badge.size.x*.65,-growth_badge.size.y*.45)
    growth_badge.pivot_offset = growth_badge.size/2

func _refresh_auto(locked: bool = false) -> void:
    if screen_id != "puzzle" or not is_instance_valid(auto_button) or not is_instance_valid(auto_state): return
    var enabled: bool = state.auto_clear
    auto_state.text = "대기" if locked else ("켬" if enabled else "끔")
    auto_state.add_theme_color_override("font_color",READY if enabled and not locked else MUTED)
    auto_switch.texture = art.texture("switch_on" if enabled else "switch_off")
    auto_switch.modulate.a = .55 if locked else 1.0
    var width := auto_button.size.x
    var title_size := auto_title.get_theme_font_size("font_size")
    var state_size := auto_state.get_theme_font_size("font_size")
    var title_height := strong.get_height(title_size)
    var row_height := maxf(19,strong.get_height(state_size))
    var state_width := _text_width(auto_state.text,state_size,true)
    var gap := 2.0 if title_height+row_height+2 <= auto_button.size.y else 0.0
    var y := (auto_button.size.y-(title_height+gap+row_height))/2
    auto_title.position = Vector2(0,y)
    auto_title.size = Vector2(width,title_height)
    var x := (width-(32+5+state_width))/2
    auto_switch.position = Vector2(x,y+title_height+gap+(row_height-19)/2)
    auto_switch.size = Vector2(32,19)
    auto_state.position = Vector2(x+37,y+title_height+gap)
    auto_state.size = Vector2(state_width+2,row_height)
    var description := "자동 클리어 "+("켜짐" if enabled else "꺼짐")
    auto_button.tooltip_text = description
    auto_button.accessibility_name = description

func _refresh_streak() -> void:
    if not is_instance_valid(streak_chip): return
    var streak: int = state.streak
    streak_text.text = "%d묶음 연속" % streak
    streak_chip.visible = not compact_layout and streak >= STREAK_MIN
    streak_chip.reset_size()
    streak_chip.position = Vector2(size.x-12-streak_chip.size.x,best_row.position.y+best_row.size.y/2-streak_chip.size.y/2)

func _fit_score() -> void:
    if not is_instance_valid(score_label) or not is_instance_valid(best_label): return
    var available := size.x-24
    var best_size := _font_size(11 if compact_layout else 13)
    # 기본 배치의 최고 기록 줄은 가운데 정렬이고 오른쪽에 연속 칩을 둔다.
    var chip_room := (streak_chip.size.x+8)*2 if streak_chip.visible else 0.0
    var best_cap := 76.0 if compact_layout else available-chip_room-20
    while best_size > 7 and _text_width(best_label.text,best_size,not compact_layout) > best_cap:
        best_size -= 1
    if not compact_layout and streak_chip.visible and _text_width(best_label.text,best_size,true) > best_cap:
        # 최고 기록이 우선이다. 공간이 모자라면 연속 칩을 숨긴다.
        streak_chip.hide()
        best_size = _font_size(13)
        while best_size > 7 and _text_width(best_label.text,best_size,true) > available-20:
            best_size -= 1
    best_label.add_theme_font_size_override("font_size",best_size)
    var reserve := 0.0
    if compact_layout: reserve = 20+_text_width(best_label.text,best_size,false)+8
    var base := _font_size(28 if compact_layout else 52)
    var measured := _text_width(score_label.text,base,true)
    var room := available-2*reserve
    score_label.position.x = 12
    score_label.size.x = available
    if compact_layout and _text_width(score_label.text,8,true) > room:
        # 극단적으로 긴 점수는 가운데 대칭을 포기하고 최고 기록 오른쪽 전체 폭을 쓴다.
        score_label.position.x = 12+reserve
        score_label.size.x = available-reserve
        room = available-reserve
    var font_size := base
    if measured > room: font_size = maxi(8,int(base*room/maxf(1,measured)))
    score_label.add_theme_font_size_override("font_size",font_size)

func _hint() -> String:
    var status: String = analysis.get("status","")
    if status == "GAME_OVER": return "남은 조각을 놓을 공간이 없어요"
    if analysis.clear_lines > 0:
        if status == "MUST_CLEAR": return "[완성] %d줄 · 지워야 계속할 수 있어요" % analysis.clear_lines
        return "[완성] %d줄 대기 · 원할 때 지우세요" % analysis.clear_lines
    return "조각을 끌어 놓고 가로·세로 줄을 완성하세요"

func _drag_hint() -> String:
    if preview.get("ok",false):
        var lines := preview_rows.size()+preview_columns.size()
        var cells: int = preview.cells.size()
        if lines == 0: return "[가능] 놓을 수 있어요"
        if state.auto_clear: return "[가능] %d줄 클리어 · +%s점" % [lines,format_int(cells+Session.clear_points(lines))]
        return "[가능] +%d점 · %d줄 완성" % [cells,lines]
    return "[불가] 다른 블록과 겹쳐요" if preview.get("error","") == "OCCUPIED" else "[불가] 보드 안으로 옮겨 주세요"

func _clear_text(busy: bool = false, dragging: bool = false) -> String:
    if busy: return "처리 중 · 잠시만요"
    if analysis.status == "GAME_OVER": return "결과 보기"
    if state.auto_clear: return "자동 · 줄이 바로 지워져요"
    if analysis.clear_lines == 0: return "대기 · 줄을 완성하세요"
    if dragging: return "%d줄 클리어\n놓는 동안 잠겨요" % analysis.clear_lines
    return "%d줄 클리어\n+%s점 · 탑 +%d층" % [analysis.clear_lines, format_int(analysis.clear_points), analysis.clear_lines]

func _fit_clear_text() -> void:
    if not is_instance_valid(clear_button): return
    var base := _font_size(14 if compact_layout else 15)
    var text := clear_button.text
    # 두 줄이 버튼 높이에 들어가지 않으면 같은 정보를 한 줄로 합친다.
    if text.contains("\n") and 2*base*1.42 > clear_button.size.y-4:
        text = " · ".join(text.split("\n"))
        clear_button.text = text
    var font_size := base
    while font_size > 10 and _text_width(text,font_size,true) > clear_button.size.x-24:
        font_size -= 1
    clear_button.add_theme_font_size_override("font_size",font_size)

func _sync_buttons() -> void:
    if screen_id != "puzzle" or not is_instance_valid(clear_button): return
    var busy: bool = not controller.application_active or controller.phase in ["committing", "settling", "recovery"]
    var dragging: bool = controller.phase == "dragging"
    var locked := busy or dragging
    clear_button.disabled = locked or (analysis.status != "GAME_OVER" and (state.auto_clear or analysis.clear_lines == 0))
    auto_button.disabled = locked
    tower_button.disabled = locked
    clear_button.text = _clear_text(busy,dragging)
    # 줄이 없거나 자동일 때는 조용한 안내, 잠시 잠긴 대기 줄은 비활성 재질로 구분한다.
    var quiet: bool = not busy and analysis.status != "GAME_OVER" and (state.auto_clear or analysis.clear_lines == 0)
    clear_button.add_theme_stylebox_override("disabled",_quiet_style() if quiet else art.panel("button","disabled"))
    clear_button.add_theme_color_override("font_disabled_color",MUTED if quiet else DISABLED_TEXT)
    _fit_clear_text()
    _refresh_chip(locked)
    _refresh_auto(locked)
    _refresh_tray_notes()
    _redraw()

func _redraw() -> void:
    if has_node("BoardCanvas"): $BoardCanvas.queue_redraw()
    if is_instance_valid(drag_layer): drag_layer.queue_redraw()

func _refresh_fits() -> void:
    # 보드/조각은 커밋에서만 바뀐다. 레이아웃 재생성에는 확정 결과를 재사용한다.
    if controller.session == _tray_session and int(state.get("revision", -1)) == _tray_revision: return
    _tray_session = controller.session
    _tray_revision = int(state.get("revision", -1))
    slot_fits.assign([true,true,true])
    tray_pieces.assign([{},{},{}])
    if controller.session == null: return
    for slot_index in range(3):
        var piece: Dictionary = controller.session.piece_for_slot(slot_index)
        tray_pieces[slot_index] = piece
        if piece.is_empty(): continue
        var found := false
        for y in range(9-piece.height):
            for x in range(9-piece.width):
                if controller.session.preview_placement(slot_index,x,y).ok:
                    found = true
                    break
            if found: break
        slot_fits[slot_index] = found

func _lane_note_visible(slot_index: int) -> bool:
    if slot_index >= tray_rects.size() or tray_rects[slot_index].size.y < LANE_NOTE_MIN_HEIGHT: return false
    if controller.phase == "dragging" and slot_index == controller.slot: return false
    return not slot_fits[slot_index] and not tray_pieces[slot_index].is_empty()

func _refresh_tray_notes() -> void:
    for slot_index in range(tray_notes.size()):
        var note: Label = tray_notes[slot_index]
        if is_instance_valid(note): note.visible = _lane_note_visible(slot_index)

func _refresh_tray_scale() -> void:
    if tray_rects.is_empty(): return
    var largest := Vector2.ONE
    for slot_index in range(3):
        var piece: Dictionary = tray_pieces[slot_index]
        if not piece.is_empty(): largest = largest.max(Vector2(piece.width,piece.height))
    var note_room := 12.0 if tray_rects[0].size.y >= LANE_NOTE_MIN_HEIGHT else 0.0
    tray_cell_size = minf(28,minf((tray_rects[0].size.x-20)/largest.x,(tray_rects[0].size.y-16-note_room)/largest.y))

func _refresh_preview_lines() -> void:
    preview_rows.clear()
    preview_columns.clear()
    if not preview.get("ok",false): return
    var occupied: PackedByteArray = state.occupancy.duplicate()
    for i in preview.cells: occupied[i] = 1
    for line in range(8):
        var row_before := true
        var row_after := true
        var column_before := true
        var column_after := true
        for k in range(8):
            row_before = row_before and state.occupancy[line*8+k] == 1
            row_after = row_after and occupied[line*8+k] == 1
            column_before = column_before and state.occupancy[k*8+line] == 1
            column_after = column_after and occupied[k*8+line] == 1
        if row_after and not row_before: preview_rows.append(line)
        if column_after and not column_before: preview_columns.append(line)

func _cell(canvas: CanvasItem, rect: Rect2, style_id: int, alpha: float = 1.0) -> void:
    canvas.draw_texture_rect(art.cell(style_id),rect.grow(-.35),false,Color(1,1,1,alpha))

func _grid_cell(i: int) -> Rect2:
    var step := board_rect.size.x / 8.0
    return Rect2(board_rect.position + Vector2(i % 8, i / 8) * step, Vector2.ONE * step)

func _row_rect(row: int) -> Rect2:
    var step := board_rect.size.x/8.0
    return Rect2(board_rect.position+Vector2(0,row*step),Vector2(board_rect.size.x,step))

func _column_rect(column: int) -> Rect2:
    var step := board_rect.size.x/8.0
    return Rect2(board_rect.position+Vector2(column*step,0),Vector2(step,board_rect.size.y))

func _draw_line_band(canvas: CanvasItem, rect: Rect2, pending: bool) -> void:
    # 대기 줄은 채운 띠, 실선, 양 끝 점으로 표시한다. 색은 보조 단서다.
    var band := rect.grow(-1.5)
    canvas.draw_rect(band,Color(READY,.14 if pending else .12))
    if pending: canvas.draw_rect(band.grow(1.5),Color(READY,.22),false,2)
    canvas.draw_rect(band,Color(READY,1.0 if pending else .75),false,2)
    if not pending: return
    var center := band.get_center()
    if rect.size.x > rect.size.y:
        canvas.draw_circle(Vector2(band.position.x+7,center.y),3,READY)
        canvas.draw_circle(Vector2(band.end.x-7,center.y),3,READY)
    else:
        canvas.draw_circle(Vector2(center.x,band.position.y+7),3,READY)
        canvas.draw_circle(Vector2(center.x,band.end.y-7),3,READY)

func _draw_progress(canvas: Control, ratio: float) -> void:
    var bounds := Rect2(Vector2.ZERO,canvas.size)
    var track := StyleBoxFlat.new()
    track.bg_color = Color(0,0,0,.5)
    track.border_color = Color(0.914,0.839,0.706,.2)
    track.set_border_width_all(1)
    track.set_corner_radius_all(int(bounds.size.y/2))
    canvas.draw_style_box(track,bounds)
    if ratio <= 0: return
    var fill := StyleBoxFlat.new()
    fill.bg_color = GOLD
    fill.set_corner_radius_all(int(bounds.size.y/2))
    canvas.draw_style_box(fill,Rect2(bounds.position,Vector2(maxf(bounds.size.y,bounds.size.x*clampf(ratio,0,1)),bounds.size.y)))

func _draw_chip_progress(canvas: Control) -> void:
    if analysis.is_empty(): return
    _draw_progress(canvas,analysis.growth.partial_floors/10.0)

func _must_clear_emphasis() -> bool:
    return analysis.get("status","") == "MUST_CLEAR" and is_instance_valid(clear_button) and not clear_button.disabled

func _draw_board(canvas: Control) -> void:
    if state.is_empty(): return
    if screen_id == "tower_overview":
        canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),BACKGROUND_DIM)
        _draw_tower_overview(canvas)
        return
    if screen_id in ["tower","tower_focus"]:
        _draw_tower(canvas)
        return
    canvas.draw_rect(Rect2(Vector2.ZERO,size),BACKGROUND_DIM)
    if growth_glow > 0 and is_instance_valid(tower_button):
        canvas.draw_style_box(_ring_style(Color(GOLD,.85*growth_glow),10*growth_glow),tower_button.get_rect().grow(2))
    if _must_clear_emphasis():
        canvas.draw_style_box(_ring_style(GOLD,12),clear_button.get_rect().grow(3))
    canvas.draw_style_box(art.panel("board"), board_rect.grow(4))
    for i in range(64):
        var r := _grid_cell(i)
        canvas.draw_texture_rect(art.texture("empty"),r.grow(-.35),false)
        if state.occupancy[i] and not (effect_alpha>0 and i in snap_cells): _cell(canvas, r, state.cell_style[i])
    for row in analysis.pending_rows: _draw_line_band(canvas,_row_rect(row),true)
    for column in analysis.pending_columns: _draw_line_band(canvas,_column_rect(column),true)
    canvas.draw_style_box(art.panel("tray"),shelf_rect)
    for divider: int in [1,2]:
        var x: float = shelf_rect.position.x+shelf_rect.size.x*divider/3.0
        canvas.draw_line(Vector2(x,shelf_rect.position.y+16),Vector2(x,shelf_rect.end.y-16),LANE_LINE,1)
    for s in range(3):
        var piece: Dictionary = tray_pieces[s]
        if piece.is_empty(): continue
        var dragging_this: bool = controller.phase == "dragging" and s == controller.slot
        var fits: bool = slot_fits[s]
        var tint := Color(1,1,1,.2) if dragging_this else (Color.WHITE if fits else DIMMED_PIECE)
        var cell_size := tray_cell_size
        var center: Vector2 = tray_rects[s].get_center()-Vector2(0,LANE_NOTE_SHIFT if _lane_note_visible(s) else 0.0)
        var p: Vector2 = center - Vector2(piece.width,piece.height)*cell_size/2
        for c in piece.cells:
            canvas.draw_texture_rect(art.cell(piece.family_index+1),Rect2(p+Vector2(c)*cell_size, Vector2.ONE*cell_size).grow(-.35),false,tint)
        if not fits and not dragging_this:
            # 놓을 수 없는 조각은 색 외에도 작은 × 표시를 둔다.
            var mark := Vector2(tray_rects[s].end.x-16,tray_rects[s].position.y+14)
            canvas.draw_line(mark-Vector2(4,4),mark+Vector2(4,4),MUTED,2,true)
            canvas.draw_line(mark+Vector2(-4,4),mark+Vector2(4,-4),MUTED,2,true)
    if controller.phase == "dragging" and not drag_piece.is_empty():
        var step := board_rect.size.x / 8
        var valid: bool = preview.get("ok", false)
        var preview_color := READY if valid else INVALID
        if valid:
            for row in preview_rows: _draw_line_band(canvas,_row_rect(row),false)
            for column in preview_columns: _draw_line_band(canvas,_column_rect(column),false)
        for c in drag_piece.cells:
            var at: Vector2i = controller.origin + c
            if at.x >= 0 and at.x < 8 and at.y >= 0 and at.y < 8:
                var r := _grid_cell(at.y*8+at.x).grow(-2)
                if valid: _cell(canvas,r,drag_piece.family_index+1,.48)
                else: canvas.draw_rect(r,Color(preview_color,.22))
                canvas.draw_rect(r, preview_color, false, 2)
                if valid:
                    var a := r.position+Vector2(step*.12,step*.52)
                    var b := r.position+Vector2(step*.27,step*.67)
                    var d := r.position+Vector2(step*.57,step*.32)
                    canvas.draw_line(a,b,PRIMARY_TEXT,3,true)
                    canvas.draw_line(b,d,PRIMARY_TEXT,3,true)
                else:
                    canvas.draw_line(r.position,r.end,preview_color,2)
                    canvas.draw_line(r.position+Vector2(r.size.x,0),r.position+Vector2(0,r.size.y),preview_color,2)
    if effect_alpha > 0:
        Effects.draw(canvas,board_rect,art,remnants,remnant_styles,snap_cells,state.cell_style,effect_rows,effect_columns,effect_progress)

func _draw_drag(layer: Control) -> void:
    if screen_id != "puzzle" or controller.phase != "dragging" or drag_piece.is_empty(): return
    var step := board_rect.size.x/8
    var p := drag_position-grab+lift
    var pick_scale := lerpf(.88,1.0,minf(1,pick_age/.09)) if not preferences.values.reduced_motion else 1.0
    for c in drag_piece.cells:
        var r := Rect2(p+Vector2(c)*step,Vector2.ONE*step)
        layer.draw_texture_rect(art.cell(drag_piece.family_index+1),Rect2(r.position+Vector2(0,5),r.size),false,Color(0,0,0,.23))
        _cell(layer,Rect2(r.get_center()-r.size*pick_scale/2,r.size*pick_scale),drag_piece.family_index+1,.94)
    if preview.get("ok",false): return
    for c in drag_piece.cells:
        var at: Vector2i = controller.origin+c
        if at.x >= 0 and at.x < 8 and at.y >= 0 and at.y < 8:
            var r := _grid_cell(at.y*8+at.x).grow(-4)
            layer.draw_line(r.position,r.end,INVALID,2)
            layer.draw_line(r.position+Vector2(r.size.x,0),r.position+Vector2(0,r.size.y),INVALID,2)

func side_length() -> float:
    return board_rect.size.x

func handle_back() -> bool:
    if not controller.application_active: return true
    if modal != null: _close_modal()
    elif controller.phase == "dragging": _cancel_drag()
    elif screen_id in ["tower_overview","tower_focus"]: _show_selected_tower()
    elif screen_id == "tower": _open_puzzle()
    else: return false
    return true

func _input(event: InputEvent) -> void:
    if not controller.application_active:
        get_viewport().set_input_as_handled()
        return
    if not is_visible_in_tree(): return
    if state.is_empty(): return
    if controller.phase == "dragging":
        if (event is InputEventScreenTouch or event is InputEventScreenDrag) and event.index != controller.pointer:
            get_viewport().set_input_as_handled()
            return
        if event is InputEventMouseButton and (touch_active or event.device == InputEvent.DEVICE_ID_EMULATION):
            get_viewport().set_input_as_handled()
            return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        handle_back()
        get_viewport().set_input_as_handled()
        return
    if screen_id != "puzzle" or modal != null or controller.phase in ["recovery", "committing", "settling"]: return
    if event is InputEventScreenTouch:
        if event.canceled:
            if event.index == controller.pointer: _cancel_drag()
            get_viewport().set_input_as_handled()
            return
        touch_active = true
        touch_until = Time.get_ticks_msec()+Tokens.TOUCH_MOUSE_SUPPRESSION_MS
        _pointer(event.index,event.position,event.pressed,not event.pressed)
    elif event is InputEventScreenDrag:
        _pointer(event.index,event.position,false,false)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if touch_active or event.device == InputEvent.DEVICE_ID_EMULATION: return
        _pointer(-1,event.position,event.pressed,not event.pressed)
    elif event is InputEventMouseMotion and not touch_active:
        _pointer(-1,event.position,false,false)

func _pointer(id: int, point: Vector2, down: bool, up: bool) -> void:
    if not controller.application_active: return
    var p := get_global_transform_with_canvas().affine_inverse() * point
    if down and controller.phase == "idle":
        for s in range(3):
            if tray_rects[s].has_point(p) and controller.begin_drag(id,s):
                if toast_motion != null: toast_motion.kill()
                toast_queue.clear()
                toast_label.modulate.a = 0
                hint_label.show()
                drag_piece = controller.session.piece_for_slot(s)
                var step := board_rect.size.x/8
                grab = Vector2(drag_piece.width,drag_piece.height)*step/2
                lift = Vector2(0,-step*Tokens.touch_lift_cells(drag_piece.height)) if id >= 0 else Vector2.ZERO
                pick_age = 0.0
                feedback.cue("pick")
                break
    if controller.phase != "dragging" or controller.pointer != id: return
    drag_position = p
    var at := controller.assisted_origin(p,board_rect,grab,lift)
    preview = controller.move_drag(id,at)
    _refresh_preview_lines()
    _set_hint(_drag_hint())
    if up:
        var piece_center: Vector2 = p-grab+lift+Vector2(drag_piece.width,drag_piece.height)*board_rect.size.x/16
        controller.release_drag(id,board_rect.has_point(piece_center))
        drag_piece = {}
        preview = {}
        _refresh_preview_lines()
        _set_hint(_hint())
    _sync_buttons()
    _redraw()
    get_viewport().set_input_as_handled()

func _cancel_drag() -> void:
    controller.cancel()
    drag_piece = {}
    preview = {}
    _refresh_preview_lines()
    _set_hint(_hint())
    _sync_buttons()
    _redraw()

func _clear() -> void:
    if analysis.status == "GAME_OVER": _results()
    else: controller.submit("CLEAR")

func _toggle_auto() -> void:
    if not state.auto_clear and analysis.clear_lines > 0:
        # 게임 기획 4.4절 문구와 버튼 이름을 따른다.
        _dialog("자동 클리어로 바꿀까요?", "완성된 %d줄을 지금 지우고,\n이후 완성되는 줄은 자동으로 지웁니다." % analysis.clear_lines,"지우고 자동 전환",func(): _confirm_auto(),"수동 유지",true)
        modal_content.add_child(_reward_pill("이번 클리어 +%s점 · 탑 +%d층" % [format_int(analysis.clear_points),analysis.clear_lines]))
        _fit_modal()
    else: controller.submit("SET_AUTO",{"enabled":not state.auto_clear,"confirmed":false})

func _confirm_auto() -> void:
    _remove_modal()
    controller.submit_modal("SET_AUTO",{"enabled":true,"confirmed":true})

func _committed(result: Dictionary, before: Dictionary) -> void:
    interrupt(false)
    state = result.snapshot
    analysis = controller.session.view()
    var clear_event: Dictionary = {}
    for event in result.events:
        match event.type:
            "PLACED":
                snap_cells = event.cells.duplicate()
            "CLEARED":
                clear_event = event
                remnants = event.cells.duplicate()
                remnant_styles = event.styles.duplicate()
                effect_rows = event.rows.duplicate()
                effect_columns = event.columns.duplicate()
    last_event_announcements = _event_announcements(result.events,before,state)
    last_event_details = _event_detail_lines(result.events,before,state)
    if not clear_event.is_empty(): last_growth_details = _growth_detail_lines(clear_event,before,state)
    _refresh_text()
    if not clear_event.is_empty() and clear_event.floors > 0: _show_growth_badge(clear_event.floors)
    if not clear_event.is_empty(): feedback.cue("clear",mini(clear_event.lines,4))
    elif result.events.any(func(event): return event.type == "PLACED"): feedback.cue("snap")
    _queue_toasts(last_event_announcements)
    effect_alpha = 1.0
    effect_progress = 0.0
    settle_left = Tokens.CLEAR_SETTLE if not clear_event.is_empty() else Tokens.SNAP
    if preferences.values.reduced_motion:
        settle_left = 0
        effect_alpha = 0
        controller.settle()
        _after_settle(clear_event)
    else:
        motion = create_tween().set_parallel(true)
        motion.tween_property(self,"effect_progress",1.0,Tokens.CLEAR_VISUAL if not clear_event.is_empty() else Tokens.SNAP)
        motion.chain().tween_callback(func(): _after_settle(clear_event))
    _sync_buttons()
    _redraw()

func _show_growth_badge(floors: int) -> void:
    if not is_instance_valid(growth_badge): return
    if growth_motion != null: growth_motion.kill()
    growth_badge.text = "+%d층" % floors
    _place_growth_badge()
    growth_badge.modulate.a = 1.0
    growth_badge.show()
    growth_glow = 1.0
    growth_motion = create_tween()
    if preferences.values.reduced_motion:
        # 움직임 줄이기에서도 같은 보상 정보를 정지 상태로 보여 준다.
        growth_badge.scale = Vector2.ONE
        growth_motion.tween_interval(GROWTH_BADGE_HOLD)
    else:
        growth_badge.scale = Vector2.ONE*.6
        growth_motion.tween_property(growth_badge,"scale",Vector2.ONE,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        growth_motion.tween_interval(GROWTH_BADGE_HOLD-.38)
        growth_motion.tween_property(self,"growth_glow",0.0,.2)
        growth_motion.parallel().tween_property(growth_badge,"modulate:a",0.0,.2)
    growth_motion.tween_callback(_hide_growth_badge)
    _redraw()

func _hide_growth_badge() -> void:
    growth_glow = 0.0
    if is_instance_valid(growth_badge):
        growth_badge.hide()
        growth_badge.modulate.a = 1.0
        growth_badge.scale = Vector2.ONE
    _redraw()

func _after_settle(clear_event: Dictionary = {}) -> void:
    if not controller.application_active: return
    remnants.clear()
    remnant_styles.clear()
    effect_rows.clear()
    effect_columns.clear()
    snap_cells.clear()
    effect_alpha = 0
    controller.settle()
    _sync_buttons()
    _redraw()
    if not clear_event.is_empty() and clear_event.new_segments > 0: feedback.cue("lock")
    if analysis.status == "GAME_OVER" and modal == null:
        feedback.cue("over")
        _results()

func _refresh_text() -> void:
    if screen_id != "puzzle":
        _layout()
        return
    score_label.text = format_int(state.score)
    best_label.text = ("최고\n%s" if compact_layout else "최고 %s") % format_int(state.best)
    _refresh_fits()
    _refresh_tray_scale()
    _refresh_streak()
    _fit_score()
    _set_hint(_hint())
    _refresh_chip()
    _refresh_auto()
    clear_button.text = _clear_text()
    _fit_clear_text()
    _refresh_tray_notes()

func _rejected(error: String) -> void:
    if error in ["OCCUPIED", "OUT_OF_BOUNDS"]:
        feedback.cue("reject")
        _toast("겹치지 않는 보드 안쪽에 놓아 주세요")
    elif error == "STALE_INPUT": _toast("상태가 바뀌었어요. 다시 선택해 주세요")
    elif error != "BUSY":
        _save_error_dialog()
    _sync_buttons()

func _save_error_dialog() -> void:
    _dialog("저장하지 못했어요", "진행 기록을 다시 확인한 뒤 계속할 수 있어요.","기록 다시 읽기",func(): reload_requested.emit(),"")

func _event_announcements(events: Array, before: Dictionary, after: Dictionary) -> Array[String]:
    var messages: Array[String] = []
    var clear_event: Dictionary = {}
    var placed_points := 0
    var settled_streak := 0
    var supplied := false
    var game_over := false
    var run_started := false
    for event in events:
        match event.type:
            "PLACED": placed_points = event.points
            "CLEARED": clear_event = event
            "BATCH_SETTLED": settled_streak = event.streak
            "SUPPLIED": supplied = true
            "GAME_OVER": game_over = true
            "RUN_STARTED": run_started = true
    if run_started:
        best_announced = false
        return messages
    if not clear_event.is_empty():
        messages.append("[완료] %d줄 · +%d점 · +%d층" % [clear_event.lines,clear_event.points,clear_event.floors])
    elif placed_points > 0:
        messages.append("[배치] +%d점" % placed_points)

    if not clear_event.is_empty():
        var unlock_count: int = clear_event.materials.size()+clear_event.parts.size()
        if clear_event.new_segments > 0 or unlock_count > 0:
            var progress_parts: Array[String] = []
            if clear_event.new_segments > 0: progress_parts.append("구간 +%d" % clear_event.new_segments)
            if unlock_count > 0: progress_parts.append("해금 %d종" % unlock_count)
            messages.append(" · ".join(progress_parts))

    var new_best: bool = after.best > before.best and not best_announced
    if new_best:
        best_announced = true
    var status_parts: Array[String] = []
    if new_best: status_parts.append("기록 갱신")
    if supplied: status_parts.append("새 조각")
    if game_over: status_parts.append("게임 종료")
    if status_parts.is_empty() and settled_streak > 0: status_parts.append("연속 %d묶음" % settled_streak)
    if not status_parts.is_empty(): messages.append(" · ".join(status_parts))
    while messages.size() > MAX_EVENT_ANNOUNCEMENTS: messages.pop_back()
    return messages

func _growth_detail_lines(clear_event: Dictionary, before: Dictionary, after: Dictionary) -> Array[String]:
    var details: Array[String] = []
    var old_segments: int = int(before.growth.total_floors/10)
    var new_segments: int = int(after.growth.total_floors/10)
    var segment_names: Array[String] = []
    for segment in range(old_segments+1,new_segments+1): segment_names.append(str(segment))
    if not segment_names.is_empty(): details.append("새 구간: "+", ".join(segment_names))
    var material_names: Array[String] = []
    for material in clear_event.materials: material_names.append(_material_name(str(material)))
    if not material_names.is_empty(): details.append("새 재료: "+", ".join(material_names))
    var part_names: Array[String] = []
    for part in clear_event.parts: part_names.append(_part_name(str(part)))
    if not part_names.is_empty(): details.append("새 장식: "+", ".join(part_names))
    if details.is_empty(): details.append("이번 클리어에서 새 구간이나 재료·장식 해금은 없어요")
    return details

func _material_name(material: String) -> String:
    var labels := {"wood":"나무","brick":"벽돌","metal":"금속","crystal":"수정"}
    return labels.get(material,"새 재료")

func _part_name(part: String) -> String:
    var labels := {
        "brick_arch_window":"아치 창문",
        "brick_terrace":"테라스",
        "brick_cornice":"상단 장식",
        "brick_landmark":"랜드마크"
    }
    return labels.get(part,"새 장식")

func _event_detail_lines(events: Array, before: Dictionary, after: Dictionary) -> Array[String]:
    var details: Array[String] = []
    for event in events:
        match event.type:
            "PLACED":
                if event.points > 0 and events.any(func(item): return item.type == "CLEARED") == false:
                    details.append("배치 점수: +%d점" % event.points)
            "CLEARED":
                details.append("클리어: %d줄 · +%d점 · +%d층" % [event.lines,event.points,event.floors])
                details.append("누적: %d층" % after.growth.total_floors)
                details.append_array(_growth_detail_lines(event,before,after))
            "BATCH_SETTLED": details.append("연속 완성: %d묶음" % event.streak)
            "SUPPLIED": details.append("새 조각 3개를 받았어요")
            "GAME_OVER": details.append("게임 종료 · %d점 · 최고 %d점" % [after.score,after.best])
    if after.best > before.best: details.append("새 최고 기록: %d점" % after.best)
    return details

func _growth_details_text() -> String:
    var details: Array[String] = ["누적 %d층 · %d개 구간 완성" % [state.growth.total_floors,analysis.growth.completed_segments]]
    if not last_growth_details.is_empty():
        details.append("최근 클리어")
        details.append_array(last_growth_details)
    else:
        var unlocked_materials: Array[String] = []
        for material in analysis.growth.materials:
            if material != "wood": unlocked_materials.append(_material_name(str(material)))
        var unlocked_parts: Array[String] = []
        for part in analysis.growth.parts: unlocked_parts.append(_part_name(str(part)))
        details.append("해금 재료: "+("없음" if unlocked_materials.is_empty() else ", ".join(unlocked_materials)))
        details.append("해금 장식: "+("없음" if unlocked_parts.is_empty() else ", ".join(unlocked_parts)))
    details.append("현재 재료: "+", ".join(analysis.growth.materials.map(func(id): return _material_name(str(id)))))
    if not analysis.growth.parts.is_empty():
        details.append("현재 장식: "+", ".join(analysis.growth.parts.map(func(id): return _part_name(str(id)))))
    else:
        details.append("현재 장식: 없음")
    return "\n".join(details)

func _show_growth_details() -> void:
    _dialog("탑 성장 내역",_growth_details_text(),"닫기",_close_modal,"")

func _toast(message: String) -> void:
    _queue_toasts([message])

func _queue_toasts(messages: Array[String]) -> void:
    if not is_instance_valid(toast_label): return
    if toast_motion != null: toast_motion.kill()
    toast_queue.clear()
    for message in messages:
        if not message.is_empty(): toast_queue.append(message)
    if toast_queue.is_empty():
        toast_label.modulate.a = 0
        if is_instance_valid(hint_label): hint_label.show()
        return
    _show_next_toast()

func _show_next_toast() -> void:
    if not is_instance_valid(toast_label) or toast_queue.is_empty():
        if is_instance_valid(hint_label): hint_label.show()
        return
    var message: String = toast_queue.pop_front()
    toast_label.position = hint_label.position
    toast_label.size = hint_label.size
    # 작은 화면의 안내 줄 높이 안에 큰 글씨까지 들어가도록 기준 크기를 낮춘다.
    var font_size := _font_size(12 if compact_layout else 14)
    var minimum_size := _font_size(11 if compact_layout else 12)
    while font_size > minimum_size and strong.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > toast_label.size.x-26:
        font_size -= 1
    toast_label.add_theme_font_size_override("font_size",font_size)
    toast_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    toast_label.text = message
    _fit_pill(toast_label)
    toast_label.modulate.a = 1
    hint_label.hide()
    toast_motion = create_tween()
    toast_motion.tween_interval(EVENT_NOTICE_HOLD)
    toast_motion.tween_property(toast_label,"modulate:a",0.0,Tokens.TOAST_FADE)
    toast_motion.tween_callback(func():
        if not toast_queue.is_empty(): _show_next_toast()
        elif is_instance_valid(hint_label): hint_label.show())

func _process(delta: float) -> void:
    if not controller.application_active: return
    if touch_active and controller.pointer < 0 and Time.get_ticks_msec() > touch_until: touch_active = false
    if controller.phase == "dragging":
        pick_age += delta
        if pick_age < .12: _redraw()
    if controller.phase == "settling":
        settle_left -= delta
        if settle_left <= 0:
            controller.settle()
            _sync_buttons()
    if effect_alpha > 0 or growth_glow > 0: _redraw()

func interrupt(unlock: bool = true) -> void:
    if motion != null: motion.kill()
    if toast_motion != null: toast_motion.kill()
    if growth_motion != null: growth_motion.kill()
    toast_queue.clear()
    if feedback != null: feedback.stop_all()
    if controls != null: _reset_button_motion(controls)
    remnants.clear()
    remnant_styles.clear()
    effect_rows.clear()
    effect_columns.clear()
    snap_cells.clear()
    effect_alpha = 0
    growth_glow = 0
    if is_instance_valid(growth_badge): growth_badge.hide()
    if is_instance_valid(toast_label):
        toast_label.text = ""
        toast_label.modulate.a = 0
    if is_instance_valid(hint_label): hint_label.show()
    drag_piece = {}
    preview = {}
    preview_rows.clear()
    preview_columns.clear()
    if unlock: controller.cancel()

func _ui_callback_allowed(control: Control, epoch: int) -> bool:
    if not controller.application_active or epoch != _ui_epoch or not is_instance_valid(control): return false
    if control.is_queued_for_deletion() or not control.is_visible_in_tree(): return false
    return modal == null or modal.is_ancestor_of(control)

func _reset_button_motion(node: Node) -> void:
    if node is BaseButton:
        if node.has_meta("motion"):
            var tween: Tween = node.get_meta("motion")
            if tween != null: tween.kill()
        node.scale = Vector2.ONE
        node.modulate = Color.WHITE
    for child in node.get_children(): _reset_button_motion(child)

func set_application_active(active: bool) -> void:
    if controller.application_active == active: return
    controller.set_application_active(active)
    if feedback != null: feedback.application_active = active
    touch_active = false
    touch_until = 0
    _ui_epoch += 1
    if not active:
        var focused := get_viewport().gui_get_focus_owner()
        if focused != null: focused.release_focus()
        interrupt()
        if modal != null: _close_modal()
        _sync_buttons()
        _redraw()
    elif controller.session != null:
        # 저장된 보상을 재생하지 않고 확정 snapshot으로 입력 위젯을 새로 만든다.
        state = controller.session.snapshot()
        analysis = controller.session.view()
        _layout()

func _exit_tree() -> void:
    controller.set_application_active(false)
    interrupt()

func _dialog(title: String, message: String, primary: String, callback: Callable, secondary: String = "닫기", side_by_side: bool = false) -> void:
    interrupt()
    if modal != null: _remove_modal()
    controller.open_modal()
    last_focus = get_viewport().gui_get_focus_owner()
    background_focus.clear()
    for child in controls.get_children():
        if child is BaseButton:
            background_focus.append(child)
            child.focus_mode = Control.FOCUS_NONE
    modal = ColorRect.new()
    modal.color = MODAL_SCRIM
    modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    modal.mouse_filter = Control.MOUSE_FILTER_STOP
    controls.add_child(modal)
    # 모든 확인창은 엄지가 닿는 하단 시트다. 높이는 내용에 맞추고 안전 영역을 넘지 않는다.
    var panel := PanelContainer.new()
    panel.position = Vector2(12,_safe_vertical().x+8)
    panel.size = Vector2(size.x-24,160)
    panel.add_theme_stylebox_override("panel",_sheet_style())
    modal.add_child(panel)
    var dialog_root := VBoxContainer.new()
    dialog_root.add_theme_constant_override("separation",12)
    panel.add_child(dialog_root)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialog_root.add_child(scroll)
    modal_content = VBoxContainer.new()
    modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    modal_content.add_theme_constant_override("separation",10)
    scroll.add_child(modal_content)
    for text in [title,message]:
        modal_content.add_child(_wrapped_label(text,20 if text==title else 14,INK if text==title else NOTE_TEXT,text==title))
    modal_actions = HBoxContainer.new() if side_by_side else VBoxContainer.new()
    modal_actions.add_theme_constant_override("separation",8)
    dialog_root.add_child(modal_actions)
    # 두 선택지는 보조 동작을 왼쪽, 주 동작을 오른쪽에 둔다. 주 동작은 항상 첫 자식이다.
    if side_by_side: modal_actions.layout_direction = Control.LAYOUT_DIRECTION_RTL
    var button := _modal_button(primary,callback,true)
    if not secondary.is_empty(): _modal_button(secondary,_close_modal,false)
    button.grab_focus()
    _fit_modal()

func _modal_button(text: String, callback: Callable, primary: bool) -> Button:
    var button := _button(text,Rect2(0,0,size.x-48,48),callback,primary)
    controls.remove_child(button)
    modal_actions.add_child(button)
    button.custom_minimum_size.y = 48
    if modal_actions is HBoxContainer:
        button.layout_direction = Control.LAYOUT_DIRECTION_LTR
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return button

func _text_button(text: String, callback: Callable, color: Color) -> Button:
    var button := _modal_button(text,callback,false)
    var empty := StyleBoxEmpty.new()
    for style_state in ["normal","hover","pressed","disabled"]:
        button.add_theme_stylebox_override(style_state,empty)
    for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        button.add_theme_color_override(k,color)
    return button

func _reward_pill(text: String) -> Label:
    var pill := _make_label(text,13,GOLD,true)
    pill.add_theme_stylebox_override("normal",_chip_style())
    pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    pill.custom_minimum_size.y = 30
    return pill

func _fit_modal() -> void:
    if not is_instance_valid(modal) or modal.get_child_count() == 0: return
    var panel := modal.get_child(0) as Control
    var safe := _safe_vertical()
    var available := maxf(160,size.y-safe.x-safe.y-16)
    var chrome := panel.get_theme_stylebox("panel").get_minimum_size().y
    var wanted := _stack_height(modal_content)+12+_stack_height(modal_actions)+chrome+4
    var height := minf(available,ceilf(wanted))
    panel.size = Vector2(size.x-24,height)
    panel.position = Vector2(12,size.y-safe.y-8-height)
    if modal.has_meta("close_button"):
        var close: Control = modal.get_meta("close_button")
        var title_height: float = modal_content.get_child(0).custom_minimum_size.y
        if is_instance_valid(close): close.position = panel.position+Vector2(panel.size.x-close.size.x-10,14+title_height/2-close.size.y/2)

func _stack_height(box: BoxContainer) -> float:
    # 자동 줄바꿈 Label은 폭이 정해지기 전 최소 높이가 과대하므로 미리 잰 높이를 쓴다.
    var total := 0.0
    var count := 0
    var horizontal := box is HBoxContainer
    for child in box.get_children():
        if not child is Control or not child.visible: continue
        var height: float = child.custom_minimum_size.y if child is Label and child.autowrap_mode != TextServer.AUTOWRAP_OFF else child.get_combined_minimum_size().y
        total = maxf(total,height) if horizontal else total+height
        count += 1
    if not horizontal and count > 1: total += box.get_theme_constant("separation")*(count-1)
    return total

func _remove_modal() -> void:
    if is_instance_valid(modal):
        modal.hide()
        modal.queue_free()
    modal = null
    modal_content = null
    modal_actions = null
    segment_jump_input = null
    segment_jump_status = null
    segment_copy_input = null
    segment_copy_preview = null
    volume_slider = null
    for child in background_focus:
        if is_instance_valid(child): child.focus_mode = Control.FOCUS_ALL
    background_focus.clear()
    if is_instance_valid(last_focus): last_focus.grab_focus()

func _close_modal() -> void:
    if controller.phase == "recovery": return
    _remove_modal()
    controller.cancel()
    _sync_buttons()

func _settings() -> void:
    if controller.phase == "recovery": return
    _dialog("설정", "퍼즐 규칙과 점수에는 영향을 주지 않아요.","계속하기",_close_modal,"")
    var epoch := _ui_epoch
    for entry in [["sound","효과음"],["volume","음량"],["haptics","진동"],["reduced_motion","움직임 줄이기"],["large_text","큰 글씨"]]:
        var setting_key := str(entry[0])
        if setting_key == "volume":
            modal_content.add_child(_volume_row(epoch))
            continue
        var check := CheckButton.new()
        check.text = entry[1]
        check.button_pressed = (not preferences.values.muted) if setting_key == "sound" else bool(preferences.values[setting_key])
        check.add_theme_font_override("font",regular)
        check.add_theme_font_size_override("font_size",_font_size(15))
        check.add_theme_color_override("font_color",INK)
        check.add_theme_color_override("font_hover_color",GOLD)
        check.add_theme_color_override("font_pressed_color",INK)
        check.add_theme_color_override("font_hover_pressed_color",GOLD)
        check.add_theme_color_override("font_focus_color",INK)
        # 켜짐/꺼짐은 손잡이 위치로 구분하는 원본 스위치 재질을 쓴다.
        for icon_name in ["checked","checked_disabled","checked_mirrored","checked_disabled_mirrored"]:
            check.add_theme_icon_override(icon_name,art.texture("switch_on"))
        for icon_name in ["unchecked","unchecked_disabled","unchecked_mirrored","unchecked_disabled_mirrored"]:
            check.add_theme_icon_override(icon_name,art.texture("switch_off"))
        var row_style := StyleBoxEmpty.new()
        row_style.content_margin_left = 4
        row_style.content_margin_right = 2
        for style_state in ["normal","hover","pressed","hover_pressed","disabled"]:
            check.add_theme_stylebox_override(style_state,row_style)
        check.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,READY))
        check.custom_minimum_size.y = 48
        check.button_down.connect(func(): _button_feedback(check,.82))
        check.button_up.connect(func(): _button_feedback(check,1.0))
        check.mouse_exited.connect(func(): _button_feedback(check,1.0))
        modal_content.add_child(check)
        check.toggled.connect(_preference_toggled.bind(setting_key,check,epoch))
    settings_status = _make_label(preferences.warning if not preferences.warning.is_empty() else "효과음 음량은 10 단위로 바뀌어요",12,MUTED,false)
    settings_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    settings_status.custom_minimum_size.y = _font_size(12)*1.5
    modal_content.add_child(settings_status)
    _text_button("새 게임 시작",_new_run_dialog,INVALID)
    var close := _icon_button("icon_close",Rect2(0,0,48,48),_close_modal,"닫기")
    controls.remove_child(close)
    modal.add_child(close)
    modal.set_meta("close_button",close)
    _fit_modal()

func _volume_row(epoch: int) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",12)
    row.custom_minimum_size.y = 48
    var caption := _make_label("음량",15,INK,false)
    caption.custom_minimum_size.x = 60
    row.add_child(caption)
    volume_slider = HSlider.new()
    volume_slider.min_value = 0
    volume_slider.max_value = 100
    volume_slider.step = 10
    volume_slider.value = preferences.values.volume
    volume_slider.editable = not preferences.values.muted
    volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    volume_slider.custom_minimum_size.y = 32
    volume_slider.tooltip_text = "효과음 음량"
    volume_slider.accessibility_name = "효과음 음량"
    var track := StyleBoxFlat.new()
    track.bg_color = Color(0,0,0,.5)
    track.border_color = Color(0.914,0.839,0.706,.25)
    track.set_border_width_all(1)
    track.set_corner_radius_all(4)
    track.content_margin_top = 3
    track.content_margin_bottom = 3
    var filled := StyleBoxFlat.new()
    filled.bg_color = GOLD
    filled.set_corner_radius_all(4)
    filled.content_margin_top = 3
    filled.content_margin_bottom = 3
    volume_slider.add_theme_stylebox_override("slider",track)
    volume_slider.add_theme_stylebox_override("grabber_area",filled)
    volume_slider.add_theme_stylebox_override("grabber_area_highlight",filled)
    var slider := volume_slider
    slider.drag_ended.connect(func(_changed: bool):
        if _ui_callback_allowed(slider,epoch): feedback.cue("button"))
    slider.value_changed.connect(func(value: float):
        if not _ui_callback_allowed(slider,epoch): return
        if not preferences.update("volume",int(value)):
            slider.set_value_no_signal(preferences.values.volume)
            settings_status.text = "음량을 저장하지 못했어요.")
    row.add_child(slider)
    return row

func _preference_toggled(value: bool, key: String, check: CheckButton, epoch: int) -> void:
    if not _ui_callback_allowed(check,epoch): return
    feedback.cue("button")
    # 화면의 '효과음' 스위치는 저장 값 muted의 반대다.
    var stored_key := "muted" if key == "sound" else key
    var stored_value: bool = (not value) if key == "sound" else value
    if not preferences.update(stored_key,stored_value):
        check.set_pressed_no_signal(not value)
        settings_status.text = "설정을 저장하지 못했어요. 기존 값을 유지합니다."
    elif key == "sound":
        if is_instance_valid(volume_slider): volume_slider.editable = value
    elif key == "large_text":
        _close_modal()
        _layout()
        _settings()

func _new_run_dialog() -> void:
    if online_mode:
        _dialog("주간 도전 중", "이번 도전에서는 새 게임을 시작할 수 없습니다. 제출하거나 개인 탑으로 돌아가 주세요.", "확인", _close_modal, "")
        return
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    new_run_seed = str(rng.seed)
    _dialog("새 게임을 시작할까요?", "현재 보드와 점수는 초기화됩니다. 최고 기록과 탑은 유지됩니다.","새 게임 시작",_confirm_new,"취소",true)

func _confirm_new() -> void:
    _remove_modal()
    var result: Dictionary = controller.submit_modal("NEW_RUN",{"seed_text":new_run_seed,"confirmed":true})
    if result.ok:
        screen_id = "puzzle"
        _layout()

func _results() -> void:
    if online_mode:
        _dialog("주간 도전 종료", "도전 기록을 제출하면 검증된 층수만 순위에 반영됩니다.", "주간 기록", _request_online_from_modal, "닫기")
        return
    # 판이 이미 끝났으므로 '다시 하기'는 추가 확인 없이 확정된 NEW_RUN을 보낸다.
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    new_run_seed = str(rng.seed)
    _dialog("더 놓을 곳이 없어요", "쌓은 층은 그대로 남아요.","다시 하기",_confirm_new,"")
    var stats := HBoxContainer.new()
    stats.add_theme_constant_override("separation",8)
    stats.add_child(_stat_card("이번 점수",format_int(state.score),INK))
    stats.add_child(_stat_card("최고 기록",format_int(state.best),GOLD))

    modal_content.add_child(stats)
    modal_content.add_child(_tower_card())
    if not last_event_details.is_empty():
        modal_content.add_child(_wrapped_label("이번 결과 안내:\n"+"\n".join(last_event_details),13,MUTED,false))
    # 보조 동작은 한 줄에 나란히 두어 작은 화면에서도 결과 카드를 가리지 않는다.
    var secondary := HBoxContainer.new()
    secondary.add_theme_constant_override("separation",8)
    modal_actions.add_child(secondary)
    for entry in [["내 탑 보기",_results_to_tower],["보드 보기",_close_modal]]:
        var action := _button(entry[0],Rect2(0,0,size.x-48,48),entry[1])
        controls.remove_child(action)
        secondary.add_child(action)
        action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _fit_modal()

func _open_online() -> void:
    if controller.application_active and controller.phase == "idle": online_requested.emit()

func _request_online_from_modal() -> void:
    _close_modal()
    online_requested.emit()

func _stat_card(caption: String, value: String, color: Color) -> Control:
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel",art.panel("panel"))
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.custom_minimum_size.y = 84
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation",4)
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var top := _make_label(caption,13,MUTED,false)
    top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(top)
    var number := _make_label(value,26,color,true)
    number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var room := (size.x-56-8)/2-24
    var font_size := _font_size(26)
    while font_size > 9 and _text_width(value,font_size,true) > room: font_size -= 1
    number.add_theme_font_size_override("font_size",font_size)
    column.add_child(number)
    card.add_child(column)
    return card

func _tower_card() -> Control:
    var total: int = state.growth.total_floors
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel",art.panel("panel"))
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",14)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var picture := Control.new()
    picture.custom_minimum_size = Vector2(84,112)
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    picture.draw.connect(_draw_mini_tower.bind(picture,total))
    row.add_child(picture)
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation",6)
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(_make_label("내 탑 누적",13,MUTED,false))
    var floors := _make_label("%s층" % format_int(total),28,GOLD,true)
    var room := size.x-24-32-24-84-14
    var font_size := _font_size(28)
    while font_size > 10 and _text_width(floors.text,font_size,true) > room: font_size -= 1
    floors.add_theme_font_size_override("font_size",font_size)
    column.add_child(floors)
    if total == 0:
        column.add_child(_make_label("첫 줄을 클리어하면 탑이 자라요",12,MUTED,false))
    else:
        var bar := Control.new()
        bar.custom_minimum_size = Vector2(0,8)
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bar.draw.connect(_draw_progress.bind(bar,analysis.growth.partial_floors/10.0))
        column.add_child(bar)
        column.add_child(_make_label("다음 구간까지 %d층" % analysis.growth.floors_to_next,12,MUTED,false))
    row.add_child(column)
    card.add_child(row)
    return card

func _draw_mini_tower(canvas: Control, total: int) -> void:
    # 결과 카드는 실제 최상단 구간만 그린다. 그려진 층은 모두 획득한 층이다.
    var count := 0
    if total > 0:
        count = total % 10
        if count == 0: count = 10
    var entry := total > 0 and total <= 10
    var step: float = tower_geometry.floor_step
    var height := 232.0 if count == 0 else 276.0+count*step
    var s := minf(canvas.size.x/454.0,canvas.size.y/height)
    var rect := Rect2(Vector2(canvas.size.x/2-320*s,canvas.size.y-344*s),Vector2(640,480)*s)
    canvas.draw_texture_rect(tower_art.base,rect,false)
    for i in range(count):
        var part := "floor_wide" if i<3 else ("floor_mid" if i<6 else "floor_top")
        if i==0 and entry: part = "floor_entry"
        canvas.draw_texture_rect(tower_art[part],Rect2(rect.position-Vector2(0,i*step*s),rect.size),false)
    if count > 0:
        var cap := "roof_wide" if count<=3 else ("roof_mid" if count<=6 else "roof_top")
        canvas.draw_texture_rect(tower_art[cap],Rect2(rect.position-Vector2(0,count*step*s),rect.size),false)

func _results_to_tower() -> void:
    _remove_modal()
    controller.cancel()
    _open_tower()

func _open_tower() -> void:
    screen_id = "tower"
    selected_segment = maxi(1,state.growth.representative_segment)
    _layout()

func _show_selected_tower() -> void:
    screen_id = "tower"
    _layout()

func _open_tower_overview() -> void:
    screen_id = "tower_overview"
    _layout()

func _open_tower_focus() -> void:
    if state.growth.total_floors <= 0: return
    screen_id = "tower_focus"
    _layout()

func _overview_to_representative() -> void:
    selected_segment = maxi(1,int(state.growth.representative_segment))
    _show_selected_tower()

func _open_puzzle() -> void:
    screen_id = "puzzle"
    _layout()

func _maximum_tower_segment() -> int:
    return int(analysis.growth.completed_segments)+(1 if int(analysis.growth.partial_floors)>0 else 0)

func _make_segment_number_input(initial: int, accessible: String) -> LineEdit:
    var input := LineEdit.new()
    input.text = str(initial)
    input.placeholder_text = "구간 번호"
    input.max_length = 16
    input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
    input.custom_minimum_size.y = 48
    input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input.alignment = HORIZONTAL_ALIGNMENT_CENTER
    input.accessibility_name = accessible
    input.add_theme_font_override("font",regular)
    input.add_theme_font_size_override("font_size",_font_size(18))
    input.add_theme_color_override("font_color",INK)
    input.add_theme_color_override("font_placeholder_color",MUTED)
    input.add_theme_stylebox_override("normal",_style(Color("2d241d"),Color(GOLD,.55)))
    input.add_theme_stylebox_override("focus",_style(Color("2d241d"),READY))
    return input

func _show_segment_jump() -> void:
    var maximum := _maximum_tower_segment()
    if screen_id not in ["tower","tower_overview"] or maximum < 2 or not controller.application_active: return
    _dialog("구간 이동", "1~%s번 중 원하는 10층 구간을 입력하세요. 마지막 미완성 구간도 볼 수 있어요." % format_int(maximum), "이동", _confirm_segment_jump, "취소", true)
    segment_jump_input = _make_segment_number_input(selected_segment,"이동할 구간 번호")
    modal_content.add_child(segment_jump_input)
    segment_jump_status = _wrapped_label("구간 번호를 입력한 뒤 이동을 누르세요.",12,MUTED,false)
    modal_content.add_child(segment_jump_status)
    var input := segment_jump_input
    var epoch := _ui_epoch
    input.text_submitted.connect(func(_value: String):
        if _ui_callback_allowed(input,epoch): _confirm_segment_jump())
    _fit_modal()
    segment_jump_input.grab_focus()
    segment_jump_input.select_all()

func _confirm_segment_jump() -> void:
    if screen_id not in ["tower","tower_overview"] or controller.phase != "modal" or not is_instance_valid(segment_jump_input): return
    var raw := segment_jump_input.text.strip_edges()
    var maximum := _maximum_tower_segment()
    if not raw.is_valid_int() or raw.length() > 15 or raw.to_int() < 1 or raw.to_int() > maximum:
        segment_jump_status.text = "1~%s번 사이의 구간 번호를 입력하세요." % format_int(maximum)
        segment_jump_status.add_theme_color_override("font_color",INVALID)
        segment_jump_input.grab_focus()
        segment_jump_input.select_all()
        return
    var target := raw.to_int()
    _close_modal()
    selected_segment = target
    _show_selected_tower()

func _segment_appearance_text(segment: int, include_dormant: bool = false) -> String:
    var key := str(segment)
    var material := str(state.growth.segment_styles.get(key,"wood"))
    var result := _facade_label(material)
    var parts: Array = state.growth.segment_parts.get(key,[])
    if material == "brick":
        var names: Array[String] = []
        for part in parts: names.append(_part_name(str(part)))
        if not names.is_empty(): result += " · "+"+".join(names)
    elif include_dormant and not parts.is_empty():
        result += " · 숨긴 벽돌 파츠 %d개" % parts.size()
    return result

func _copy_target_matches(source: int, target: int) -> bool:
    var source_key := str(source)
    var target_key := str(target)
    var material := str(state.growth.segment_styles.get(source_key,"wood"))
    var source_parts: Array = state.growth.segment_parts.get(source_key,[]) if material == "brick" else []
    return state.growth.segment_styles.get(target_key,"wood") == material and state.growth.segment_parts.get(target_key,[]) == source_parts

func _refresh_segment_copy_preview() -> void:
    if not is_instance_valid(segment_copy_input) or not is_instance_valid(segment_copy_preview): return
    var raw := segment_copy_input.text.strip_edges()
    var completed := int(analysis.growth.completed_segments)
    segment_copy_preview.add_theme_color_override("font_color",MUTED)
    if not raw.is_valid_int() or raw.length()>15 or raw.to_int()<1 or raw.to_int()>completed:
        segment_copy_preview.text = "1~%s번 사이의 완성 구간을 입력하세요." % format_int(completed)
        segment_copy_preview.add_theme_color_override("font_color",INVALID)
    elif raw.to_int() == selected_segment:
        segment_copy_preview.text = "원본과 다른 구간을 선택하세요."
        segment_copy_preview.add_theme_color_override("font_color",INVALID)
    elif _copy_target_matches(selected_segment,raw.to_int()):
        segment_copy_preview.text = "대상 구간 %d은 이미 같은 외형입니다." % raw.to_int()
    else:
        segment_copy_preview.text = "대상 구간 %d: %s\n복사 후: %s\n대상의 기존 파츠 기록도 교체됩니다." % [raw.to_int(),_segment_appearance_text(raw.to_int(),true),_segment_appearance_text(selected_segment)]
    var preview_font_size := _font_size(13)
    var preview_height := regular.get_multiline_string_size(segment_copy_preview.text,HORIZONTAL_ALIGNMENT_LEFT,size.x-56,preview_font_size).y
    segment_copy_preview.custom_minimum_size.y = maxf(preview_font_size*2.5,preview_height+12)
    _fit_modal()

func _show_segment_copy() -> void:
    var completed := int(analysis.growth.completed_segments)
    if screen_id != "tower" or selected_segment>completed or completed<2 or not controller.application_active: return
    _dialog("구간 외형 복사", "구간 %d의 %s 외형을 완성된 다른 구간에 복사합니다." % [selected_segment,_segment_appearance_text(selected_segment)], "복사", _confirm_segment_copy, "취소", true)
    var default_target := 2 if selected_segment == 1 else 1
    segment_copy_input = _make_segment_number_input(default_target,"외형을 받을 완성 구간 번호")
    modal_content.add_child(segment_copy_input)
    segment_copy_preview = _wrapped_label("대상 구간의 외형과 복사 후 외형을 확인하세요.\n대상의 기존 파츠 기록도 교체됩니다.",13,MUTED,false)
    segment_copy_preview.custom_minimum_size.y = maxf(segment_copy_preview.custom_minimum_size.y,_font_size(13)*4.6)
    modal_content.add_child(segment_copy_preview)
    var input := segment_copy_input
    var epoch := _ui_epoch
    input.text_changed.connect(func(_value: String):
        if _ui_callback_allowed(input,epoch): _refresh_segment_copy_preview())
    input.text_submitted.connect(func(_value: String):
        if _ui_callback_allowed(input,epoch): _confirm_segment_copy())
    _refresh_segment_copy_preview()
    _fit_modal()
    segment_copy_input.grab_focus()
    segment_copy_input.select_all()

func _confirm_segment_copy() -> void:
    if screen_id != "tower" or controller.phase != "modal" or not is_instance_valid(segment_copy_input): return
    var raw := segment_copy_input.text.strip_edges()
    var completed := int(analysis.growth.completed_segments)
    if not raw.is_valid_int() or raw.length()>15 or raw.to_int()<1 or raw.to_int()>completed or raw.to_int()==selected_segment or _copy_target_matches(selected_segment,raw.to_int()):
        _refresh_segment_copy_preview()
        segment_copy_input.grab_focus()
        segment_copy_input.select_all()
        return
    var target := raw.to_int()
    var result: Dictionary = controller.submit_modal("COPY_SEGMENT_APPEARANCE",{"source":selected_segment,"target":target,"confirmed":true})
    if result.ok:
        selected_segment = target
        _show_selected_tower()

func _build_tower_focus() -> void:
    var insets := _safe_vertical()
    var bottom := size.y-insets.y
    var maximum := _maximum_tower_segment()
    var title := _label("구간 %s / %s 확대" % [format_int(selected_segment),format_int(maximum)],Rect2(18,insets.x+62,size.x-116,40),20)
    var title_size := _font_size(20)
    while title_size>13 and _text_width(title.text,title_size,true)>title.size.x: title_size -= 1
    title.add_theme_font_size_override("font_size",title_size)
    title.add_theme_stylebox_override("normal",_style(Color(0.15,0.10,0.07,0.85),Color(GOLD,0.4)))
    _button("닫기",Rect2(size.x-82,insets.x+56,64,48),_show_selected_tower)
    var previous := _button("이전",Rect2(18,bottom-58,64,48),func(): selected_segment=maxi(1,selected_segment-1);_layout())
    previous.disabled = selected_segment<=1
    var appearance := "미완성 · %d/10층" % int(analysis.growth.partial_floors) if selected_segment>int(analysis.growth.completed_segments) else _facade_label(tower_segment_style())
    var visible_parts: Array = state.growth.segment_parts.get(str(selected_segment),[])
    if tower_segment_style()=="brick" and not visible_parts.is_empty(): appearance += " · 장식 %d개" % visible_parts.size()
    var caption := _label("구간 %s / %s\n%s" % [format_int(selected_segment),format_int(maximum),appearance],Rect2(90,bottom-70,size.x-180,60),12)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    caption.accessibility_name = caption.text
    caption.add_theme_stylebox_override("normal",_style(Color(0.15,0.10,0.07,0.85),Color(GOLD,0.4)))
    var next := _button("다음",Rect2(size.x-82,bottom-58,64,48),func(): selected_segment=mini(maximum,selected_segment+1);_layout())
    next.disabled = selected_segment>=maximum

func _build_tower() -> void:
    var total: int = state.growth.total_floors
    var insets := _safe_vertical()
    var bottom := size.y-insets.y
    var maximum_segment := _maximum_tower_segment()
    _label("내가 쌓은 탑",Rect2(18,insets.x+62,size.x-(158 if maximum_segment>1 else 36),38),22)
    if maximum_segment > 1:
        var jump := _button("구간 이동",Rect2(size.x-126,insets.x+56,108,48),_show_segment_jump)
        jump.accessibility_name = "원하는 10층 구간으로 이동"
    _label("누적 %s층" % format_int(total),Rect2(18,insets.x+104,size.x-36,42),28,GOLD)
    var desc := "첫 줄을 클리어하면 탑이 자라요" if total==0 else "%s개 구간 완성 · 다음 구간까지 %d층" % [str(analysis.growth.completed_segments),analysis.growth.floors_to_next]
    if total > 0:
        var complete_count := int(analysis.growth.completed_segments)
        if selected_segment > complete_count:
            desc = "미완성 구간 · %d/10층 · 완성 후 외벽 편집" % int(analysis.growth.partial_floors)
        else:
            var selected_style := str(state.growth.segment_styles.get(str(selected_segment),"wood"))
            if selected_style in ["metal","crystal"]:
                desc = _tower_style_status(selected_style)
            elif "metal" not in analysis.growth.materials and "brick" in analysis.growth.materials:
                desc = "금속·유리 잠김 · 동시 3줄 제거 또는 누적 100층"
            elif "brick" not in analysis.growth.materials:
                desc = "벽돌 잠김 · 동시 2줄 제거 또는 누적 30층"
    _label(desc,Rect2(18,insets.x+152,size.x-36,32),12,MUTED)
    _button("퍼즐로 돌아가기",Rect2(18,bottom-48,size.x-36,48),_open_puzzle,true)
    if total > 0:
        var complete: bool = selected_segment <= int(analysis.growth.completed_segments)
        var previous := _button("이전",Rect2(18,bottom-210,64,48),func(): selected_segment=maxi(1,selected_segment-1);_layout())
        previous.disabled = selected_segment <= 1
        var raw_style := str(state.growth.segment_styles.get(str(selected_segment),"wood"))
        var caption := "현재 목재" if raw_style == "wood" else ("현재 벽돌" if raw_style == "brick" else ("현재 금속·유리" if raw_style == "metal" else ("현재 크리스털" if raw_style == "crystal" else "현재 목재")))
        var selected_parts: Array = state.growth.segment_parts.get(str(selected_segment),[])
        var visible_parts: Array[String] = []
        if raw_style == "brick":
            if "brick_arch_window" in selected_parts: visible_parts.append("아치 창문")
            if "brick_terrace" in selected_parts: visible_parts.append("테라스")
            if "brick_cornice" in selected_parts: visible_parts.append("상단 장식")
            if "brick_landmark" in selected_parts: visible_parts.append("랜드마크")
            if not visible_parts.is_empty(): caption += " · "+"+".join(visible_parts)
        var selected_caption := "구간 %s / %s\n%s" % [str(selected_segment),str(maximum_segment),caption]
        var two_part_caption_height := 60.0
        if raw_style == "brick" and selected_parts.size() == 2:
            var joined_part_names := "+".join(visible_parts)
            selected_caption = "구간 %s / %s\n현재 벽돌 ·\n%s" % [str(selected_segment),str(maximum_segment),joined_part_names]
            if _text_width(joined_part_names,_font_size(12),false) > size.x-180:
                selected_caption = "구간 %s / %s\n현재 벽돌\n%s\n%s" % [str(selected_segment),str(maximum_segment),visible_parts[0],visible_parts[1]]
                two_part_caption_height = 72.0
        var multi_part_caption_height := 60.0
        if raw_style == "brick" and selected_parts.size() >= 3:
            var part_lines: Array[String] = []
            var current_line := ""
            var available_part_width := size.x-180
            for part_name in visible_parts:
                var candidate := part_name if current_line.is_empty() else current_line+"·"+part_name
                if not current_line.is_empty() and _text_width(candidate,_font_size(12),false)>available_part_width:
                    part_lines.append(current_line)
                    current_line = part_name
                else:
                    current_line = candidate
            if not current_line.is_empty(): part_lines.append(current_line)
            var parts_copy := "\n".join(part_lines)
            selected_caption = "구간 %s/%s · 벽돌\n%s" % [str(selected_segment),str(maximum_segment),parts_copy]
            multi_part_caption_height = 48.0+24.0*float(part_lines.size())
        if not complete: selected_caption = "구간 %s / %s\n미완성" % [str(selected_segment),str(maximum_segment)]
        var caption_rect := Rect2(90,bottom-210,size.x-180,48)
        if raw_style == "brick" and selected_parts.size() == 2: caption_rect = Rect2(90,bottom-218-(two_part_caption_height-48.0),size.x-180,two_part_caption_height)
        elif raw_style == "brick" and selected_parts.size() >= 3: caption_rect = Rect2(90,bottom-210-(multi_part_caption_height-48.0),size.x-180,multi_part_caption_height)
        var selected_caption_label := _label(selected_caption,caption_rect,12)
        selected_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        selected_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        selected_caption_label.accessibility_name = selected_caption
        var next := _button("다음",Rect2(size.x-82,bottom-210,64,48),func(): selected_segment=mini(maximum_segment,selected_segment+1);_layout())
        next.disabled = selected_segment >= maximum_segment
        var facade_choice := _button("외벽 선택" if complete else "10층 완성 후 외벽 선택",
            Rect2(18,bottom-154,size.x-36,48),_show_facade_sheet)
        facade_choice.disabled = not complete
        facade_choice.accessibility_name = "구간 %d 외벽 선택: %s" % [selected_segment,_tower_style_status(raw_style)]
        var third := (size.x-52)/3.0
        var representative := _button("대표 구간" if selected_segment==state.growth.representative_segment else "대표 지정",
            Rect2(18,bottom-98,third,48),func(): controller.submit("SET_REPRESENTATIVE",{"segment":selected_segment}))
        representative.disabled = not complete or selected_segment==state.growth.representative_segment
        representative.accessibility_name = "구간 %d 대표 구간으로 선택" % selected_segment
        var copy := _button("복사",Rect2(26+third,bottom-98,third,48),_show_segment_copy)
        copy.disabled = not complete or int(analysis.growth.completed_segments)<2
        copy.accessibility_name = "구간 %d 외형을 다른 구간에 복사" % selected_segment
        var overview := _button("전체 탑",Rect2(34+third*2,bottom-98,third,48),_open_tower_overview)
        overview.accessibility_name = "전체 탑 감상"
        var focus := _button("확대",Rect2(size.x-82,insets.x+188,64,48),_open_tower_focus)
        focus.accessibility_name = "선택한 10층 구간 확대 보기"
        for action_button in [representative,copy,overview]:
            var action_font: int = action_button.get_theme_font_size("font_size")
            while action_font>11 and _text_width(action_button.text,action_font,true)>third-18: action_font -= 1
            action_button.add_theme_font_size_override("font_size",action_font)

func _overview_floor_counts() -> Dictionary:
    var completed: int = int(analysis.growth.completed_segments)
    var partial: int = int(analysis.growth.partial_floors)
    var counts := {"wood":completed*10+partial,"brick":0,"metal":0,"crystal":0}
    for value in state.growth.segment_styles.values():
        var material := str(value)
        if material in ["brick","metal","crystal"]:
            counts.wood -= 10
            counts[material] += 10
    return counts

func _overview_material_share(count: int, total: int) -> String:
    if count <= 0: return "0%"
    var share := count*100.0/float(maxi(1,total))
    if share < 0.1: return "0.1% 미만"
    return "%.1f%%" % share

func _overview_plot_rect() -> Rect2:
    var insets := _safe_vertical()
    var top := insets.x+236.0
    var bottom := size.y-insets.y-202.0
    return Rect2((size.x-150.0)/2.0,top,150.0,maxf(64.0,bottom-top))

func _build_tower_overview() -> void:
    var insets := _safe_vertical()
    var bottom := size.y-insets.y
    var maximum := _maximum_tower_segment()
    _label("전체 탑",Rect2(18,insets.x+62,size.x-158,38),22)
    if maximum > 1:
        var jump := _button("구간 이동",Rect2(size.x-126,insets.x+56,108,48),_show_segment_jump)
        jump.accessibility_name = "원하는 10층 구간으로 이동"
    var floors := _label("누적 %s층" % format_int(int(state.growth.total_floors)),Rect2(18,insets.x+104,size.x-36,42),28,GOLD)
    var heading_size := _font_size(28)
    while heading_size > 15 and _text_width(floors.text,heading_size,true)>floors.size.x: heading_size -= 1
    floors.add_theme_font_size_override("font_size",heading_size)
    var best := "완성 %s구간 · 진행 %d/10층 · 최고 %s점" % [format_int(int(analysis.growth.completed_segments)),int(analysis.growth.partial_floors),format_int(int(state.best))]
    var best_label := _label(best,Rect2(18,insets.x+150,size.x-36,46),12,MUTED)
    best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    best_label.accessibility_name = best
    var diagram_note := _label("구간 축약 보기 · 금색 현재 / 원형 대표",Rect2(18,insets.x+194,size.x-36,20),11,MUTED)
    diagram_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var shares := _overview_floor_counts()
    var total: int = maxi(1,int(state.growth.total_floors))
    var share_text := "외벽 비중  목재 %s · 벽돌 %s\n금속·유리 %s · 크리스털 %s" % [_overview_material_share(shares.wood,total),_overview_material_share(shares.brick,total),_overview_material_share(shares.metal,total),_overview_material_share(shares.crystal,total)]
    var share_label := _label(share_text,Rect2(18,bottom-194,size.x-36,46),12,INK)
    share_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    share_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    share_label.accessibility_name = share_text+". 비율은 실제 누적 층수 기준입니다."
    var representative := _button("대표 구간 보기",Rect2(18,bottom-144,size.x-36,48),_overview_to_representative)
    representative.disabled = int(state.growth.representative_segment)==0
    representative.accessibility_name = "대표 구간 %d 보기" % int(state.growth.representative_segment)
    _button("선택 구간 보기",Rect2(18,bottom-96,size.x-36,48),_show_selected_tower)
    _button("퍼즐로 돌아가기",Rect2(18,bottom-48,size.x-36,48),_open_puzzle,true)

func _facade_label(material: String) -> String:
    match material:
        "brick": return "벽돌"
        "metal": return "금속·유리"
        "crystal": return "크리스털"
        _: return "목재"

func _show_facade_sheet() -> void:
    if selected_segment > analysis.growth.completed_segments: return
    var stored_style := str(state.growth.segment_styles.get(str(selected_segment),"wood"))
    var details := "현재 적용: "+_facade_label(stored_style)
    details += "\n벽돌: 동시 2줄 제거 또는 누적 30층."
    details += "\n벽돌 아치 창문: 벽돌 10줄 또는 누적 60층."
    details += "\n벽돌 테라스: 벽돌 30줄 또는 누적 120층."
    details += "\n벽돌 상단 장식: 벽돌 60줄 또는 누적 200층."
    details += "\n벽돌 랜드마크: 벽돌 100줄 또는 누적 300층."
    details += "\n금속·유리: 동시 3줄 제거 또는 누적 100층."
    details += "\n크리스털: 동시 4줄 제거 또는 누적 250층."
    _dialog("구간 %d 외벽 선택" % selected_segment,details,"닫기",_close_modal,"")
    var focus_target: Control
    for material in ["wood","brick","metal","crystal"]:
        var unlocked: bool = material in analysis.growth.materials
        var current: bool = stored_style == material
        var label := "현재 · "+_facade_label(material) if current else _facade_label(material)+(" 적용" if unlocked else " · 잠김")
        var option := _button(label,Rect2(0,0,size.x-48,48),_apply_facade_choice.bind(material))
        controls.remove_child(option)
        modal_content.add_child(option)
        option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        option.custom_minimum_size.y = 48
        option.disabled = not unlocked or current
        option.accessibility_name = label
        if not option.disabled and focus_target == null: focus_target = option
    var segment_key := str(selected_segment)
    var arch_equipped: bool = "brick_arch_window" in state.growth.segment_parts.get(segment_key,[])
    var arch_unlocked: bool = "brick_arch_window" in analysis.growth.parts
    var arch_status := "벽돌 아치 창문 · 잠김" if not arch_unlocked else ("아치 창문 장착 · 해제" if arch_equipped and stored_style == "brick" else ("아치 창문 숨김 · 해제" if arch_equipped else ("벽돌 아치 창문 장착" if stored_style == "brick" else "아치 창문 · 벽돌 필요")))
    var arch_button := _button(arch_status,Rect2(0,0,size.x-48,48),_apply_segment_part.bind("brick_arch_window",not arch_equipped))
    controls.remove_child(arch_button)
    modal_content.add_child(arch_button)
    arch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    arch_button.custom_minimum_size.y = 48
    arch_button.disabled = (not arch_unlocked and not arch_equipped) or (not arch_equipped and stored_style != "brick")
    arch_button.accessibility_name = arch_status
    if not arch_button.disabled and focus_target == null: focus_target = arch_button
    var terrace_equipped: bool = "brick_terrace" in state.growth.segment_parts.get(segment_key,[])
    var terrace_unlocked: bool = "brick_terrace" in analysis.growth.parts
    var terrace_status := "벽돌 테라스 · 잠김" if not terrace_unlocked else ("테라스 장착 · 해제" if terrace_equipped and stored_style == "brick" else ("테라스 숨김 · 해제" if terrace_equipped else ("벽돌 테라스 장착" if stored_style == "brick" else "테라스 · 벽돌 필요")))
    var terrace_button := _button(terrace_status,Rect2(0,0,size.x-48,48),_apply_segment_part.bind("brick_terrace",not terrace_equipped))
    controls.remove_child(terrace_button)
    modal_content.add_child(terrace_button)
    terrace_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    terrace_button.custom_minimum_size.y = 48
    terrace_button.disabled = (not terrace_unlocked and not terrace_equipped) or (not terrace_equipped and stored_style != "brick")
    terrace_button.accessibility_name = terrace_status
    if not terrace_button.disabled and focus_target == null: focus_target = terrace_button
    var cornice_equipped: bool = "brick_cornice" in state.growth.segment_parts.get(segment_key,[])
    var cornice_unlocked: bool = "brick_cornice" in analysis.growth.parts
    var cornice_status := "벽돌 상단 장식 · 잠김" if not cornice_unlocked else ("상단 장식 장착 · 해제" if cornice_equipped and stored_style == "brick" else ("상단 장식 숨김 · 해제" if cornice_equipped else ("벽돌 상단 장식 장착" if stored_style == "brick" else "상단 장식 · 벽돌 필요")))
    var cornice_button := _button(cornice_status,Rect2(0,0,size.x-48,48),_apply_segment_part.bind("brick_cornice",not cornice_equipped))
    controls.remove_child(cornice_button)
    modal_content.add_child(cornice_button)
    cornice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cornice_button.custom_minimum_size.y = 48
    cornice_button.disabled = (not cornice_unlocked and not cornice_equipped) or (not cornice_equipped and stored_style != "brick")
    cornice_button.accessibility_name = cornice_status
    if not cornice_button.disabled and focus_target == null: focus_target = cornice_button
    var landmark_equipped: bool = "brick_landmark" in state.growth.segment_parts.get(segment_key,[])
    var landmark_unlocked: bool = "brick_landmark" in analysis.growth.parts
    var landmark_status := "벽돌 랜드마크 · 잠김" if not landmark_unlocked else ("랜드마크 장착 · 해제" if landmark_equipped and stored_style == "brick" else ("랜드마크 숨김 · 해제" if landmark_equipped else ("벽돌 랜드마크 장착" if stored_style == "brick" else "랜드마크 · 벽돌 필요")))
    var landmark_button := _button(landmark_status,Rect2(0,0,size.x-48,48),_apply_segment_part.bind("brick_landmark",not landmark_equipped))
    controls.remove_child(landmark_button)
    modal_content.add_child(landmark_button)
    landmark_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    landmark_button.custom_minimum_size.y = 48
    landmark_button.disabled = (not landmark_unlocked and not landmark_equipped) or (not landmark_equipped and stored_style != "brick")
    landmark_button.accessibility_name = landmark_status
    if not landmark_button.disabled and focus_target == null: focus_target = landmark_button
    _fit_modal()
    if focus_target != null: focus_target.grab_focus()

func _apply_segment_part(part: String, enabled: bool) -> void:
    controller.submit_modal("SET_SEGMENT_PART",{"segment":selected_segment,"part":part,"enabled":enabled})

func _apply_facade_choice(material: String) -> void:
    if material not in ["wood","brick","metal","crystal"] or selected_segment > analysis.growth.completed_segments: return
    if material not in analysis.growth.materials or str(state.growth.segment_styles.get(str(selected_segment),"wood")) == material: return
    controller.submit_modal("SET_SEGMENT_STYLE",{"segment":selected_segment,"material":material})

func _tower_style_status(raw_style: String) -> String:
    match raw_style:
        "brick": return "현재 외벽: 벽돌"
        "metal": return "현재 외벽: 금속·유리"
        "crystal": return "현재 외벽: 크리스털"
        _: return "현재 외벽: 목재"

func _set_tower_style(material: String) -> void:
    if selected_segment > analysis.growth.completed_segments or material not in ["wood","brick","metal","crystal"]: return
    if material not in analysis.growth.materials or str(state.growth.segment_styles.get(str(selected_segment),"wood")) == material: return
    controller.submit("SET_SEGMENT_STYLE",{"segment":selected_segment,"material":material})

func tower_segment_style(segment: int = -1) -> String:
    var target := selected_segment if segment < 1 else segment
    var stored := str(state.growth.segment_styles.get(str(target),"wood"))
    return stored if stored in ["wood","brick","metal","crystal"] else "wood"

func tower_segment_view() -> Dictionary:
    var floors: int = state.growth.total_floors
    var start := (selected_segment-1)*10
    var count := clampi(floors-start,0,10)
    return {"count":count,"roof":count>0 and start+count==floors}

func tower_landmark_key() -> String:
    var selected_parts: Array = state.growth.segment_parts.get(str(selected_segment),[])
    if tower_segment_style()=="brick" and "brick_landmark" in selected_parts:
        return "brick_arch_landmark_floor_mid" if "brick_arch_window" in selected_parts else "brick_landmark_floor_mid"
    return ""

func tower_cap_key() -> String:
    var segment := tower_segment_view()
    var count: int = segment.count
    var cap := ("roof_wide" if count<=3 else ("roof_mid" if count<=6 else "roof_top")) if segment.roof else "cornice"
    var selected_parts: Array = state.growth.segment_parts.get(str(selected_segment),[])
    if tower_segment_style() == "brick" and "brick_cornice" in selected_parts:
        cap = ("brick_cornice_roof_wide" if count<=3 else ("brick_cornice_roof_mid" if count<=6 else "brick_cornice_roof_top")) if segment.roof else "brick_cornice"
    return cap

func _draw_tower_overview(canvas: Control) -> void:
    var plot := _overview_plot_rect()
    canvas.draw_style_box(_style(Color("291f19"),Color(GOLD,.65),10),plot.grow(8))
    var maximum := _maximum_tower_segment()
    if maximum <= 0: return
    # 3,000층 이상에서도 구간당 노드나 층 그림을 만들지 않고 고정 수의 띠로 축약한다.
    var bands := mini(maximum,OVERVIEW_BANDS)
    var band_height := plot.size.y/float(bands)
    var colors := {"wood":Color("bc8e66"),"brick":Color("a8654c"),"metal":Color("8ba7a6"),"crystal":Color("a9a6d7")}
    var completed := int(analysis.growth.completed_segments)
    for i in range(bands):
        var segment := mini(maximum,1+floori((float(i)+0.5)*float(maximum)/float(bands)))
        var material := "wood" if segment > completed else str(state.growth.segment_styles.get(str(segment),"wood"))
        var band_color: Color = colors.get(material,colors.wood)
        if i%2 == 1: band_color = band_color.darkened(.09)
        var width := lerpf(118.0,92.0,float(i)/maxf(1.0,float(bands-1)))
        var band := Rect2(plot.get_center().x-width/2.0,plot.end.y-(i+1)*band_height,width,band_height+0.8)
        canvas.draw_rect(band,band_color)
        if bands <= 12 or i%8 == 0:
            canvas.draw_line(Vector2(band.position.x,band.position.y),Vector2(band.end.x,band.position.y),Color("ead2a7",.54),1.0)
    canvas.draw_rect(Rect2(plot.get_center().x-68,plot.end.y,136,6),Color("b99a6c"))
    canvas.draw_rect(Rect2(plot.get_center().x-51,plot.position.y-7,102,7),Color("dfc999"))
    var selected_y := plot.end.y-(float(selected_segment)-0.5)*plot.size.y/float(maximum)
    canvas.draw_line(Vector2(plot.position.x-12,selected_y),Vector2(plot.end.x+12,selected_y),GOLD,3.0)
    var representative := int(state.growth.representative_segment)
    if representative > 0:
        var representative_y := plot.end.y-(float(representative)-0.5)*plot.size.y/float(maximum)
        canvas.draw_circle(Vector2(plot.position.x-15,representative_y),5,READY)

func _draw_tower(canvas: Control) -> void:
    var floors: int = state.growth.total_floors
    if floors == 0: return
    # 고층도 표시 노드는 제한한다. 누적 층수는 위의 정확한 숫자로 전달한다.
    var segment := tower_segment_view()
    var count: int = segment.count
    var insets := _safe_vertical()
    var selected_parts: Array = state.growth.segment_parts.get(str(selected_segment),[])
    var landmark_caption_lift := 16.0 if tower_segment_style() == "brick" and selected_parts.size() >= 2 else 0.0
    var focus_bottom_space := maxf(104.0,size.y*0.16)
    var base_y := size.y-insets.y-(focus_bottom_space if screen_id=="tower_focus" else 245.0)-landmark_caption_lift
    var available := base_y-(insets.x+112.0) if screen_id=="tower_focus" else base_y-210+landmark_caption_lift
    var floor_step: float = tower_geometry.floor_step
    var scale_factor := minf(size.x/470,available/(count*floor_step+205))
    var anchor := Vector2(size.x/2,base_y)
    var rect := Rect2(anchor-Vector2(320,240)*scale_factor,Vector2(640,480)*scale_factor)
    canvas.draw_texture_rect(tower_art.base,rect,false)
    for i in range(count):
        var part := "floor_wide" if i<3 else ("floor_mid" if i<6 else "floor_top")
        if i==0 and selected_segment==1: part = "floor_entry"
        var style := tower_segment_style()
        if style == "brick" and i == 4 and not tower_landmark_key().is_empty():
            part = tower_landmark_key()
        elif style == "brick" and i == 0 and "brick_terrace" in selected_parts:
            var terrace_suffix := "entry" if selected_segment == 1 else "wide"
            part = "brick_arch_terrace_"+terrace_suffix if "brick_arch_window" in selected_parts else "brick_terrace_"+terrace_suffix
        elif style == "brick" and "brick_arch_window" in selected_parts: part = "brick_arch_"+part
        elif style in ["brick","metal","crystal"]: part = style+"_"+part
        canvas.draw_texture_rect(tower_art[part],Rect2(rect.position-Vector2(0,i*floor_step*scale_factor),rect.size),false)
    var cap := tower_cap_key()
    canvas.draw_texture_rect(tower_art[cap],Rect2(rect.position-Vector2(0,count*floor_step*scale_factor),rect.size),false)
