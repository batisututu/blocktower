extends SceneTree
## 벽돌 아치 창문 파츠 원본: 기존 벽돌 모듈 위에 쐐기돌 아치와 아치형 유리를 더한다.
const OUTPUT := "res://assets/visual_bible/tower"
const FLOOR_HEIGHT := 1.18
const VIEW_SIZE := Vector2i(640,480)
var viewport: SubViewport
var world: Node3D
var model: Node3D
var materials: Dictionary = {}

func _initialize() -> void:
	_render.call_deferred()

func material(color: String) -> StandardMaterial3D:
	if materials.has(color): return materials[color]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color).darkened(.18)
	result.roughness = .92
	materials[color] = result
	return result

func box(at: Vector3, dimensions: Vector3, color: String, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = at
	(model if parent == null else parent).add_child(mesh)
	return mesh

func window_unit(x: float, parent: Node3D, doorway: bool = false) -> void:
	var width := .54 if doorway else .42
	var height := .77 if doorway else .58
	var y := .10 if doorway else .27
	box(Vector3(x,y+height/2,1.012),Vector3(width,height,.026),"343735",parent)
	box(Vector3(x,y+height/2,1.031),Vector3(width-.09,height-.10,.018),"53645c",parent)
	# 사각 창틀과 중앙 세로·가로살은 목재 아치창과 다른 읽힘을 만든다.
	for side in [-1,1]:
		box(Vector3(x+side*(width/2+.025),y+height/2,1.055),Vector3(.065,height+.08,.055),"d0bd94",parent)
	box(Vector3(x,y-.035,1.058),Vector3(width+.14,.105,.12),"d7c6a3",parent)
	box(Vector3(x,y+height+.035,1.050),Vector3(width+.09,.075,.075),"c9b18b",parent)
	if doorway:
		box(Vector3(x,y+height/2,1.066),Vector3(.035,height-.06,.026),"886b45",parent)
		box(Vector3(x,y+.20,1.068),Vector3(width-.08,.035,.025),"886b45",parent)
		box(Vector3(x+width*.27,y+.38,1.083),Vector3(.035,.035,.018),"efc06b",parent)
	else:
		box(Vector3(x,y+height/2,1.065),Vector3(.032,height-.08,.028),"e1d0ac",parent)
		box(Vector3(x,y+height*.55,1.066),Vector3(width-.06,.035,.028),"e1d0ac",parent)
	# 창 상부를 직선 상인방 대신 부채꼴 쐐기돌 아치로 감싼다.
	var radius := width*.62
	var center_y := y+height-.07
	for wedge in range(7):
		var angle := PI*float(wedge+1)/8.0
		var px := cos(angle)*radius
		var py := center_y+sin(angle)*.22
		var stone := box(Vector3(x+px,py,1.103),Vector3(.145,.105,.105),"d7c19b" if wedge != 3 else "ead7b1",parent)
		stone.rotation.z = -angle+PI/2
	# 둥근 상부 유리 윤곽을 다각형 표면으로 만들어 네모창과 읽힘을 분리한다.
	var glass_points: Array[Vector2] = [Vector2(-width*.46,y+.11),Vector2(width*.46,y+.11),Vector2(width*.46,center_y)]
	for arc in range(1,9):
		var angle := PI*float(arc)/8.0
		glass_points.append(Vector2(cos(angle)*width*.46,center_y+sin(angle)*.165))
	glass_points.append(Vector2(-width*.46,center_y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array([Vector3.ZERO])
	for point in glass_points: vertices.append(Vector3(point.x,point.y,1.087))
	var indices := PackedInt32Array()
	for i in range(1,vertices.size()-1): indices.append_array(PackedInt32Array([0,i,i+1]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var arch_mesh := ArrayMesh.new()
	arch_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var arch_glass := MeshInstance3D.new()
	arch_glass.mesh = arch_mesh
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color("5a7068")
	glass_material.roughness = .72
	arch_glass.material_override = glass_material
	arch_glass.position.x = x
	parent.add_child(arch_glass)

func floor_module(tier: float, entry: bool = false) -> Node3D:
	var building := Node3D.new()
	building.scale = Vector3(tier,1,tier)
	model.add_child(building)
	box(Vector3(0,.58,0),Vector3(2.62,1.12,1.94),"8e5944",building)
	# 두께가 보이는 띠장과 모서리 기둥으로 층 구조를 잡는다.
	for y in [.045,1.115]:
		box(Vector3(0,y,0),Vector3(2.78,.105,2.08),"cdbb97",building)
		box(Vector3(0,y+.053,.997),Vector3(2.48,.045,.11),"e0cfad",building)
	for x in [-1.28,1.28]:
		box(Vector3(x,.59,1.002),Vector3(.16,1.02,.12),"d5c39e",building)
		box(Vector3(x,.59,1.075),Vector3(.045,.94,.025),"b99b72",building)
	# 개별 입체 벽돌을 교차 줄눈으로 배치한다. 색 배치는 좌표 기반으로 고정한다.
	for row in range(4):
		var y := .17+row*.245
		var offset := .18 if row%2 == 1 else 0.0
		for column in range(6):
			var x := -1.08+column*.405+offset
			if x > 1.12: continue
			var shade: String = ["a5634c","b26d54","985b47","bd785c","a9654d"][(row*3+column*2)%5]
			box(Vector3(x,y,.987),Vector3(.375,.195,.045),shade,building)
	# 좁은 측면에도 벽돌 결이 이어진다.
	var side := Node3D.new()
	building.add_child(side)
	side.rotation.y = PI/2
	side.position.x = 1.326
	for row in range(4):
		var y := .17+row*.245
		var offset := .20 if row%2 == 1 else 0.0
		for column in range(4):
			var z := -.67+column*.43+offset
			box(Vector3(z,y,0),Vector3(.40,.195,.045),["a5634c","b26d54","985b47","bd785c"][(row+column*2)%4],side)
	for x in [-.72,0,.72]:
		window_unit(x,building,entry and x == 0)
	# 출입구 측면의 짧은 석재 계단띠는 첫 모듈만 갖는다.
	if entry:
		for step in range(2):
			box(Vector3(0,-.015-step*.09,1.19+step*.13),Vector3(.88,.09,.24),"b8a681",building)
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
		model.name = "brick_arch_"+part
		world.add_child(model)
		match part:
			"floor_entry": floor_module(1.0,true)
			"floor_wide": floor_module(1.0)
			"floor_mid": floor_module(.83)
			"floor_top": floor_module(.66)
		own_tree(world,world)
		var packed := PackedScene.new()
		assert(packed.pack(world) == OK)
		assert(ResourceSaver.save(packed,scene_directory.path_join("brick_arch_"+part+".tscn")) == OK)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		assert(image.save_png(OUTPUT.path_join("brick_arch_"+part+".png")) == OK)
		world.remove_child(model)
		model.queue_free()
	var step := camera.unproject_position(Vector3.ZERO).y-camera.unproject_position(Vector3(0,FLOOR_HEIGHT,0)).y
	records["floor_step"] = step
	var file := FileAccess.open(OUTPUT.path_join("brick_arch_geometry.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	file.close()
	print("BRICK_ARCH_TOWER_RENDER ",records)
	viewport.queue_free()
	await process_frame
	quit()
