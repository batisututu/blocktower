extends SceneTree
## 벽돌 랜드마크 원본: 석재 시계면과 입체 탑체를 기본/아치 벽돌층에 합성한다.
const OUTPUT := "res://assets/visual_bible/tower"
const SIZE := Vector2i(640, 480)
const FLOOR_HEIGHT := 1.18
const SCENES := "res://../art_source/visual_bible/tower_scenes"

func _initialize() -> void:
	_render.call_deferred()

func _material(hex_color: String, roughness: float = .9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex_color)
	material.roughness = roughness
	return material

func _box(parent: Node3D, name: String, at: Vector3, dimensions: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var shape := BoxMesh.new()
	shape.size = dimensions
	node.mesh = shape
	node.material_override = _material(color)
	node.position = at
	parent.add_child(node)
	return node

func _clock_disc(parent: Node3D, name: String, radius: float, depth: float, color: String, z: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = depth
	shape.radial_segments = 32
	node.mesh = shape
	node.material_override = _material(color,.68)
	node.rotation.x = PI / 2.0
	node.position = Vector3(0,.63,z)
	parent.add_child(node)
	return node

func _window(parent: Node3D, x: float, arch: bool) -> void:
	var y := .27
	_box(parent,"WindowShadow_%s" % x,Vector3(x,y+.28,1.018),Vector3(.44,.58,.03),"383b38")
	_box(parent,"WindowGlass_%s" % x,Vector3(x,y+.28,1.04),Vector3(.34,.48,.022),"59675f")
	for side in [-1.0,1.0]:
		_box(parent,"WindowJamb_%s_%s" % [x,side],Vector3(x+side*.245,y+.28,1.064),Vector3(.07,.65,.065),"d0bd94")
	_box(parent,"WindowSill_%s" % x,Vector3(x,y-.04,1.08),Vector3(.56,.09,.10),"e0cfad")
	if arch:
		# 쐐기돌 여섯 점이 인방을 대신해 기존 아치 창과의 공존을 식별시킨다.
		for index in range(7):
			var angle := PI * float(index+1) / 8.0
			var wedge := _box(parent,"Voussoir_%s_%d" % [x,index],Vector3(x+cos(angle)*.29,y+.46+sin(angle)*.16,1.095),Vector3(.12,.09,.075),"dfcaa7")
			wedge.rotation.z = -angle+PI/2.0
	else:
		_box(parent,"WindowLintel_%s" % x,Vector3(x,y+.63,1.06),Vector3(.54,.08,.08),"c9b18b")

func _landmark(parent: Node3D, arch: bool) -> void:
	var tower := Node3D.new()
	tower.name = "ProjectingClockLandmark"
	parent.add_child(tower)
	# 벽에서 앞으로 나온 시계면과 양옆 기둥으로 랜드마크의 깊이를 만든다.
	_box(tower,"LandmarkPlinth",Vector3(0,.12,1.12),Vector3(1.05,.20,.28),"d8c7a2")
	_box(tower,"LandmarkBody",Vector3(0,.57,1.11),Vector3(.78,.86,.28),"9e684f")
	for x in [-.43,.43]:
		_box(tower,"LandmarkPillar_%s" % x,Vector3(x,.57,1.26),Vector3(.12,.86,.15),"e0cfad")
		_box(tower,"PillarCapital_%s" % x,Vector3(x,.99,1.29),Vector3(.20,.11,.20),"f0e1c1")
	_box(tower,"LandmarkLintel",Vector3(0,1.03,1.24),Vector3(1.02,.16,.22),"ead9b8")
	_box(tower,"LandmarkCrownLower",Vector3(0,1.15,1.16),Vector3(.92,.10,.34),"b69568")
	_box(tower,"LandmarkCrownTop",Vector3(0,1.27,1.12),Vector3(.70,.10,.28),"ead9b8")
	_clock_disc(tower,"ClockFaceBacking",.29,.055,"705743",1.30)
	_clock_disc(tower,"ClockFace",.235,.064,"f2e2bf",1.34)
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		_box(tower,"ClockMarker_%02d" % index,Vector3(cos(angle)*.19,.63+sin(angle)*.19,1.39),Vector3(.025,.045,.02),"514b3f")
	var hour := _box(tower,"ClockHourHand",Vector3(-.025,.675,1.405),Vector3(.035,.105,.02),"514b3f")
	hour.rotation.z = -.4
	var minute := _box(tower,"ClockMinuteHand",Vector3(.035,.70,1.41),Vector3(.026,.15,.02),"514b3f")
	minute.rotation.z = .35
	_clock_disc(tower,"ClockPin",.035,.03,"b0915a",1.43)
	if arch:
		# 아치 모듈은 랜드마크 아래 좌우 창에도 벽돌 아치 쐐기돌을 유지한다.
		_box(tower,"ArchVariantMarker",Vector3(0,.04,1.31),Vector3(.54,.055,.08),"d5bf99")

func _floor(arch: bool) -> Node3D:
	var root := _world()
	var floor := Node3D.new()
	floor.name = "BrickLandmarkArchFloorMid" if arch else "BrickLandmarkFloorMid"
	root.add_child(floor)
	_box(floor,"BrickMass",Vector3(0,.58,0),Vector3(2.62,1.12,1.94),"8e5944")
	for y in [.045,1.115]:
		_box(floor,"Belt_%s" % y,Vector3(0,y,0),Vector3(2.78,.105,2.08),"cdbb97")
		_box(floor,"FrontHighlight_%s" % y,Vector3(0,y+.053,.997),Vector3(2.48,.045,.11),"e0cfad")
	for x in [-1.28,1.28]:
		_box(floor,"CornerPilaster_%s" % x,Vector3(x,.59,1.002),Vector3(.16,1.02,.12),"d5c39e")
		_box(floor,"PilasterInset_%s" % x,Vector3(x,.59,1.075),Vector3(.045,.94,.025),"b99b72")
	for row in range(4):
		var y := .17+row*.245
		var offset := .18 if row%2==1 else 0.0
		for column in range(6):
			var x := -1.08+column*.405+offset
			if x > 1.12: continue
			_box(floor,"Brick_%d_%d" % [row,column],Vector3(x,y,.987),Vector3(.375,.195,.045),["a5634c","b26d54","985b47","bd785c","a9654d"][(row*3+column*2)%5])
	_window(floor,-.82,arch)
	_window(floor,.82,arch)
	_landmark(floor,arch)
	return root

func _world() -> Node3D:
	var root := Node3D.new()
	root.name = "BrickLandmarkModule"
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("eee4cf")
	environment.environment.ambient_light_energy = .32
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-38,0)
	light.light_color = Color("fff0d3")
	light.light_energy = .65
	light.shadow_enabled = true
	root.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.1
	camera.position = Vector3(5,2.8,8)
	root.add_child(camera)
	camera.look_at_from_position(camera.position,Vector3.ZERO)
	camera.current = true
	return root

func _own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_own(child,owner_node)

func _capture(scene: Node3D, stem: String, scene_dir: String, output_dir: String) -> void:
	_own(scene,scene)
	var packed := PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,scene_dir.path_join(stem+".tscn"))==OK)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output_dir.path_join(stem+".png"))==OK)
	root.remove_child(viewport)
	viewport.queue_free()
	await process_frame

func _render() -> void:
	var output_dir := ProjectSettings.globalize_path(OUTPUT)
	var scene_dir := ProjectSettings.globalize_path(SCENES)
	DirAccess.make_dir_recursive_absolute(output_dir)
	DirAccess.make_dir_recursive_absolute(scene_dir)
	for variant in [{"stem":"brick_landmark_floor_mid","arch":false},{"stem":"brick_arch_landmark_floor_mid","arch":true}]:
		await _capture(_floor(variant.arch),variant.stem,scene_dir,output_dir)
	var metadata := {"canvas":[640,480],"anchor":[320,240],"floor_step":106.4683685,"floor_height":FLOOR_HEIGHT,"camera":[5,2.8,8],"camera_size":5.1,"variants":["brick_landmark_floor_mid","brick_arch_landmark_floor_mid"],"origin":"original code-authored Godot 3D geometry; no external model or texture"}
	var file := FileAccess.open(OUTPUT+"/brick_landmark_geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"\t")+"\n")
	file.close()
	print("BRICK_LANDMARK_RENDER ",metadata)
	quit()
