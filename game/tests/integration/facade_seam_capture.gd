extends SceneTree
## Two-floor material seam proof using production PNGs and shared stacking geometry.
const FLOOR_STEP := 106.468368530273
const SAMPLE_SCALE := 0.5
const MATERIALS := ["wood", "brick", "metal", "crystal", "brick_arch", "brick_terrace", "brick_arch_terrace", "brick_cornice", "brick_cornice_roof_top"]

class SeamCanvas extends Control:
	var upper_texture: Texture2D
	var lower_texture: Texture2D
	var upper_name := ""
	var lower_name := ""
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("17191e"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 48), "FACADE JOINT SAMPLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f8ead2"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 78), "Upper: %s    Lower: %s" % [upper_name, lower_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e9d6b4"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 104), "Shared anchor delta: %.3f px at 50%% scale" % (FLOOR_STEP * SAMPLE_SCALE), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e9d6b4"))
		var checker_rect := Rect2(20, 300, 320, 320)
		for y in range(0, 320, 16):
			for x in range(0, 320, 16):
				var alternate := (floori(float(x) / 16) + floori(float(y) / 16)) % 2 == 0
				draw_rect(Rect2(checker_rect.position + Vector2(x, y), Vector2(16, 16)), Color("35383f") if alternate else Color("24272d"))
		var anchor := Vector2(size.x * 0.5, 520.0)
		var rect := Rect2(anchor - Vector2(320, 240) * SAMPLE_SCALE, Vector2(640, 480) * SAMPLE_SCALE)
		draw_texture_rect(lower_texture, rect, false)
		draw_texture_rect(upper_texture, Rect2(rect.position - Vector2(0, FLOOR_STEP * SAMPLE_SCALE), rect.size), false)
		var joint_y := anchor.y - FLOOR_STEP * SAMPLE_SCALE
		draw_line(Vector2(7, joint_y), Vector2(18, joint_y), Color("63d8ff"), 2.0)
		draw_line(Vector2(342, joint_y), Vector2(353, joint_y), Color("63d8ff"), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(20, 666), "Cyan ticks: upper anchor · source step 106.468px", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e9d6b4"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 690), "Both source modules: 640x480, anchor 320x240.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e9d6b4"))

func _initialize() -> void:
	_run.call_deferred()

func _image_metrics(texture: Texture2D) -> Dictionary:
	var image := texture.get_image()
	var partial_alpha := 0
	var transparent_rgb := 0
	var used := image.get_used_rect()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			var alpha := pixel.a
			if alpha > 0.0 and alpha < 1.0: partial_alpha += 1
			if alpha == 0.0 and (pixel.r > 0.0 or pixel.g > 0.0 or pixel.b > 0.0): transparent_rgb += 1
	return {"size": [image.get_width(), image.get_height()], "alpha_bounds": [used.position.x, used.position.y, used.size.x, used.size.y], "partial_alpha_pixels": partial_alpha, "transparent_pixels_with_rgb": transparent_rgb}

func _empty_overlap_rows(upper: Texture2D, lower: Texture2D) -> int:
	var upper_image := upper.get_image()
	var lower_image := lower.get_image()
	var upper_bounds := upper_image.get_used_rect()
	var lower_bounds := lower_image.get_used_rect()
	var source_step := roundi(FLOOR_STEP)
	var first_row := maxi(lower_bounds.position.y, upper_bounds.position.y - source_step)
	var last_row := mini(lower_bounds.end.y, upper_bounds.end.y - source_step)
	var empty_rows := 0
	for y in range(first_row, last_row):
		var occupied := false
		for x in range(640):
			if lower_image.get_pixel(x, y).a > 0.0 or upper_image.get_pixel(x, y + source_step).a > 0.0:
				occupied = true
				break
		if not occupied: empty_rows += 1
	return empty_rows

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <upper>_over_<lower> <capture.png>")
		quit(2)
		return
	var pieces := args[0].split("_over_")
	if pieces.size() != 2 or pieces[0] not in MATERIALS or pieces[1] not in MATERIALS or pieces[0] == pieces[1]:
		push_error("invalid material orientation")
		quit(2)
		return
	var upper_name: String = pieces[0]
	var lower_name: String = pieces[1]
	var upper_stem := _asset_stem(upper_name)
	var lower_stem := _asset_stem(lower_name)
	var upper := load("res://assets/visual_bible/tower/%s.png" % upper_stem) as Texture2D
	var lower := load("res://assets/visual_bible/tower/%s.png" % lower_stem) as Texture2D
	if upper == null or lower == null:
		push_error("Failed to load selected production material PNGs")
		quit(3)
		return
	for material in [upper_name, lower_name]:
		var geometry_id: String = "brick_terrace" if material == "brick_arch_terrace" else ("brick_cornice" if material.begins_with("brick_cornice") else material)
		var geometry_file: String = "geometry.json" if material == "wood" else geometry_id + "_geometry.json"
		var metadata := JSON.parse_string(FileAccess.get_file_as_string("res://assets/visual_bible/tower/%s" % geometry_file)) as Dictionary
		var canvas_meta: Array = metadata.get("canvas", [])
		var anchor_meta: Array = metadata.get("anchor", [])
		if canvas_meta.size() != 2 or anchor_meta.size() != 2 or int(canvas_meta[0]) != 640 or int(canvas_meta[1]) != 480 or int(anchor_meta[0]) != 320 or int(anchor_meta[1]) != 240 or absf(float(metadata.get("floor_step", 0.0)) - FLOOR_STEP) > 0.001:
			push_error("All facade geometry metadata must share canvas, anchor and floor step")
			quit(4)
			return
	root.size = Vector2i(360, 800)
	root.content_scale_size = root.size
	var canvas := SeamCanvas.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.upper_texture = upper
	canvas.lower_texture = lower
	canvas.upper_name = upper_name
	canvas.lower_name = lower_name
	root.add_child(canvas)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image.save_png(args[1]) != OK:
		push_error("Could not save seam capture")
		quit(5)
		return
	var report := {"capture": args[1], "viewport": [360, 800], "upper_material": upper_name, "lower_material": lower_name,
		"shared_canvas": [640, 480], "shared_anchor": [320, 240], "floor_step_source_px": FLOOR_STEP,
		"sample_scale": SAMPLE_SCALE, "anchor_delta_capture_px": FLOOR_STEP * SAMPLE_SCALE,
		"production_draw_order": "lower first, upper second, upper offset by one floor_step",
		"source_overlap_silhouette_empty_rows": _empty_overlap_rows(upper, lower),
		"upper_source": _image_metrics(upper), "lower_source": _image_metrics(lower)}
	var file := FileAccess.open(args[1].get_basename() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("FACADE_SEAM_CAPTURE %s %s" % [args[0], args[1]])
	quit(0)

func _asset_stem(material: String) -> String:
	if material in ["brick_cornice","brick_cornice_roof_top"]: return material
	var stem := "floor" if material == "wood" else material+"_floor"
	return stem+"_wide"
