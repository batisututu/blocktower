extends SceneTree
## Two-floor seam proof using the production tower PNGs and stacking anchor.

const FLOOR_STEP := 106.468368530273
const SAMPLE_SCALE := 0.5
const WOOD_PATH := "res://assets/visual_bible/tower/floor_wide.png"
const BRICK_PATH := "res://assets/visual_bible/tower/brick_floor_wide.png"
const BRICK_MID_PATH := "res://assets/visual_bible/tower/brick_floor_mid.png"
const BRICK_ARCH_MID_PATH := "res://assets/visual_bible/tower/brick_arch_floor_mid.png"
const LANDMARK_PATH := "res://assets/visual_bible/tower/brick_landmark_floor_mid.png"
const ARCH_LANDMARK_PATH := "res://assets/visual_bible/tower/brick_arch_landmark_floor_mid.png"
const TERRACE_PATH := "res://assets/visual_bible/tower/brick_terrace_floor_wide.png"
const CORNICE_TOP_PATH := "res://assets/visual_bible/tower/brick_cornice_roof_top.png"
const GEOMETRY_PATH := "res://assets/visual_bible/tower/geometry.json"
const BRICK_GEOMETRY_PATH := "res://assets/visual_bible/tower/brick_geometry.json"

class SeamCanvas extends Control:
	var upper_texture: Texture2D
	var lower_texture: Texture2D
	var upper_name := ""
	var lower_name := ""
	var floor_step := FLOOR_STEP
	var sample_scale := SAMPLE_SCALE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("17191e"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 48), "WOOD / BRICK JOINT SAMPLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f8ead2"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 78), "Upper: %s    Lower: %s" % [upper_name, lower_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e9d6b4"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 104), "Shared anchor delta: %.3f px at %.0f%% scale" % [floor_step * sample_scale, sample_scale * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e9d6b4"))
		# Checkerboard makes each render's transparent alpha edge visible in the capture.
		var checker_rect := Rect2(20, 300, 320, 320)
		var tile := 16
		for y in range(0, 320, tile):
			for x in range(0, 320, tile):
				var alternate := (floori(float(x) / tile) + floori(float(y) / tile)) % 2 == 0
				draw_rect(Rect2(checker_rect.position + Vector2(x, y), Vector2(tile, tile)), Color("35383f") if alternate else Color("24272d"))
		var anchor := Vector2(size.x * 0.5, 520.0)
		var rect := Rect2(anchor - Vector2(320, 240) * sample_scale, Vector2(640, 480) * sample_scale)
		# This is the same render order and vertical offset used by puzzle_screen._draw_tower.
		draw_texture_rect(lower_texture, rect, false)
		draw_texture_rect(upper_texture, Rect2(rect.position - Vector2(0, floor_step * sample_scale), rect.size), false)
		var joint_y := anchor.y - floor_step * sample_scale
		draw_line(Vector2(7, joint_y), Vector2(18, joint_y), Color("63d8ff"), 2.0)
		draw_line(Vector2(342, joint_y), Vector2(353, joint_y), Color("63d8ff"), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(20, 666), "Cyan ticks: upper anchor · displayed step: 53.234 px", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e9d6b4"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 690), "Both source modules: 640x480, anchor 320x240.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e9d6b4"))

func _initialize() -> void:
	_run.call_deferred()

func _used_alpha_metrics(texture: Texture2D) -> Dictionary:
	var image := texture.get_image()
	var used := image.get_used_rect()
	var partial_alpha := 0
	var transparent_rgb_nonzero := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.0 and pixel.a < 1.0:
				partial_alpha += 1
			elif pixel.a == 0.0 and (pixel.r > 0.0 or pixel.g > 0.0 or pixel.b > 0.0):
				transparent_rgb_nonzero += 1
	return {
		"size": [image.get_width(), image.get_height()],
		"alpha_bounds": [used.position.x, used.position.y, used.size.x, used.size.y],
		"partial_alpha_pixels": partial_alpha,
		"transparent_pixels_with_rgb": transparent_rgb_nonzero
	}

func _silhouette_gap_rows(upper: Texture2D, lower: Texture2D) -> int:
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
		if not occupied:
			empty_rows += 1
	return empty_rows

func _write_report(path: String, upper_name: String, lower_name: String, upper_texture: Texture2D, lower_texture: Texture2D, capture_path: String) -> void:
	var report := {
		"capture": capture_path,
		"viewport": [360, 800],
		"upper_material": upper_name,
		"lower_material": lower_name,
		"shared_canvas": [640, 480],
		"shared_anchor": [320, 240],
		"floor_step_source_px": FLOOR_STEP,
		"sample_scale": SAMPLE_SCALE,
		"anchor_delta_capture_px": FLOOR_STEP * SAMPLE_SCALE,
		"production_draw_order": "lower module first, upper module second, upper texture offset by one floor_step",
		"source_overlap_silhouette_empty_rows": _silhouette_gap_rows(upper_texture, lower_texture),
		"upper_source": _used_alpha_metrics(upper_texture),
		"lower_source": _used_alpha_metrics(lower_texture)
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pairs := {
		"wood_over_brick":{"upper":"wood","lower":"brick"},
		"brick_over_wood":{"upper":"brick","lower":"wood"},
		"landmark_over_brick":{"upper":"landmark","lower":"brick_mid"},
		"brick_over_landmark":{"upper":"brick_mid","lower":"landmark"},
		"arch_landmark_over_arch":{"upper":"arch_landmark","lower":"arch_mid"},
		"arch_over_arch_landmark":{"upper":"arch_mid","lower":"arch_landmark"},
		"landmark_over_terrace":{"upper":"landmark","lower":"terrace"},
		"cornice_roof_over_landmark":{"upper":"cornice_top","lower":"landmark"}
	}
	if args.size() < 2 or not pairs.has(args[0]):
		push_error("usage: -- <registered-seam-case> <capture.png>")
		quit(2)
		return
	var order := args[0]
	var capture_path := args[1]
	var sources := {
		"wood":WOOD_PATH,"brick":BRICK_PATH,"brick_mid":BRICK_MID_PATH,
		"arch_mid":BRICK_ARCH_MID_PATH,"landmark":LANDMARK_PATH,
		"arch_landmark":ARCH_LANDMARK_PATH,"terrace":TERRACE_PATH,
		"cornice_top":CORNICE_TOP_PATH
	}
	var geometry := JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH)) as Dictionary
	var brick_geometry := JSON.parse_string(FileAccess.get_file_as_string(BRICK_GEOMETRY_PATH)) as Dictionary
	var wood_canvas: Array = geometry.get("canvas", [])
	var brick_canvas: Array = brick_geometry.get("canvas", [])
	var wood_anchor: Array = geometry.get("anchor", [])
	var brick_anchor: Array = brick_geometry.get("anchor", [])
	if wood_canvas.size() != 2 or brick_canvas.size() != 2 or wood_anchor.size() != 2 or brick_anchor.size() != 2 or int(wood_canvas[0]) != 640 or int(wood_canvas[1]) != 480 or int(brick_canvas[0]) != 640 or int(brick_canvas[1]) != 480 or int(wood_anchor[0]) != 320 or int(wood_anchor[1]) != 240 or int(brick_anchor[0]) != 320 or int(brick_anchor[1]) != 240 or absf(float(geometry.get("floor_step", 0.0)) - FLOOR_STEP) > 0.001 or absf(float(brick_geometry.get("floor_step", 0.0)) - FLOOR_STEP) > 0.001:
		push_error("Wood and brick geometry metadata must share canvas, anchor, and floor step")
		quit(4)
		return
	var upper_name: String = pairs[order].upper
	var lower_name: String = pairs[order].lower
	var upper := load(sources[upper_name]) as Texture2D
	var lower := load(sources[lower_name]) as Texture2D
	if upper == null or lower == null:
		push_error("Failed to load seam source pair %s / %s" % [upper_name,lower_name])
		quit(3)
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
	canvas.floor_step = FLOOR_STEP
	canvas.sample_scale = SAMPLE_SCALE
	root.add_child(canvas)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var save_error := image.save_png(capture_path)
	if save_error != OK:
		push_error("Could not save seam capture: %s" % error_string(save_error))
		quit(5)
		return
	_write_report(capture_path.get_basename() + ".json", upper_name, lower_name, upper, lower, capture_path)
	print("BRICK_SEAM_CAPTURE %s %s" % [order, capture_path])
	quit(0)
