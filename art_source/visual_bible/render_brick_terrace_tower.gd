extends SceneTree
## 벽돌 테라스 파츠 원본: 기존 벽돌/아치 층 위에 돌출 바닥과 난간을 더한다.
const OUTPUT := "res://assets/visual_bible/tower"
const VIEW_SIZE := Vector2i(640, 480)
const FLOOR_STEP := 106.4683685
var viewport: SubViewport

func _initialize() -> void:
	_render.call_deferred()

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .84
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)

func _terrace(model: Node3D, owner_node: Node) -> void:
	var balcony := Node3D.new()
	balcony.name = "BrickTerraceOriginalGeometry"
	model.add_child(balcony)
	balcony.owner = owner_node
	var limestone := Color("d4c29d")
	var highlight := Color("ead9b8")
	var shadow := Color("9f8966")
	# 돌출 바닥과 하부 받침이 입면 밖으로 이어진다.
	_box(balcony, Vector3(0, 1.16, 1.31), Vector3(3.02, .14, .72), limestone)
	_box(balcony, Vector3(0, 1.07, 1.30), Vector3(2.70, .08, .54), shadow)
	_box(balcony, Vector3(0, 1.245, 1.34), Vector3(2.92, .045, .64), highlight)
	# 전면 난간은 작은 기둥과 두 줄 가로대로 구성한다.
	for x in [-1.36, -.91, -.455, 0.0, .455, .91, 1.36]:
		_box(balcony, Vector3(x, 1.43, 1.63), Vector3(.095, .38, .095), limestone)
		_box(balcony, Vector3(x, 1.635, 1.63), Vector3(.14, .06, .14), highlight)
	_box(balcony, Vector3(0, 1.62, 1.63), Vector3(2.91, .105, .13), highlight)
	_box(balcony, Vector3(0, 1.31, 1.63), Vector3(2.76, .075, .11), limestone)
	# 좌우 짧은 난간도 플랫폼 끝을 감싸 층 모서리를 닫는다.
	for side in [-1.0, 1.0]:
		for z in [1.18, 1.40, 1.61]:
			_box(balcony, Vector3(side*1.43, 1.43, z), Vector3(.09, .38, .09), limestone)
		_box(balcony, Vector3(side*1.43, 1.62, 1.40), Vector3(.12, .105, .62), highlight)
		_box(balcony, Vector3(side*1.43, 1.31, 1.40), Vector3(.10, .075, .60), limestone)
	# 석재 받침은 플랫폼이 공중에 떠 보이지 않게 벽체에 연결한다.
	for side in [-1.0, 1.0]:
		var brace := MeshInstance3D.new()
		var brace_mesh := BoxMesh.new()
		brace_mesh.size = Vector3(.15, .42, .16)
		brace.mesh = brace_mesh
		var brace_material := StandardMaterial3D.new()
		brace_material.albedo_color = shadow
		brace.material_override = brace_material
		brace.position = Vector3(side*1.10, .94, 1.26)
		brace.rotation.z = side * -.45
		balcony.add_child(brace)
		brace.owner = owner_node

func _own_added(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_own_added(child, owner_node)

func _render() -> void:
	viewport = SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var scene_directory := ProjectSettings.globalize_path("res://").path_join("../art_source/visual_bible/tower_scenes").simplify_path()
	DirAccess.make_dir_recursive_absolute(scene_directory)
	var variants := [
		{"stem":"brick_terrace_floor_entry", "base":"brick_floor_entry"},
		{"stem":"brick_terrace_floor_wide", "base":"brick_floor_wide"},
		{"stem":"brick_arch_terrace_floor_entry", "base":"brick_arch_floor_entry"},
		{"stem":"brick_arch_terrace_floor_wide", "base":"brick_arch_floor_wide"}
	]
	for variant in variants:
		var packed_base := load("res://../art_source/visual_bible/tower_scenes/%s.tscn" % variant.base) as PackedScene
		assert(packed_base != null, "Base facade module must load: %s" % variant.base)
		var scene := packed_base.instantiate() as Node3D
		var model := scene.find_child(variant.base, true, false) as Node3D
		assert(model != null, "Base facade model node must exist")
		_terrace(model, scene)
		_own_added(scene, scene)
		var packed := PackedScene.new()
		assert(packed.pack(scene) == OK)
		assert(ResourceSaver.save(packed, scene_directory.path_join(variant.stem+".tscn")) == OK)
		viewport.add_child(scene)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		assert(image.save_png(OUTPUT.path_join(variant.stem+".png")) == OK)
		viewport.remove_child(scene)
		scene.queue_free()
	var records := {"canvas":[640,480],"anchor":[320,240],"camera":[5,2.8,8],"camera_size":5.1,"floor_height":1.18,"floor_step":FLOOR_STEP,"terrace_variants":variants}
	var file := FileAccess.open(OUTPUT.path_join("brick_terrace_geometry.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t")+"\n")
	file.close()
	print("BRICK_TERRACE_TOWER_RENDER ", records)
	viewport.queue_free()
	await process_frame
	quit()
