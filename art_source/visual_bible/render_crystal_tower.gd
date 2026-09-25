extends SceneTree
## 크리스털 외벽 원본: 육각 결정 기둥과 절제된 삼각 유리 면.
const OUTPUT := "res://assets/visual_bible/tower"
const FLOOR_HEIGHT := 1.18
const VIEW_SIZE := Vector2i(640, 480)
var viewport: SubViewport
var world: Node3D
var model: Node3D
var materials: Dictionary = {}

func _initialize() -> void:
	_render.call_deferred()

func material(kind: String) -> StandardMaterial3D:
	if materials.has(kind): return materials[kind]
	var result := StandardMaterial3D.new()
	match kind:
		"pane":
			result.albedo_color = Color("79c9da", .30)
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.roughness = .2
			result.cull_mode = BaseMaterial3D.CULL_DISABLED
			result.emission_enabled = true
			result.emission = Color("3a8fbb")
			result.emission_energy_multiplier = .24
		"facet_a":
			result.albedo_color = Color("9de5df", .48)
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.roughness = .17
			result.cull_mode = BaseMaterial3D.CULL_DISABLED
			result.emission_enabled = true
			result.emission = Color("63b6c4")
			result.emission_energy_multiplier = .34
		"facet_b":
			result.albedo_color = Color("b9a8df", .36)
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.roughness = .22
			result.cull_mode = BaseMaterial3D.CULL_DISABLED
			result.emission_enabled = true
			result.emission = Color("8475bb")
			result.emission_energy_multiplier = .22
		_:
			result.albedo_color = Color(kind)
			result.metallic = .08
			result.roughness = .48
			result.metallic_specular = .32
	materials[kind] = result
	return result

