extends SceneTree
## 격리된 실제 파일 세션과 네이티브 렌더링으로 W4 상태/입력을 검증한다.
const Session = preload("res://scripts/core/game_session.gd")
const Repository = preload("res://scripts/persistence/file_save_repository.gd")
const Screen = preload("res://scripts/presentation/puzzle_screen.gd")
const InsetScreen = preload("res://tests/integration/inset_puzzle_screen.gd")
var args: PackedStringArray
var screen: Control
var checks: Array = []

func _mouse(at: Vector2, pressed: bool):
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = at
    event.pressed = pressed
    Input.parse_input_event(event)

func _touch(id: int, at: Vector2, pressed: bool):
    var event := InputEventScreenTouch.new()
    event.index = id
    event.position = at
    event.pressed = pressed
    Input.parse_input_event(event)

func _initialize():
    args = OS.get_cmdline_user_args()
    _run.call_deferred()

func check(value: bool, name: String):
    checks.append({"check":name,"passed":value})

func _grayscale_image(image: Image) -> void:
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var pixel := image.get_pixel(x,y)
            var luminance := pixel.get_luminance()
            image.set_pixel(x,y,Color(luminance,luminance,luminance,pixel.a))

func _count_nodes(node: Node) -> int:
    var total := 1
    for child in node.get_children(): total += _count_nodes(child)
    return total

