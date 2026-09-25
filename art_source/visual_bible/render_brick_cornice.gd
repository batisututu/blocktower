extends SceneTree
## 벽돌 코니스 원본: 수평 마감과 기존 지붕을 살린 장식 지붕 마감을 만든다.
const OUTPUT := "res://assets/visual_bible/tower"
const SIZE := Vector2i(640, 480)
const STEP := 106.4683685
const SCENES := "res://../art_source/visual_bible/tower_scenes"

func _initialize() -> void:
	_render.call_deferred()

func _material(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .86
	return material

func _box(parent: Node3D, name: String, at: Vector3, dimensions: Vector3, color: String) -> void:
	var node := MeshInstance3D.new()
	node.name = name
	var shape := BoxMesh.new()
	shape.size = dimensions
	node.mesh = shape
	node.material_override = _material(color)
	node.position = at
	parent.add_child(node)

func _world() -> Node3D:
	var root := Node3D.new()
	root.name = "BrickCorniceModule"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("eee4cf")
	env.environment.ambient_light_energy = .32
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(env)
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
	camera.look_at_from_position(Vector3(5,2.8,8),Vector3.ZERO)
	camera.current = true
	return root

func _horizontal(root: Node3D) -> void:
	var stone := Node3D.new()
	stone.name = "ProjectingLimestoneCornice"
	root.add_child(stone)
	# 돌출 상판과 그림자 띠가 벽돌 층의 수평 경계를 닫는다.
	_box(stone,"UpperCoping",Vector3(0,.22,0),Vector3(3.06,.14,2.34),"e0d0ad")
	_box(stone,"ShadowCourse",Vector3(0,.125,0),Vector3(2.82,.08,2.14),"79654d")
	_box(stone,"FrontFrieze",Vector3(0,.015,1.12),Vector3(2.78,.22,.12),"c5ae85")
	_box(stone,"FrontHighlight",Vector3(0,.12,1.19),Vector3(2.96,.055,.08),"f0e1c1")
	# 반복 치형 장식과 아래 받침돌로 석재 구조를 분명히 한다.
	for x in [-1.25,-.82,-.39,.04,.47,.90,1.25]:
		_box(stone,"Dentil_%0.2f" % x,Vector3(x,-.025,1.205),Vector3(.24,.16,.10),"e5d4b1")
		_box(stone,"Corbel_%0.2f" % x,Vector3(x,-.16,1.04),Vector3(.14,.14,.16),"a58c66")
	for sign in [-1.0,1.0]:
		_box(stone,"SideFrieze_%d" % int(sign),Vector3(sign*1.48,.015,0),Vector3(.10,.22,2.16),"c5ae85")
		_box(stone,"SideHighlight_%d" % int(sign),Vector3(sign*1.53,.12,0),Vector3(.06,.055,2.26),"f0e1c1")

func _roof(root: Node3D, tier: float, label: String) -> void:
	var module := Node3D.new()
	module.name = "BrickDecoratedRoof_"+label
	module.scale = Vector3(tier,1,tier)
	root.add_child(module)
	_box(module,"RoofBase",Vector3(0,.04,0),Vector3(2.87,.08,2.2),"d8c9a2")
	var roof := MeshInstance3D.new()
	roof.name = "ExistingHipRoofSilhouette"
	var shape := CylinderMesh.new()
	shape.top_radius = .24
	shape.bottom_radius = 1.99
	shape.height = 1.24
	shape.radial_segments = 4
	roof.mesh = shape
	roof.scale.z = .78
	roof.rotation.y = PI/4
	roof.position.y = .70
	var tiles := _material("805445")
	roof.material_override = tiles
	module.add_child(roof)
	# 석회암 띠와 치형은 기존 지붕 하단에 붙어 지붕 실루엣을 보존한다.
	_box(module,"RoofCorniceBand",Vector3(0,.045,1.105),Vector3(2.94,.19,.15),"e0d0ad")
	_box(module,"RoofBandShadow",Vector3(0,-.055,1.08),Vector3(2.78,.07,.16),"79654d")
	for x in [-1.18,-.78,-.39,0,.39,.78,1.18]:
		_box(module,"RoofDentil_%0.2f" % x,Vector3(x,-.055,1.19),Vector3(.20,.13,.09),"f0e1c1")
		_box(module,"RoofMerlon_%0.2f" % x,Vector3(x,.18,1.13),Vector3(.14,.12,.11),"c5ae85")
	# 세 기존 지붕에 있던 금색 깃대와 깃발 실루엣을 장식 지붕에서도 유지한다.
	_box(module,"GoldFinialSocket",Vector3(0,1.34,0),Vector3(.17,.08,.17),"b99752")
	_box(module,"GoldFinialPole",Vector3(0,1.52,0),Vector3(.045,.34,.045),"9b7539")
	_box(module,"GoldFlag",Vector3(.15,1.63,0),Vector3(.28,.16,.035),"d5a83e")

func _own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_own(child,owner_node)

func _capture(scene_root: Node3D, stem: String, scene_dir: String, output_dir: String) -> void:
	_own(scene_root,scene_root)
	var packed := PackedScene.new()
	assert(packed.pack(scene_root)==OK)
	assert(ResourceSaver.save(packed,scene_dir.path_join(stem+".tscn"))==OK)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene_root)
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
	var horizontal := _world()
	_horizontal(horizontal)
	await _capture(horizontal,"brick_cornice",scene_dir,output_dir)
	for item in [{"stem":"brick_cornice_roof_wide","tier":1.0},{"stem":"brick_cornice_roof_mid","tier":.83},{"stem":"brick_cornice_roof_top","tier":.66}]:
		var roof_root := _world()
		_roof(roof_root,item.tier,item.stem)
		await _capture(roof_root,item.stem,scene_dir,output_dir)
	var geometry := {"canvas":[640,480],"anchor":[320,240],"camera":[5,2.8,8],"camera_size":5.1,"floor_step":STEP,"origin":"original code-authored Godot 3D geometry; no external models or textures","variants":["horizontal","roof_wide","roof_mid","roof_top"]}
	var file := FileAccess.open(OUTPUT+"/brick_cornice_geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(geometry,"\t")+"\n")
	file.close()
	print("BRICK_CORNICE_RENDER ",geometry)
	quit()