func box(at: Vector3, dimensions: Vector3, kind: String, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.material_override = material(kind)
	mesh.position = at
	(model if parent == null else parent).add_child(mesh)
	return mesh

func crystal_pillar(at: Vector3, height: float, parent: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	var crystal := CylinderMesh.new()
	crystal.top_radius = .085
	crystal.bottom_radius = .16
	crystal.height = height
	crystal.radial_segments = 6
	mesh.mesh = crystal
	mesh.material_override = material("79bfc9")
	mesh.position = at
	mesh.rotation_degrees.y = 30
	parent.add_child(mesh)
	# 한쪽 면에 좁은 빛줄기를 두어 육각 절단면을 작은 크기에서도 구분한다.
	box(at + Vector3(0, 0, .13), Vector3(.035, height * .82, .025), "c9f1e8", parent)

func facet_triangle(a: Vector3, b: Vector3, c: Vector3, kind: String, parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material(kind))
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(b)
	surface.generate_normals()
	var triangle := MeshInstance3D.new()
	triangle.mesh = surface.commit()
	parent.add_child(triangle)

func facet_window(x: float, y: float, width: float, height: float, parent: Node3D, entry: bool = false) -> void:
	var w := width * (.83 if entry else 1.0)
	var h := height * (1.0 if entry else .84)
	var mid := Vector3(x, y + h * .5, 1.065)
	var left_bottom := Vector3(x - w * .5, y, 1.065)
	var left_top := Vector3(x - w * .5, y + h, 1.065)
	var right_bottom := Vector3(x + w * .5, y, 1.065)
	var right_top := Vector3(x + w * .5, y + h, 1.065)
	box(Vector3(x, y + h * .5, 1.015), Vector3(w, h, .035), "pane", parent)
	var peak := mid + Vector3(-w * .08, h * .06, .035)
	facet_triangle(left_bottom, left_top, peak, "facet_a", parent)
	facet_triangle(left_bottom, peak, right_bottom, "facet_b", parent)
	facet_triangle(peak, left_top, right_top, "facet_b", parent)
	facet_triangle(peak, right_top, right_bottom, "facet_a", parent)
	for edge in [-1.0, 1.0]:
		box(Vector3(x + edge * w * .53, y + h * .5, 1.105), Vector3(.055, h + .12, .075), "86b7c0", parent)
	box(Vector3(x, y - .025, 1.105), Vector3(w + .13, .075, .075), "a6d8d3", parent)
	box(Vector3(x, y + h + .025, 1.105), Vector3(w + .13, .07, .075), "a6d8d3", parent)
	if entry:
		box(Vector3(x + w * .26, y + .38, 1.14), Vector3(.025, .10, .025), "f1d99b", parent)

func floor_module(tier: float, entry: bool = false) -> Node3D:
	var building := Node3D.new()
	building.scale = Vector3(tier, 1, tier)
	model.add_child(building)
	# 투명한 결정판 슬래브와 얇은 테두리 띠가 각 층을 분리한다.
	box(Vector3(0, .58, 0), Vector3(2.62, 1.12, 1.94), "4d6684", building)
	for y in [.045, 1.115]:
		box(Vector3(0, y, 0), Vector3(2.78, .085, 2.08), "789aaa" if y > 1.0 else "7fadb1", building)
		box(Vector3(0, y + .045, 1.025), Vector3(2.48, .035, .11), "d0ece0", building)
	# 네 모서리 기둥은 원통이 아닌 절단된 육각 결정 실루엣이다.
	for x in [-1.29, 1.29]:
		crystal_pillar(Vector3(x, .59, 1.005), 1.02, building)
	for x in [-.82, 0.0, .82]:
		facet_window(x, .18, .60, .76 if entry and x == 0.0 else .60, building, entry and x == 0.0)
	# 측면 유리 면과 각진 연결살을 꺾어 붙여 다면체 구조를 이어간다.
	var side := Node3D.new()
	building.add_child(side)
	side.rotation.y = PI / 2
	side.position.x = .245
	for z in [-.52, .18, .82]:
		facet_window(z, .20, .47, .62, side)
	if entry:
		for step in range(2):
			box(Vector3(0, -.015 - step * .09, 1.20 + step * .13), Vector3(.98, .085, .22), "7baab5", building)
	return building

func own_tree(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own_tree(child, owner_node)

func _render() -> void:
	viewport = SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e8f3f0")
	environment.environment.ambient_light_energy = .34
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -38, 0)
	key.light_color = Color("e8f6ff")
	key.light_energy = .62
	key.shadow_enabled = true
	world.add_child(key)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.1
	camera.position = Vector3(5, 2.8, 8)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var scene_directory := ProjectSettings.globalize_path("res://").path_join("../art_source/visual_bible/tower_scenes").simplify_path()
	DirAccess.make_dir_recursive_absolute(scene_directory)
	var records := {"canvas": [640, 480], "anchor": [320, 240], "floor_height": FLOOR_HEIGHT, "camera": [5, 2.8, 8], "camera_size": 5.1}
	for part in ["floor_entry", "floor_wide", "floor_mid", "floor_top"]:
		model = Node3D.new()
		model.name = "crystal_" + part
		world.add_child(model)
		match part:
			"floor_entry": floor_module(1.0, true)
			"floor_wide": floor_module(1.0)
			"floor_mid": floor_module(.83)
			"floor_top": floor_module(.66)
		own_tree(world, world)
		var packed := PackedScene.new()
		assert(packed.pack(world) == OK)
		assert(ResourceSaver.save(packed, scene_directory.path_join("crystal_" + part + ".tscn")) == OK)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		assert(image.save_png(OUTPUT.path_join("crystal_" + part + ".png")) == OK)
		world.remove_child(model)
		model.queue_free()
	var step := camera.unproject_position(Vector3.ZERO).y - camera.unproject_position(Vector3(0, FLOOR_HEIGHT, 0)).y
	records["floor_step"] = step
	var file := FileAccess.open(OUTPUT.path_join("crystal_geometry.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	print("CRYSTAL_TOWER_RENDER ", records)
	viewport.queue_free()
	await process_frame
	quit()