func _run():
    if args.size()<4:
        quit(2)
        return
    var capture_name := args[0]
    var variants := capture_name.split("_")
    var large_text_case: bool = "text" in variants
    var grayscale_case: bool = "gray" in variants
    var inset_case: bool = "inset" in variants or capture_name == "inset"
    var reduced_motion_case: bool = "reduced" in variants
    var mode := capture_name
    while mode.begins_with("gray_") or mode.begins_with("inset_") or mode.begins_with("text_") or mode.begins_with("reduced_"):
        if mode.begins_with("gray_"): mode = mode.trim_prefix("gray_")
        elif mode.begins_with("inset_"): mode = mode.trim_prefix("inset_")
        elif mode.begins_with("text_"): mode = mode.trim_prefix("text_")
        elif mode.begins_with("reduced_"): mode = mode.trim_prefix("reduced_")
    if mode == "inset": mode = "basic"
    var directory := args[1]
    var output := args[2]
    var dimensions := args[3].split("x")
    root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
    root.content_scale_size = root.size
    var opened: Dictionary = Repository.open(directory)
    if not opened.ok:
        quit(3)
        return
    var repo = opened.repository
    var loaded: Dictionary = repo.load_snapshot()
    var session
    if loaded.found:
        session = Session.resume(repo).session
    else:
        session = Session.start(repo,"w4-native-probe","20260921").session
        var state: Dictionary = session.snapshot()
        state.queue = ["square2_v0","single_v0","line3_h_v0"]
        # 정식 카탈로그의 실제 조각 ID를 사용한다.
        state.queue[2] = session._generator.catalog()[5].id
        for i in [0,1,2,8,9,16,24,25,34,35,43,50,51,57]:
            state.occupancy[i] = 1
            state.cell_style[i] = (i%6)+1
        if mode in ["cross","pending","clear","modal","max","tower","anticipation","sweep","shrink","motion","clear_pick","lifecycle","event_9_11","event_19_21","event_multi16"]:
            for i in range(8):
                state.occupancy[3*8+i] = 1
                state.occupancy[i*8+5] = 1
                state.cell_style[3*8+i] = 2
                state.cell_style[i*8+5] = 3
            state.growth.total_floors = 9
        if mode in ["event_9_11","event_19_21"]:
            state.growth.total_floors = 9 if mode == "event_9_11" else 19
            state.growth.representative_segment = 0 if mode == "event_9_11" else 1
        if mode == "event_multi16":
            state.occupancy.fill(1)
            state.cell_style.fill(1)
            state.growth.total_floors = 9
        if mode == "max":
            state.occupancy.fill(1)
            state.cell_style.fill(1)
        if mode in ["tower","tower_top"]:
            state.growth.total_floors = 13
            state.growth.representative_segment = 1
        if mode.begins_with("tower_") and mode.trim_prefix("tower_").is_valid_int():
            state.growth.total_floors = int(mode.trim_prefix("tower_"))
            state.growth.representative_segment = 1 if state.growth.total_floors>=10 else 0
        if mode in ["tower_brick","tower_wood","tower_locked","tower_partial","tower_legacy","tower_style_probe","facade_sheet_locked","facade_sheet_unlocked","facade_sheet_legacy","facade_partial","facade_style_probe","facade_crystal_locked","facade_crystal_unlocked","facade_crystal_scrolled","facade_crystal_legacy","facade_part_locked","facade_part_unlocked","facade_part_scrolled","facade_part_dormant","facade_part_probe","tower_brick_arch","facade_part_terrace_locked","facade_part_terrace_unlocked","facade_part_terrace_scrolled","facade_part_terrace_dormant","facade_part_terrace_probe","tower_brick_terrace","tower_brick_arch_terrace","facade_part_cornice_locked","facade_part_cornice_dormant","facade_part_cornice_unlocked","facade_part_cornice_scrolled","facade_part_cornice_probe","tower_brick_cornice_horizontal","tower_brick_cornice_roof","tower_brick_all_parts","tower_brick_arch_cornice","tower_brick_terrace_cornice","facade_part_landmark_locked","facade_part_landmark_unlocked","facade_part_landmark_scrolled","facade_part_landmark_dormant","facade_part_landmark_probe","tower_brick_landmark","tower_brick_arch_landmark","tower_brick_all_parts_landmark"]:
            if mode in ["tower_partial","facade_partial"]: state.growth.total_floors = 13
            elif mode in ["facade_part_landmark_unlocked","facade_part_landmark_scrolled","facade_part_landmark_probe","facade_part_landmark_dormant","tower_brick_landmark","tower_brick_arch_landmark","tower_brick_all_parts_landmark"]: state.growth.total_floors = 300
            elif mode == "facade_part_landmark_locked": state.growth.total_floors = 30
            elif mode in ["facade_part_cornice_unlocked","facade_part_cornice_scrolled","facade_part_cornice_probe","tower_brick_cornice_horizontal","tower_brick_cornice_roof","tower_brick_all_parts","tower_brick_arch_cornice","tower_brick_terrace_cornice"]: state.growth.total_floors = 205 if mode == "tower_brick_cornice_horizontal" else 200
            elif mode in ["facade_part_terrace_unlocked","facade_part_terrace_scrolled","facade_part_terrace_dormant","facade_part_terrace_probe","tower_brick_terrace","tower_brick_arch_terrace"]: state.growth.total_floors = 120
            elif mode in ["facade_crystal_unlocked","facade_crystal_scrolled","facade_crystal_legacy"]: state.growth.total_floors = 260
            elif mode in ["facade_part_locked","facade_part_terrace_locked"]: state.growth.total_floors = 30
            elif mode in ["facade_part_dormant","facade_part_probe","tower_brick_arch"]: state.growth.total_floors = 100
            elif mode in ["facade_part_unlocked","facade_part_scrolled"]: state.growth.total_floors = 60
            else: state.growth.total_floors = 20
            state.growth.representative_segment = 1
            state.growth.brick_lines = 3 if mode in ["facade_sheet_unlocked","facade_sheet_legacy","facade_style_probe"] else (0 if mode == "tower_locked" else 2)
            if mode in ["facade_part_landmark_unlocked","facade_part_landmark_scrolled","facade_part_landmark_probe","facade_part_landmark_dormant","tower_brick_landmark","tower_brick_arch_landmark","tower_brick_all_parts_landmark"]: state.growth.brick_lines = 100
            if mode in ["facade_part_cornice_unlocked","facade_part_cornice_scrolled","facade_part_cornice_probe","tower_brick_cornice_horizontal","tower_brick_cornice_roof","tower_brick_all_parts","tower_brick_arch_cornice","tower_brick_terrace_cornice"]: state.growth.brick_lines = 60
            if mode == "tower_brick": state.growth.segment_styles = {"2":"brick"}
            elif mode == "tower_partial": state.growth.segment_styles = {"1":"brick"}
            if mode in ["facade_sheet_unlocked","facade_style_probe"]: state.growth.metal_lines = 3
            if mode in ["facade_crystal_unlocked","facade_crystal_legacy"]:
                state.growth.brick_lines = 4
                state.growth.metal_lines = 4
                state.growth.crystal_lines = 4
            if mode == "facade_crystal_legacy": state.growth.segment_styles = {"1":"crystal"}
            if mode in ["facade_part_locked","facade_part_unlocked","facade_part_scrolled","facade_part_dormant","facade_part_probe","tower_brick_arch","facade_part_terrace_locked","facade_part_terrace_unlocked","facade_part_terrace_scrolled","facade_part_terrace_dormant","facade_part_terrace_probe","tower_brick_terrace","tower_brick_arch_terrace"]:
                state.growth.brick_lines = 30 if mode in ["facade_part_terrace_dormant","facade_part_terrace_probe","tower_brick_terrace","tower_brick_arch_terrace"] else (3 if mode in ["facade_part_dormant","facade_part_probe","tower_brick_arch"] else 2)
                if mode in ["facade_part_dormant","facade_part_probe","tower_brick_arch","facade_part_terrace_dormant","facade_part_terrace_probe"]: state.growth.metal_lines = 3
                if mode in ["facade_part_dormant","tower_brick_arch","facade_part_terrace_dormant"]:
                    state.growth.segment_styles = {"1":"metal" if mode in ["facade_part_dormant","facade_part_terrace_dormant"] else "brick"}
                    state.growth.segment_parts = {"1":["brick_arch_window","brick_terrace"] if mode=="facade_part_terrace_dormant" else (["brick_terrace"] if mode=="facade_part_terrace_dormant" else ["brick_arch_window"])}
                elif mode in ["facade_part_locked","facade_part_unlocked","facade_part_scrolled","facade_part_probe","facade_part_terrace_locked","facade_part_terrace_unlocked","facade_part_terrace_scrolled","facade_part_terrace_probe","tower_brick_terrace","tower_brick_arch_terrace"]:
                    state.growth.segment_styles = {"1":"brick"}
                    if mode == "tower_brick_terrace": state.growth.segment_parts = {"1":["brick_terrace"]}
                    if mode == "tower_brick_arch_terrace": state.growth.segment_parts = {"1":["brick_arch_window","brick_terrace"]}
            if mode in ["tower_legacy","facade_sheet_legacy"]:
                state.growth.brick_lines = 4
                state.growth.metal_lines = 4
                state.growth.crystal_lines = 4
                state.growth.segment_styles = {"1":"crystal"}
            if mode == "facade_style_probe": state.growth.segment_styles = {"2":"brick"}
            if mode in ["tower_brick_cornice_horizontal","tower_brick_cornice_roof","tower_brick_all_parts","tower_brick_arch_cornice","tower_brick_terrace_cornice"]:
                var target_segment := "20"
                state.growth.segment_styles = {target_segment:"brick"}
                if mode in ["tower_brick_cornice_horizontal","tower_brick_cornice_roof"]: state.growth.segment_parts = {target_segment:["brick_cornice"]}
                if mode == "tower_brick_all_parts": state.growth.segment_parts = {target_segment:["brick_arch_window","brick_cornice","brick_terrace"]}
                if mode == "tower_brick_arch_cornice": state.growth.segment_parts = {target_segment:["brick_arch_window","brick_cornice"]}
                if mode == "tower_brick_terrace_cornice": state.growth.segment_parts = {target_segment:["brick_cornice","brick_terrace"]}
            if mode in ["facade_part_landmark_locked","facade_part_landmark_unlocked","facade_part_landmark_scrolled","facade_part_landmark_probe","facade_part_landmark_dormant","tower_brick_landmark","tower_brick_arch_landmark","tower_brick_all_parts_landmark"]:
                if mode == "facade_part_landmark_locked":
                    state.growth.total_floors = 30
                    state.growth.brick_lines = 2
                state.growth.segment_styles = {"1":"metal" if mode == "facade_part_landmark_dormant" else "brick"}
                if mode == "facade_part_landmark_dormant": state.growth.segment_parts = {"1":["brick_landmark"]}
                if mode == "tower_brick_landmark": state.growth.segment_parts = {"1":["brick_landmark"]}
                if mode == "tower_brick_arch_landmark": state.growth.segment_parts = {"1":["brick_arch_window","brick_landmark"]}
                if mode == "tower_brick_all_parts_landmark": state.growth.segment_parts = {"1":["brick_arch_window","brick_cornice","brick_landmark","brick_terrace"]}
            if mode.begins_with("facade_part_cornice_"):
                state.growth.total_floors = 30 if mode == "facade_part_cornice_locked" else 200
                state.growth.brick_lines = 2 if mode == "facade_part_cornice_locked" else 60
                if mode != "facade_part_cornice_locked": state.growth.segment_styles = {"1":"metal" if mode == "facade_part_cornice_dormant" else "brick"}
                if mode == "facade_part_cornice_dormant": state.growth.segment_parts = {"1":["brick_cornice"]}
        if mode == "reference":
            # 원본 B 패널을 실제 8×8 규칙에 맞춘 외형 대조 fixture.
            state.occupancy.fill(0)
            state.cell_style.fill(0)
            var rows := ["12300000","12200003","30002210","23002000","10332000","12120000","13000000","00000000"]
            for y in range(8):
                for x in range(8):
                    var material_id := int(rows[y][x])
                    state.occupancy[y*8+x] = 1 if material_id>0 else 0
                    state.cell_style[y*8+x] = material_id
            state.score = 2580
            state.best = 12340
        if mode == "large":
            state.score = 8999999999999000
            state.best = 9000000000000000
        if mode in ["hud","drag"]:
            # 2026-09-23 HUD 개선안의 기본 화면과 같은 규칙상 유효한 보드.
            state.occupancy.fill(0)
            state.cell_style.fill(0)
            var hud_rows := ["12300000","12000060","50000060","12560000","00520000","00620003","00320003","02000113"]
            for y in range(8):
                for x in range(8):
                    var hud_style := int(hud_rows[y][x])
                    state.occupancy[y*8+x] = 1 if hud_style>0 else 0
                    state.cell_style[y*8+x] = hud_style
            state.score = 2580
            state.best = 12340
            state.streak = 3
            state.best_streak = 3
            state.growth.total_floors = 9
        if mode in ["over","blocked"]:
            # 체커보드는 완성 줄이 없고 2칸 이상 조각을 놓을 곳이 없다.
            for i in range(64):
                var filled := ((i/8)+(i%8))%2 == 0
                state.occupancy[i] = 1 if filled else 0
                state.cell_style[i] = ((i*5)%6)+1 if filled else 0
            state.queue = ["square2_v0","square2_v0","square2_v0"]
            state.growth.total_floors = 15 if mode == "over" else 13
            state.growth.representative_segment = 1
            state.score = 4160 if mode == "over" else 3920
            state.best = 12340
            if mode == "blocked":
                for i in range(8):
                    state.occupancy[16+i] = 1
                    state.cell_style[16+i] = 2
        state.revision += 1
        state.last_event_id += 1
        var committed: Dictionary = repo.commit(state,0)
        check(committed.ok,"fixture committed")
        if not committed.ok:
            push_error("presentation fixture commit failed: "+str(committed.error))
            quit(5)
            return
        session = Session.resume(repo).session
    var app: Node
    if mode == "lifecycle":
        app = load("res://scripts/application/app_root.gd").new()
        app.save_directory = directory
        root.add_child(app)
        screen = app.screen
        session = app.game_session
    else:
        screen = InsetScreen.new() if inset_case else Screen.new()
        root.add_child(screen)
        screen.attach(session,directory.path_join("presentation.json"))
    if large_text_case:
        screen.preferences.values.large_text = true
        screen._layout()
    screen.preferences.values.reduced_motion = reduced_motion_case
    screen.preferences.values.muted = true
    await process_frame
    await process_frame
    if mode == "lifecycle":
        var before: Dictionary = session.snapshot()
        var old_auto: Button = screen.auto_button
        _mouse(old_auto.get_global_rect().get_center(),true)
        await process_frame
        app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
        app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
        app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
        check(not screen.controller.application_active,"resume waits for focus")
        app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
        _mouse(screen.auto_button.get_global_rect().get_center(),false)
        await process_frame
        check(screen.modal==null and session.snapshot()==before,"old native button release cannot activate replacement")
        _touch(0,screen.tray_rects[1].get_center(),true)
        await process_frame
        check(screen.controller.phase=="dragging","fresh native touch can pick")
        _touch(1,Vector2(root.size.x-36,screen.tower_button.position.y+24),true)
        _touch(1,Vector2(root.size.x-36,screen.tower_button.position.y+24),false)
        await process_frame
        check(screen.controller.phase=="dragging" and screen.modal==null,"second finger cannot open settings during drag")
        app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
        app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
        _touch(0,screen.board_rect.get_center(),false)
        await process_frame
        check(session.snapshot()==before and screen.controller.phase=="idle","orphan touch release cannot place after resume")
        screen._clear()
        var committed: Dictionary = session.snapshot()
        var sounds: int = screen.feedback.played.size()
        app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
        app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
        await create_timer(.55).timeout
        check(screen.remnants.is_empty() and screen.feedback.played.size()==sounds,"clear tail settles without replay")
        check(session.snapshot()==committed,"lifecycle never awards again")
        check(Session.resume(Repository.open(directory).repository).session.snapshot()==committed,"real disk matches resumed HUD session")
    if inset_case:
        check(screen.tower_button.position.y>=24,"navigation below safe top")
        check(screen.clear_button.get_rect().end.y<=root.size.y-24,"clear above safe bottom")
        check(screen.board_rect.size.x==root.size.x-24,"full width retained with insets")
    if mode == "basic":
        check(screen.clear_button.disabled and screen.clear_button.text.begins_with("대기"),"disabled clear action has a text cue")
    if mode == "pending":
        check(screen.hint_label.text.begins_with("[완성]"),"pending lines have a text cue")
    if mode == "hud":
        check(screen.chip_name.text=="내 탑 9층" and screen.chip_remaining.text=="1층 남음","tower chip shows floors and segment remainder")
        check(screen.score_label.text=="2,580" and screen.best_label.text.ends_with("12,340"),"score and best use exact grouped integers")
        check(screen.streak_chip.visible == not screen.compact_layout,"streak chip visible for a streak of three outside compact layout")
        check(screen.tower_button.get_rect().end.x<root.size.x-60,"chip does not cover settings")
    if mode == "drag":
        screen._pointer(-1,screen.tray_rects[1].get_center(),true,false)
        screen._pointer(-1,screen.board_rect.position+Vector2(7.5,3.5)*screen.board_rect.size.x/8,false,false)
        check(screen.preview.get("ok",false),"drag preview valid")
        check(screen.hint_label.text.begins_with("[가능]"),"drag hint has a text cue")
    if mode == "blocked":
        check(session.view().status=="MUST_CLEAR","fixture must clear to continue")
        check(screen._must_clear_emphasis() and not screen.clear_button.disabled,"clear action is emphasized")
        check(screen.tray_notes.all(func(note): return note.visible),"every unplaceable piece is labelled")
    if mode == "over":
        check(session.view().status=="GAME_OVER","fixture is over")
        screen._clear()
        await process_frame
        var panel: Control = screen.modal.get_child(0)
        check(panel.position.y>=0 and panel.position.y+panel.size.y<=root.size.y,"results sheet inside viewport")
        check(screen.modal_actions.get_child(0).text=="다시 하기","restart is the primary result action")
    if mode == "input":
        var before: Dictionary = session.snapshot()
        var pick: Vector2 = screen.tray_rects[1].get_center()
        var target: Vector2 = screen.board_rect.position+Vector2(6.5,6.5)*screen.board_rect.size.x/8
        var press := InputEventMouseButton.new()
        press.button_index = MOUSE_BUTTON_LEFT
        press.pressed = true
        press.position = pick
        Input.parse_input_event(press)
        await process_frame
        check(screen.controller.phase=="dragging","native input dispatch picked tray")
        var move := InputEventMouseMotion.new()
        move.position = target
        Input.parse_input_event(move)
        await process_frame
        check(screen.preview.get("ok",false),"native input preview valid")
        var release := InputEventMouseButton.new()
        release.button_index = MOUSE_BUTTON_LEFT
        release.position = target
        Input.parse_input_event(release)
        await create_timer(0.35).timeout
        check(session.snapshot().revision==before.revision+1,"one input committed once")
        check(session.snapshot().occupancy[54]==1,"preview/drop exact cell")
        check(screen.controller.phase=="idle","input unlocked after settle")
        var resumed = Session.resume(Repository.open(directory).repository).session
        check(resumed.snapshot()==session.snapshot(),"disk matches rendered session")
    elif mode in ["valid","invalid"]:
        screen._pointer(-1,screen.tray_rects[1].get_center(),true,false)
        var cell := Vector2(6.5,6.5) if mode=="valid" else Vector2(0.5,0.5)
        screen._pointer(-1,screen.board_rect.position+cell*screen.board_rect.size.x/8,false,false)
        check(screen.hint_label.text.begins_with("[가능]" if mode=="valid" else "[불가]"),"placement preview has a text cue")
    elif mode in ["event_9_11","event_19_21","event_multi16"]:
        var before: Dictionary = session.snapshot()
        var expected_floors: int = 11 if mode == "event_9_11" else (21 if mode == "event_19_21" else 25)
        var expected_lines: int = 16 if mode == "event_multi16" else 2
        check(session.view().clear_lines==expected_lines,"fixed event has %d pending lines" % expected_lines)
        var node_before: int = _count_nodes(root)
        var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
        var cue_before: int = screen.feedback.cue_sequence
        var dispatch_started: int = Time.get_ticks_usec()
        var result: Dictionary = screen.controller.submit("CLEAR")
        var dispatch_ms: float = (Time.get_ticks_usec()-dispatch_started)/1000.0
        check(result.ok,"fixed event committed through GameSession")
        check(session.snapshot().score-before.score==(2560 if expected_lines==16 else 240),"fixed event score matches rules")
        check(session.snapshot().growth.total_floors==expected_floors,"fixed event floor total matches rules")
        check(screen.toast_label.position.y>=screen.board_rect.end.y,"event notice starts below the board")
        var notice_bottom: float = screen.toast_label.position.y+screen.toast_label.size.y
        var tray_top: float = screen.tray_rects[0].position.y
        check(notice_bottom<=tray_top,"event notice ends before the tray (%d <= %d)" % [int(notice_bottom),int(tray_top)])
        await create_timer(.46).timeout
        check(screen.controller.phase=="idle","next drag is not blocked by event notices")
        var memory_after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
        var node_after: int = _count_nodes(root)
        var cue_requests: int = screen.feedback.cue_sequence-cue_before
        var audio_players_playing: int = screen.feedback.players.filter(func(player):return player.playing).size()
        var notices: Array[String] = screen.last_event_announcements.duplicate()
        check(notices.has("[완료] %d줄 · +%d점 · +%d층" % [expected_lines,2560 if expected_lines==16 else 240,expected_lines]),"clear, score and floor reward notice is present")
        check(notices.size()<=screen.MAX_EVENT_ANNOUNCEMENTS,"event notice count is bounded at three")
        check(notices.size()*(screen.EVENT_NOTICE_HOLD+screen.Tokens.TOAST_FADE)<=screen.MAX_EVENT_ANNOUNCEMENT_SECONDS,"complete notice sequence stays under three seconds")
        if mode == "event_multi16":
            check(notices.has("구간 +2 · 해금 4종"),"multi-segment and unlock count remain visible")
            check(screen.last_growth_details.has("새 구간: 1, 2"),"latest clear records exact segment unlocks")
            check(screen.last_growth_details.has("새 재료: 벽돌, 금속, 수정"),"latest clear records exact material unlocks")
            check(screen.last_growth_details.has("새 장식: 아치 창문"),"latest clear records exact part unlocks")
        else:
            check(notices.has("구간 +1 · 해금 1종"),"segment and material unlock counts remain visible")
            check(screen.last_growth_details.has("새 재료: 벽돌"),"latest clear records the material unlock")
        for index in range(notices.size()):
            if index > 0:
                if screen.toast_motion != null: screen.toast_motion.kill()
                screen.toast_label.modulate.a = 0
                screen._show_next_toast()
            await process_frame
            await RenderingServer.frame_post_draw
            var font_size: int = screen.toast_label.get_theme_font_size("font_size")
            var text_width: float = screen.strong.get_string_size(screen.toast_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
            check(text_width<=screen.toast_label.size.x,"notice %d fits without clipping" % index)
            var notice_image := root.get_texture().get_image()
            if grayscale_case: _grayscale_image(notice_image)
            check(notice_image.save_png(output+"_notice_%02d.png" % index)==OK,"notice frame %d captured" % index)
        var growth_facts_accessible := false
        var fast_pick_dismissed := false
        if mode == "event_multi16":
            screen._pointer(-1,screen.tray_rects[1].get_center(),true,false)
            fast_pick_dismissed = screen.controller.phase=="dragging" and screen.toast_label.modulate.a==0
            check(fast_pick_dismissed,"fast next pickup dismisses notices without blocking drag")
            check(screen.last_growth_details.has("새 구간: 1, 2"),"fast pickup preserves exact milestone facts")
            screen._cancel_drag()
            screen._open_tower()
            check(screen.growth_details_button!=null,"tower has a durable growth-details action")
            await RenderingServer.frame_post_draw
            var tower_image := root.get_texture().get_image()
            if grayscale_case: _grayscale_image(tower_image)
            check(tower_image.save_png(output+"_tower_details_action.png")==OK,"tower details action native screen captured")
            screen.growth_details_button.pressed.emit()
            await process_frame
            var detail_body: Label = screen.modal_content.get_child(1)
            growth_facts_accessible = detail_body.text.contains("새 구간: 1, 2") and detail_body.text.contains("새 재료: 벽돌, 금속, 수정") and detail_body.text.contains("새 장식: 아치 창문")
            check(growth_facts_accessible,"tower flow exposes exact segment, material and part unlock facts")
            await RenderingServer.frame_post_draw
            var details_image := root.get_texture().get_image()
            if grayscale_case: _grayscale_image(details_image)
            check(details_image.save_png(output+"_growth_details.png")==OK,"growth details native screen captured")
        var metrics := {"scenario":mode,"dispatch_ms":dispatch_ms,"settle_wait_ms":460,
            "node_count_before":node_before,"node_count_after":node_after,"node_count_delta":node_after-node_before,
            "memory_static_bytes_before":memory_before,"memory_static_bytes_after":memory_after,"memory_static_delta_bytes":memory_after-memory_before,
            "feedback_cue_requests":cue_requests,"audio_player_pool_size":screen.feedback.players.size(),
            "audio_player_playing_after_settle":audio_players_playing,
            "notice_count":notices.size(),"notice_hold_seconds":screen.EVENT_NOTICE_HOLD,
            "notice_max_sequence_seconds":notices.size()*(screen.EVENT_NOTICE_HOLD+screen.Tokens.TOAST_FADE),
            "fast_pick_dismissed_without_block":fast_pick_dismissed,"growth_facts_accessible_after_pick":growth_facts_accessible,
            "muted":screen.preferences.values.muted,"reduced_motion":screen.preferences.values.reduced_motion,
            "scope":"Windows native Godot observation; not a mobile performance result"}
        var metric_file := FileAccess.open(output+".metrics.json",FileAccess.WRITE)
        metric_file.store_string(JSON.stringify(metrics,"\t"))
        metric_file.close()
    elif mode == "clear_pick":
        screen._clear()
        await create_timer(.30).timeout
        screen._pointer(-1,screen.tray_rects[1].get_center(),true,false)
        screen._pointer(-1,screen.board_rect.position+Vector2(6.5,6.5)*screen.board_rect.size.x/8,false,false)
        check(screen.controller.phase=="dragging","pickup during clear tail allowed")
        check(screen.toast_label.modulate.a==0,"old clear reward dismissed on pickup")
        check(screen.hint_label.visible and screen.hint_label.text.begins_with("[가능]"),"new drag guidance visible immediately")
    elif mode == "motion":
        # Warm rendering first; defer PNG compression until the tween is over.
        for warm_frame in range(12): await process_frame
        var before: Dictionary = session.snapshot()
        var started := Time.get_ticks_usec()
        screen._clear()
        var samples: Array = []
        var frames: Array[Image] = []
        var last_frame := started
        var longest_frame := 0.0
        for target_ms in [0,60,140,220,300,460]:
            while (Time.get_ticks_usec()-started)/1000.0 < target_ms:
                await process_frame
                var now := Time.get_ticks_usec()
                longest_frame = maxf(longest_frame,(now-last_frame)/1000.0)
                last_frame = now
            await RenderingServer.frame_post_draw
            var elapsed := (Time.get_ticks_usec()-started)/1000.0
            var frame := root.get_texture().get_image()
            frames.append(frame)
            samples.append({"requested_ms":target_ms,"elapsed_ms":elapsed,"progress":screen.effect_progress,"phase":screen.controller.phase})
            # GPU readback is instrumentation, excluded from next-frame observation.
            last_frame = Time.get_ticks_usec()
        for index in range(frames.size()):
            check(frames[index].save_png(output+"_t%d.png" % samples[index].requested_ms)==OK,"motion frame %d saved" % samples[index].requested_ms)
        check(screen.controller.phase=="idle","real-time clear released input")
        check(session.snapshot().score-before.score==240,"real-time clear awarded once")
        var timeline := FileAccess.open(output+".timeline.json",FileAccess.WRITE)
        timeline.store_string(JSON.stringify({"samples":samples,"longest_observed_frame_ms":longest_frame,"scope":"Windows native real-time tween, instrumented PNG readback; not device frame-time benchmark"},"\t"))
        timeline.close()
    elif mode in ["clear","max","anticipation","sweep","shrink"]:
        var before: Dictionary = session.snapshot()
        screen._clear()
        check(screen.remnants.size()==(64 if mode=="max" else 15),"removal cells captured")
        if mode in ["anticipation","sweep","shrink"]:
            screen.motion.pause()
            screen.effect_progress = {"anticipation":.10,"sweep":.33,"shrink":.62}[mode]
            screen.settle_left = 10
            screen._redraw()
        else:
            await create_timer(0.46).timeout
            check(screen.controller.phase=="idle","clear released input")
        if mode == "clear":
            check(screen.toast_label.text.begins_with("[완료]"),"clear result has a text cue")
            check(screen.toast_label.position.y>=screen.board_rect.end.y,"clear reward remains below the board")
        check(session.snapshot().score-before.score==(2560 if mode=="max" else 240),"clear score exact")
    elif mode == "modal":
        screen._toggle_auto()
        check(screen.modal != null and screen.controller.phase=="modal","confirmation modal remains active")
        var panel: Control = screen.modal.get_child(0)
        check(panel.position.y>=0 and panel.position.y+panel.size.y<=root.size.y,"confirmation stays inside the viewport")
        check(screen.modal_actions.get_child(0).custom_minimum_size.y>=48,"confirmation action keeps a 48px target")
    elif mode == "settings":
        screen._settings()
        var panel: Control = screen.modal.get_child(0)
        check(panel.position.y>=0 and panel.position.y+panel.size.y<=root.size.y,"settings stay inside the viewport")
        var has_large_text := false
        for child in screen.modal_content.get_children():
            if child is CheckButton and child.text=="큰 글씨":
                has_large_text = child.button_pressed==large_text_case
                check(child.custom_minimum_size.y>=48,"large-text setting keeps a 48px target")
        check(has_large_text,"settings expose the current large-text choice")
    elif mode == "button":
        screen._button_feedback(screen.auto_button,.82)
        await create_timer(.07).timeout
    elif mode in ["tower","tower_top"]:
        screen._open_tower()
        screen.selected_segment = 2 if mode=="tower_top" else 1
        screen._layout()
        check(screen.tower_segment_view()=={"count":3 if mode=="tower_top" else 10,"roof":mode=="tower_top"},"only actual top receives roof")
    elif mode.begins_with("tower_") and mode.trim_prefix("tower_").is_valid_int():
        screen._open_tower()
        if mode == "tower_11": screen.selected_segment = 2
        screen._layout()
        var expected := 1 if mode=="tower_11" else int(mode.trim_prefix("tower_"))
        check(screen.tower_segment_view()=={"count":expected,"roof":true},"exact acquired floor count and top")
    elif mode in ["tower_brick","tower_wood","tower_locked","tower_partial","tower_legacy","tower_style_probe","facade_sheet_locked","facade_sheet_unlocked","facade_sheet_legacy","facade_partial","facade_style_probe","facade_crystal_locked","facade_crystal_unlocked","facade_crystal_scrolled","facade_crystal_legacy","facade_part_locked","facade_part_unlocked","facade_part_scrolled","facade_part_dormant","facade_part_probe","tower_brick_arch","facade_part_terrace_locked","facade_part_terrace_unlocked","facade_part_terrace_scrolled","facade_part_terrace_dormant","facade_part_terrace_probe","tower_brick_terrace","tower_brick_arch_terrace","facade_part_cornice_locked","facade_part_cornice_dormant","facade_part_cornice_unlocked","facade_part_cornice_scrolled","facade_part_cornice_probe","tower_brick_cornice_horizontal","tower_brick_cornice_roof","tower_brick_all_parts","tower_brick_arch_cornice","tower_brick_terrace_cornice","facade_part_landmark_locked","facade_part_landmark_unlocked","facade_part_landmark_scrolled","facade_part_landmark_dormant","facade_part_landmark_probe","tower_brick_landmark","tower_brick_arch_landmark","tower_brick_all_parts_landmark"]:
        screen._open_tower()
        screen.selected_segment = 20 if mode in ["tower_brick_cornice_horizontal","tower_brick_cornice_roof","tower_brick_all_parts","tower_brick_arch_cornice","tower_brick_terrace_cornice"] else (2 if mode in ["tower_brick","tower_partial","facade_partial"] else 1)
        screen._layout()
        var complete: bool = screen.selected_segment <= int(screen.analysis.growth.completed_segments)
        if mode == "tower_brick_arch":
            var shows_equipped_part := false
            for child in screen.controls.get_children():
                if child is Label and child.text.contains("현재 벽돌 · 아치 창문"): shows_equipped_part = true
            check(shows_equipped_part,"selected segment caption names the committed brick arch window")
        if mode in ["tower_brick_terrace","tower_brick_arch_terrace"]:
            var expected_caption := "현재 벽돌 · 테라스" if mode=="tower_brick_terrace" else "현재 벽돌 · 아치 창문+테라스"
            if mode == "tower_brick_arch_terrace":
                check(screen.controls.get_children().any(func(child):return child is Label and child.text.contains("현재 벽돌 ·") and child.text.contains("아치 창문+테라스")),"selected caption preserves the full two-part wording on separate fitting lines")
            else:
                check(screen.controls.get_children().any(func(child):return child is Label and child.text.contains(expected_caption)),"selected segment caption names every committed terrace decoration")
        if mode == "tower_brick_cornice_horizontal":
            check(screen.tower_cap_key()=="brick_cornice" and not screen.tower_segment_view().roof,"selected lower segment uses a horizontal decorated cap")
        if mode == "tower_brick_cornice_roof":
            check(screen.tower_cap_key()=="brick_cornice_roof_top" and screen.tower_segment_view().roof,"200-floor final segment keeps and decorates the top roof")
        if mode == "tower_brick_all_parts":
            var all_parts_caption: Label
            for child in screen.controls.get_children():
                if child is Label and child.text.contains("아치·테라스·상단"): all_parts_caption = child
            check(all_parts_caption != null,"selected caption names all three independent parts in user-understandable terms")
            if all_parts_caption != null:
                var caption_font := all_parts_caption.get_theme_font("font")
                var caption_size := all_parts_caption.get_theme_font_size("font_size")
                check(caption_font.get_string_size("아치·테라스·상단",HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size).x <= all_parts_caption.size.x,"three-part caption measured width fits before the Next control")
        if mode in ["tower_brick_arch_cornice","tower_brick_terrace_cornice"]:
            var pair_caption: Label
            var expected_part_one := "아치 창문" if mode == "tower_brick_arch_cornice" else "테라스"
            var expected_part_two := "상단 장식"
            var forbidden_part := "테라스" if mode == "tower_brick_arch_cornice" else "아치 창문"
            for child in screen.controls.get_children():
                if child is Label and child.text.contains("현재 벽돌") and child.text.contains("상단 장식"): pair_caption = child
            check(pair_caption != null,"two-part caption is present for the selected brick segment")
            if pair_caption != null:
                check(pair_caption.text.contains(expected_part_one) and pair_caption.text.contains(expected_part_two),"two-part caption truthfully names the selected parts")
                check(not pair_caption.text.contains(forbidden_part),"two-part caption omits unselected brick decorations")
                check(pair_caption.accessibility_name == pair_caption.text,"accessible caption matches its visible truthful text")
                var pair_font := pair_caption.get_theme_font("font")
                var pair_font_size := pair_caption.get_theme_font_size("font_size")
                for line in pair_caption.text.split("\n"):
                    check(pair_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pair_font_size).x <= pair_caption.size.x,"each two-part caption line fits between tower arrows")
                var previous_button: Button
                var next_button: Button
                var style_button: Button
                for child in screen.controls.get_children():
                    if child is Button and child.text == "이전": previous_button = child
                    if child is Button and child.text == "다음": next_button = child
                    if child is Button and child.text.begins_with("외벽 선택"): style_button = child
                check(previous_button != null and next_button != null and style_button != null,"segment controls exist around the caption")
                if previous_button != null and next_button != null and style_button != null:
                    check(pair_caption.get_global_rect().position.x >= previous_button.get_global_rect().end.x and pair_caption.get_global_rect().end.x <= next_button.get_global_rect().position.x,"caption stays horizontally between both arrow targets")
                    check(pair_caption.get_global_rect().end.y <= style_button.get_global_rect().position.y,"caption does not overlap the facade action")
        var facade_button: Button
        for child in screen.controls.get_children():
            if child is Button and (child.text.contains("외벽 선택") or child.accessibility_name.contains("외벽 선택")): facade_button = child
        check(screen._tower_style_status(str(screen.state.growth.segment_styles.get(str(screen.selected_segment),"wood"))).contains("외벽"),"selected material has a readable current-state label")
        check(facade_button != null and facade_button.disabled == not complete,"style selector is available only for completed segments")
        if mode in ["facade_sheet_locked","facade_sheet_unlocked","facade_sheet_legacy","facade_crystal_locked","facade_crystal_unlocked","facade_crystal_scrolled","facade_crystal_legacy","facade_part_locked","facade_part_unlocked","facade_part_scrolled","facade_part_dormant","facade_part_probe","facade_part_terrace_locked","facade_part_terrace_unlocked","facade_part_terrace_scrolled","facade_part_terrace_dormant","facade_part_terrace_probe","facade_part_cornice_locked","facade_part_cornice_dormant","facade_part_cornice_unlocked","facade_part_cornice_scrolled","facade_part_cornice_probe","facade_part_landmark_locked","facade_part_landmark_dormant","facade_part_landmark_unlocked","facade_part_landmark_scrolled","facade_part_landmark_probe"]:
            if facade_button != null:
                facade_button.grab_focus()
                screen._show_facade_sheet()
            else:
                check(false,"facade selector can be found for the completed segment")
            await process_frame
            var brick_choice: Button
            var metal_choice: Button
            var crystal_choice: Button
            var wood_choice: Button
            var arch_choice: Button
            var terrace_choice: Button
            var cornice_choice: Button
            var landmark_choice: Button
            var sheet_copy := ""
            for child in screen.modal_content.get_children():
                if child is Button:
                    if child.text.contains("아치"): arch_choice = child
                    elif child.text.contains("테라스"): terrace_choice = child
                    elif child.text.contains("랜드마크"): landmark_choice = child
                    elif child.text.contains("상단 장식"): cornice_choice = child
                    elif child.text.contains("벽돌"): brick_choice = child
                    elif child.text.contains("금속·유리"): metal_choice = child
                    elif child.text.contains("크리스털"): crystal_choice = child
                    elif child.text.contains("목재"): wood_choice = child
                elif child is Label: sheet_copy += child.text
            check(screen.modal != null and screen.controller.phase=="modal","facade choices use the existing modal input boundary")
            var brick_current: bool = str(screen.state.growth.segment_styles.get(str(screen.selected_segment),"wood")) == "brick"
            check(brick_choice != null and brick_choice.disabled == (("brick" not in screen.analysis.growth.materials) or brick_current),"brick lock/current state matches Growth.describe and committed style")
            var metal_current: bool = str(screen.state.growth.segment_styles.get(str(screen.selected_segment),"wood")) == "metal"
            check(metal_choice != null and metal_choice.disabled == (("metal" not in screen.analysis.growth.materials) or metal_current),"metal lock/current state matches Growth.describe and committed style")
            var crystal_current: bool = str(screen.state.growth.segment_styles.get(str(screen.selected_segment),"wood")) == "crystal"
            check(crystal_choice != null and crystal_choice.disabled == (("crystal" not in screen.analysis.growth.materials) or crystal_current),"crystal lock/current state matches committed style and Growth.describe")
            check(wood_choice != null and wood_choice.custom_minimum_size.y>=48,"wood choice remains a readable 48px target")
            var arch_unlocked: bool = "brick_arch_window" in screen.analysis.growth.parts
            var arch_equipped: bool = "brick_arch_window" in screen.state.growth.segment_parts.get(str(screen.selected_segment),[])
            check(arch_choice != null and arch_choice.custom_minimum_size.y>=48,"brick arch part choice keeps a 48px target")
            check(arch_choice.disabled == ((not arch_unlocked and not arch_equipped) or (not arch_equipped and screen.state.growth.segment_styles.get(str(screen.selected_segment),"wood")!="brick")),"part availability requires its unlock and brick style while dormant parts remain removable")
            check(sheet_copy.contains("벽돌 10줄 또는 누적 60층"),"brick arch part unlock paths are stated precisely")
            var terrace_unlocked: bool = "brick_terrace" in screen.analysis.growth.parts
            var terrace_equipped: bool = "brick_terrace" in screen.state.growth.segment_parts.get(str(screen.selected_segment),[])
            check(terrace_choice != null and terrace_choice.custom_minimum_size.y>=48,"brick terrace part choice keeps a 48px target")
            check(terrace_choice.disabled == ((not terrace_unlocked and not terrace_equipped) or (not terrace_equipped and screen.state.growth.segment_styles.get(str(screen.selected_segment),"wood")!="brick")),"terrace requires its unlock and brick style while dormant parts remain removable")
            check(sheet_copy.contains("벽돌 30줄 또는 누적 120층"),"terrace unlock paths are stated precisely")
            var cornice_unlocked: bool = "brick_cornice" in screen.analysis.growth.parts
            var cornice_equipped: bool = "brick_cornice" in screen.state.growth.segment_parts.get(str(screen.selected_segment),[])
            check(sheet_copy.contains("벽돌 60줄 또는 누적 200층"),"cornice unlock paths are stated precisely")
            check(cornice_choice != null and cornice_choice.custom_minimum_size.y>=48,"brick cornice choice keeps a 48px target")
            check(cornice_choice.disabled == ((not cornice_unlocked and not cornice_equipped) or (not cornice_equipped and screen.state.growth.segment_styles.get(str(screen.selected_segment),"wood")!="brick")),"cornice requires unlock and brick style; dormant parts remain removable")
            if mode == "facade_part_cornice_locked": check(cornice_choice.text.contains("잠김"),"locked cornice state is explicit")
            if mode == "facade_part_cornice_dormant": check(cornice_choice.text.contains("숨김") and not cornice_choice.disabled,"dormant cornice is clearly marked and removable")
            if mode == "facade_part_cornice_probe":
                cornice_choice.pressed.emit()
                check(screen.state.growth.segment_parts.get("1",[])==["brick_cornice"],"actual pressed cornice button commits to its selected brick segment")
            if mode == "facade_part_locked": check(arch_choice.text.contains("잠김"),"locked part status is explicit")
            if mode == "facade_part_dormant": check(arch_choice.text.contains("숨김") and not arch_choice.disabled,"dormant part is clearly labeled and removable")
            if mode == "facade_part_probe":
                arch_choice.pressed.emit()
                check(screen.state.growth.segment_parts.get("1",[])==["brick_arch_window"],"actual pressed part button commits the brick arch on its bound segment")
            if mode == "facade_part_terrace_locked": check(terrace_choice.text.contains("잠김"),"locked terrace status is explicit")
            if mode == "facade_part_terrace_dormant": check(terrace_choice.text.contains("숨김") and not terrace_choice.disabled,"dormant terrace remains truthfully labeled and removable")
            if mode == "facade_part_terrace_probe":
                terrace_choice.pressed.emit()
                check(screen.state.growth.segment_parts.get("1",[])==["brick_terrace"],"actual pressed terrace button commits to the selected segment")
            var landmark_unlocked: bool = "brick_landmark" in screen.analysis.growth.parts
            var landmark_equipped: bool = "brick_landmark" in screen.state.growth.segment_parts.get(str(screen.selected_segment),[])
            check(landmark_choice != null and landmark_choice.custom_minimum_size.y>=48,"landmark choice keeps a 48px target")
            check(landmark_choice.disabled == ((not landmark_unlocked and not landmark_equipped) or (not landmark_equipped and screen.state.growth.segment_styles.get(str(screen.selected_segment),"wood")!="brick")),"landmark requires unlock and brick style; dormant state remains removable")
            check(sheet_copy.contains("벽돌 100줄 또는 누적 300층"),"landmark unlock requirements are stated precisely")
            if mode == "facade_part_landmark_locked": check(landmark_choice.text.contains("잠김"),"locked landmark is explicit")
            if mode == "facade_part_landmark_dormant": check(landmark_choice.text.contains("숨김") and not landmark_choice.disabled,"dormant landmark remains truthfully removable")
            if mode == "facade_part_landmark_probe":
                landmark_choice.pressed.emit()
                screen.controller.settle()
                check(screen.state.growth.segment_parts.get("1",[])==["brick_landmark"],"actual Button.pressed commits landmark to the selected segment")
            check(sheet_copy.contains("동시 2줄 제거 또는 누적 30층") and sheet_copy.contains("동시 3줄 제거 또는 누적 100층") and sheet_copy.contains("동시 4줄 제거 또는 누적 250층"),"all basic material unlock paths are stated precisely")
            if mode == "facade_sheet_legacy":
                check(screen.tower_segment_style()=="crystal" and screen._tower_style_status("crystal").contains("현재 외벽: 크리스털"),"saved crystal style displays its crystal art")
                var legacy_revision: int = screen.state.revision
                check(legacy_revision == session.snapshot().revision,"showing a saved crystal applies no migration commit")
            if inset_case:
                var panel: Control = screen.modal.get_child(0)
                check(panel.get_global_rect().position.y>=24 and panel.get_global_rect().end.y<=root.size.y-24,"material sheet stays inside 24px safe insets")
                var scroll: Control = panel.get_child(0).get_child(0)
                var choice_rects: Array[Rect2] = []
                for choice in [wood_choice,brick_choice,metal_choice,crystal_choice,arch_choice,terrace_choice,cornice_choice,landmark_choice]:
                    check(choice.custom_minimum_size.y>=48,"material choice has a 48px target")
                    choice_rects.append(choice.get_rect())
                    var visible_rect: Rect2 = choice.get_global_rect().intersection(scroll.get_global_rect())
                    if visible_rect.size.y<=0:
                        var bar := (scroll as ScrollContainer).get_v_scroll_bar()
                        (scroll as ScrollContainer).scroll_vertical = int(bar.max_value)
                        await process_frame
                        visible_rect = choice.get_global_rect().intersection(scroll.get_global_rect())
                        (scroll as ScrollContainer).scroll_vertical = 0
                        await process_frame
                    check(visible_rect.size.x>0 and visible_rect.size.y>0,"material choice remains reachable in the scroll sheet")
                for i in range(choice_rects.size()):
                    for j in range(i+1,choice_rects.size()):
                        check(not choice_rects[i].intersects(choice_rects[j]),"material buttons do not overlap in sheet content")
                check(screen.handle_back() and screen.modal==null,"Back closes material sheet at compact inset size")
                check(screen.get_viewport().gui_get_focus_owner()==facade_button,"Back restores focus to the facade selector")
                screen._show_facade_sheet()
                await process_frame
                if mode in ["facade_crystal_scrolled","facade_part_scrolled","facade_part_terrace_scrolled","facade_part_cornice_scrolled","facade_part_landmark_scrolled"]:
                    # Keep the ordinary unscrolled inset case intact; this dedicated
                    # mode captures and verifies the entire final choice row at rest.
                    panel = screen.modal.get_child(0)
                    var scroll_container := panel.get_child(0).get_child(0) as ScrollContainer
                    var crystal_button: Button
                    var part_button: Button
                    var terrace_button: Button
                    var cornice_button: Button
                    var landmark_button: Button
                    var close_button := screen.modal_actions.get_child(0) as Button
                    for child in screen.modal_content.get_children():
                        if child is Button and child.text.contains("크리스털"):
                            crystal_button = child
                        if child is Button and (child.text.contains("아치") or child.text.contains("장착") or child.text.contains("숨김")):
                            part_button = child
                        if child is Button and child.text.contains("테라스"):
                            terrace_button = child
                        if child is Button and child.text.contains("상단 장식"):
                            cornice_button = child
                        if child is Button and child.text.contains("랜드마크"):
                            landmark_button = child
                    await process_frame
                    var scroll_bar := scroll_container.get_v_scroll_bar()
                    var scroll_end := int(ceil(scroll_bar.max_value-scroll_bar.page))
                    scroll_container.scroll_vertical = scroll_end
                    await process_frame
                    await process_frame
                    var target_button: Button = landmark_button if mode == "facade_part_landmark_scrolled" else (cornice_button if mode == "facade_part_cornice_scrolled" else (terrace_button if mode == "facade_part_terrace_scrolled" else (part_button if mode == "facade_part_scrolled" else crystal_button)))
                    var crystal_rect: Rect2 = target_button.get_global_rect()
                    var viewport_rect: Rect2 = scroll_container.get_global_rect()
                    var close_rect: Rect2 = close_button.get_global_rect()
                    check(target_button != null and absf(crystal_rect.size.y-48.0)<0.1,"scrolled final choice has an actual 48px global target")
                    check(crystal_rect.position.x>=viewport_rect.position.x and crystal_rect.position.y>=viewport_rect.position.y and crystal_rect.end.x<=viewport_rect.end.x and crystal_rect.end.y<=viewport_rect.end.y,"entire final choice target is inside the visible scroll viewport")
                    check(crystal_rect.end.y<=close_rect.position.y,"entire final choice target is above the fixed Close button")
                    check(scroll_container.scroll_vertical==scroll_end,"scrolled-state capture is at the actual scroll end")
        if mode == "facade_partial":
            check(facade_button.disabled and screen.modal==null,"partial segment cannot open the material sheet")
        if mode == "tower_legacy":
            check(screen._tower_style_status("crystal").contains("현재 외벽: 크리스털"),"stored crystal style has an honest current-state label")
            check(screen.tower_segment_style()=="crystal","stored crystal selects crystal runtime art")
        if mode == "facade_style_probe":
            screen._set_tower_style("metal")
            screen.controller.settle()
            check(screen.tower_segment_style()=="metal","committed metal style changes the displayed source art")
            var same_revision: int = screen.state.revision
            screen._set_tower_style("metal")
            check(screen.state.revision==same_revision,"same-style request does not commit a new revision")
            check(screen.state.growth.segment_styles.get("2","")=="brick","metal change leaves the other segment style untouched")
            var resumed_metal := Session.resume(repo)
            check(resumed_metal.ok and resumed_metal.session.snapshot().growth.segment_styles=={"1":"metal","2":"brick"},"metal and brick styles survive file resume independently")
        if mode == "facade_crystal_legacy":
            check(screen.tower_segment_style()=="crystal","preexisting crystal is the rendered committed style")
            var before_revision: int = screen.state.revision
            var resumed_crystal := Session.resume(repo)
            check(resumed_crystal.ok and resumed_crystal.session.snapshot().growth.segment_styles.get("1","")=="crystal","crystal style survives session resume")
            check(screen.state.revision==before_revision,"displaying legacy crystal does not add a commit")
        if mode == "tower_style_probe":
            screen._set_tower_style("brick")
            screen.controller.settle()
            screen.selected_segment = 2
            screen._layout()
            screen._set_tower_style("brick")
            screen.controller.settle()
            screen.selected_segment = 1
            screen._layout()
            screen._set_tower_style("wood")
            screen.controller.settle()
            var resumed := Session.resume(repo)
            check(resumed.ok,"facade choices reload from the file save repository")
            check(resumed.session.snapshot().growth.segment_styles == {"2":"brick"},"wood selection clears only its own sparse override")
            screen.attach(resumed.session,directory.path_join("presentation.json"))
            screen.screen_id = "tower"
            screen.selected_segment = 2
            screen._layout()
            check(screen.tower_segment_style()=="brick","other segment keeps its saved brick style after restart")
        if inset_case and screen.modal == null:
            for child in screen.controls.get_children():
                if child is Button and child.visible:
                    check(child.position.y >= 24 and child.get_rect().end.y <= root.size.y-24,"tower action remains in the 24px safe area")
        screen._redraw()
    elif mode == "stress":
        var durations: Array[float] = []
        var frame_durations: Array[float] = []
        var node_before: int = _count_nodes(root)
        var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
        var cue_before: int = screen.feedback.cue_sequence
        var node_peak: int = node_before
        var memory_peak: int = memory_before
        for step in range(30):
            var before_tick := Time.get_ticks_usec()
            var view: Dictionary = session.view()
            if view.status == "GAME_OVER":
                screen.controller.submit("NEW_RUN",{"seed_text":str(200+step),"confirmed":true})
            elif view.clear_lines > 0:
                screen.controller.submit("CLEAR")
            else:
                var witness: Dictionary = view.witness
                screen.controller.submit("PLACE",{"batch_id":session.snapshot().batch_id,"slot":witness.slot,"x":witness.x,"y":witness.y})
            durations.append((Time.get_ticks_usec()-before_tick)/1000.0)
            var frame_tick := Time.get_ticks_usec()
            await process_frame
            frame_durations.append((Time.get_ticks_usec()-frame_tick)/1000.0)
            node_peak = maxi(node_peak,_count_nodes(root))
            memory_peak = maxi(memory_peak,int(Performance.get_monitor(Performance.MEMORY_STATIC)))
            await create_timer(0.3).timeout
            if screen.modal != null: screen._close_modal()
            check(screen.controller.phase=="idle","stress action %d returns idle" % step)
        durations.sort()
        frame_durations.sort()
        var node_after: int = _count_nodes(root)
        var memory_after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
        var metrics := {"actions":30,"dispatch_p95_ms":durations[28],"dispatch_max_ms":durations[-1],
            "next_frame_p95_ms":frame_durations[28],"next_frame_max_ms":frame_durations[-1],
            "node_count_before":node_before,"node_count_after":node_after,"node_count_delta":node_after-node_before,"node_count_peak":node_peak,
            "memory_static_bytes_before":memory_before,"memory_static_bytes_after":memory_after,"memory_static_peak_bytes":memory_peak,
            "feedback_cue_requests":screen.feedback.cue_sequence-cue_before,"audio_player_pool_size":screen.feedback.players.size(),
            "audio_player_playing_after_actions":screen.feedback.players.filter(func(player):return player.playing).size(),
            "muted":screen.preferences.values.muted,
            "scope":"Windows host observation including sync file commit, not mobile budget or GPU-only time"}
        var metric_file := FileAccess.open(output+".metrics.json",FileAccess.WRITE)
        metric_file.store_string(JSON.stringify(metrics,"\t"))
        metric_file.close()
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if grayscale_case: _grayscale_image(image)
    check(image.save_png(output+".png")==OK,"native screenshot saved")
    check(screen.state==session.snapshot(),"screen state equals session")
    var report := {"mode":capture_name,"scenario":mode,"large_text":large_text_case,"grayscale":grayscale_case,"safe_insets_24px":inset_case,"size":args[3],"checks":checks,"revision":session.snapshot().revision,
        "score":session.snapshot().score,"floors":session.snapshot().growth.total_floors,
        "announcements":screen.last_event_announcements.duplicate(),"board":str(screen.board_rect),"source":"Windows Godot OpenGL native viewport; not Android"}
    var file := FileAccess.open(output+".json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"\t"))
    file.close()
    print("W4_PROBE ",capture_name," ",checks)
    screen.queue_free()
    await process_frame
    quit(0 if checks.all(func(c):return c.passed) else 1)
