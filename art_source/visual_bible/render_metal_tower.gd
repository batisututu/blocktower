extends SceneTree
## 금속·유리 외벽 원본: 강철 커튼월 프레임과 큰 유리창.
const OUTPUT := "res://assets/visual_bible/tower"
const FLOOR_HEIGHT := 1.18
const VIEW_SIZE := Vector2i(640,480)
var viewport: SubViewport
var world: Node3D
var model: Node3D
var materials: Dictionary = {}

func _initialize() -> void:
	_render.call_deferred()

func material(kind: String) -> StandardMaterial3D:
	if materials.has(kind): return materials[kind]
	var result := StandardMaterial3D.new()
	if kind == "glass":
		result.albedo_color = Color("a4e3dc",.78)
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.metallic = .08
		result.roughness = .24
		result.emission_enabled = true
		result.emission = Color("4a7975")
		result.emission_energy_multiplier = .32
	else:
		result.albedo_color = Color(kind)
		result.metallic = .78
		result.roughness = .34
		result.metallic_specular = .7
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

func window_bay(x: float, parent: Node3D, door: bool = false) -> void:
	var width := .58 if door else .68
	var height := .82 if door else .70
	var y := .10 if door else .21
	# 큰 반투명 유리를 먼저 두고 외곽 스틸 프레임/멀리언을 겹친다.
	box(Vector3(x,y+height/2,1.012),Vector3(width,height,.035),"glass",parent)
	for side in [-1,1]:
		box(Vector3(x+side*(width/2+.026),y+height/2,1.065),Vector3(.075,height+.10,.095),"43565a",parent)
	box(Vector3(x,y-.035,1.07),Vector3(width+.15,.105,.105),"3b4c53",parent)
	box(Vector3(x,y+height+.035,1.07),Vector3(width+.10,.085,.10),"3b4c53",parent)
	# 한 칸의 큰 유리판을 둘로 나누는 세로살, 얇은 수평 트랜섬.
	box(Vector3(x,y+height/2,1.085),Vector3(.045,height-.045,.055),"60777c",parent)
	box(Vector3(x,y+height*.58,1.086),Vector3(width-.06,.045,.055),"60777c",parent)
	if door:
		box(Vector3(x+width*.28,y+.40,1.105),Vector3(.035,.12,.035),"e5bd79",parent)
		for step in range(2):
			box(Vector3(x,-.015-step*.09,1.20+step*.13),Vector3(1.02,.09,.24),"829091",parent)

func floor_module(tier: float, entry: bool = false) -> Node3D:
	var building := Node3D.new()
	building.scale = Vector3(tier,1,tier)
	model.add_child(building)
	# 층을 받치는 얇은 구조 슬래브와 외곽 빔.
	box(Vector3(0,.58,0),Vector3(2.62,1.12,1.94),"39494d",building)
	for y in [.045,1.115]:
		box(Vector3(0,y,0),Vector3(2.78,.105,2.08),"607176",building)
		box(Vector3(0,y+.055,1.02),Vector3(2.50,.045,.12),"a6b7b4",building)
	# 모서리 기둥과 촘촘한 세로 프레임이 금속 커튼월 실루엣을 만든다.
	for x in [-1.28,1.28]:
		box(Vector3(x,.59,1.015),Vector3(.17,1.04,.15),"34444b",building)
		box(Vector3(x,.59,1.098),Vector3(.045,.94,.035),"b6c5bd",building)
	var bays := [-.83,0.0,.83]
	for x in bays:
		window_bay(x,building,entry and x==0.0)
	# 좁은 측면에도 큰 유리 면과 구조선을 이어 모서리에서 단절되지 않게 한다.
	var side := Node3D.new()
	building.add_child(side)
	side.rotation.y = PI/2
	side.position.x = 1.326
	for z in [-.52,.20,.83]:
		box(Vector3(z,.58,0),Vector3(.60,.68,.035),"glass",side)
		for dx in [-.34,.34]:
			box(Vector3(z+dx,.58,.05),Vector3(.055,.78,.09),"34444b",side)
		box(Vector3(z,.58,.075),Vector3(.035,.68,.045),"60777c",side)
	return building

func own_tree(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own_tree(child,owner_node)

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
	environment.environment.ambient_light_color = Color("eee4cf")
	environment.environment.ambient_light_energy = .32
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48,-38,0)
	key.light_color = Color("fff0d3")
	key.light_energy = .65
	key.shadow_enabled = true
	world.add_child(key)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.1
	camera.position = Vector3(5,2.8,8)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var scene_directory := ProjectSettings.globalize_path("res://").path_join("../art_source/visual_bible/tower_scenes").simplify_path()
	DirAccess.make_dir_recursive_absolute(scene_directory)
	var records := {"canvas":[640,480],"anchor":[320,240],"floor_height":FLOOR_HEIGHT,"camera":[5,2.8,8],"camera_size":5.1}
	for part in ["floor_entry","floor_wide","floor_mid","floor_top"]:
		model = Node3D.new()
		model.name = "metal_"+part
		world.add_child(model)
		match part:
			"floor_entry": floor_module(1.0,true)
			"floor_wide": floor_module(1.0)
			"floor_mid": floor_module(.83)
			"floor_top": floor_module(.66)
		own_tree(world,world)
		var packed := PackedScene.new()
		assert(packed.pack(world) == OK)
		assert(ResourceSaver.save(packed,scene_directory.path_join("metal_"+part+".tscn")) == OK)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		assert(image.save_png(OUTPUT.path_join("metal_"+part+".png")) == OK)
		world.remove_child(model)
		model.queue_free()
	var step := camera.unproject_position(Vector3.ZERO).y-camera.unproject_position(Vector3(0,FLOOR_HEIGHT,0)).y
	records["floor_step"] = step
	var file := FileAccess.open(OUTPUT.path_join("metal_geometry.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	file.close()
	print("METAL_TOWER_RENDER ",records)
	viewport.queue_free()
	await process_frame
	quit()
