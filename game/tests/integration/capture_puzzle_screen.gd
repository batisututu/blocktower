extends SceneTree
## 격리 저장으로 실제 PuzzleScreen 한 프레임을 파일에 남긴다.
const AppRoot = preload("res://scripts/application/app_root.gd")

func _initialize() -> void:
    _capture.call_deferred()

func _capture() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 2:
        quit(2)
        return
    var app := AppRoot.new()
    app.save_directory = args[0]
    root.add_child(app)
    for i in range(4): await process_frame
    if not app.startup_result.ok or app.screen == null:
        quit(3)
        return
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.save_png(args[1]) != OK:
        quit(4)
        return
    print("PUZZLE_CAPTURE ",JSON.stringify({"path":args[1],"size":[image.get_width(),image.get_height()],
        "supply_profile":app.startup_result.supply_profile}))
    quit(0)
