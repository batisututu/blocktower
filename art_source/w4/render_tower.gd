extends SceneTree
## 동일 직교 카메라/광원에서 재생성하는 목재 첫 프리렌더 모듈.
var viewport: SubViewport
var model: Node3D
var camera: Camera3D
var materials: Dictionary = {}

func _initialize():
    _render.call_deferred()

func material(color: String) -> StandardMaterial3D:
    if materials.has(color): return materials[color]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(color)
    m.roughness = 0.84
    materials[color] = m
    return m

func box(position: Vector3, dimensions: Vector3, color: String):
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = dimensions
    mesh.mesh = shape
    mesh.material_override = material(color)
    mesh.position = position
    model.add_child(mesh)

func floor_module():
    box(Vector3(0,0.425,0),Vector3(2.5,0.75,1.9),"c7a477")
    for y in [0.05,0.81]: box(Vector3(0,y,0),Vector3(2.68,0.10,2.08),"69513c")
    for x in [-1.2,1.2]:
        for z in [-0.9,0.9]: box(Vector3(x,0.44,z),Vector3(0.12,0.72,0.12),"755136")
    for x in [-0.78,0.0,0.78]:
        box(Vector3(x,0.45,0.966),Vector3(0.45,0.55,0.08),"eee0b7")
        box(Vector3(x,0.45,1.016),Vector3(0.33,0.43,0.035),"233740")
        box(Vector3(x,0.44,1.041),Vector3(0.025,0.44,0.025),"b89861")
        box(Vector3(x,0.39,1.046),Vector3(0.33,0.025,0.025),"b89861")
        box(Vector3(x,0.17,1.06),Vector3(0.56,0.07,0.22),"ded0a6")
    for z in [-0.48,0.40]:
        box(Vector3(1.266,0.45,z),Vector3(0.08,0.55,0.44),"eee0b7")
        box(Vector3(1.316,0.45,z),Vector3(0.035,0.43,0.32),"233740")
        box(Vector3(1.34,0.44,z),Vector3(0.025,0.44,0.025),"b89861")
        box(Vector3(1.35,0.39,z),Vector3(0.025,0.025,0.32),"b89861")
    # 식재는 조립 경계 아래에만 배치한다.
    box(Vector3(-0.78,0.22,1.13),Vector3(0.45,0.10,0.18),"3e643e")

func roof_module():
    box(Vector3(0,0.06,0),Vector3(2.8,0.12,2.2),"e1cfa0")
    var roof := MeshInstance3D.new()
    var shape := CylinderMesh.new()
    shape.top_radius = 0.25
    shape.bottom_radius = 1.90
    shape.height = 0.8
    shape.radial_segments = 4
    roof.mesh = shape
    roof.scale = Vector3(1,1,0.78)
    roof.rotation.y = PI/4
    roof.position.y = 0.5
    roof.material_override = material("59776d")
    model.add_child(roof)
    box(Vector3(0,1.0,0),Vector3(0.14,0.32,0.14),"be975d")

func _render():
    viewport = SubViewport.new()
    viewport.size = Vector2i(384,256)
    viewport.transparent_bg = true
    viewport.own_world_3d = true
    viewport.msaa_3d = Viewport.MSAA_4X
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var world := Node3D.new()
    viewport.add_child(world)
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_CLEAR_COLOR
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color("fff0d6")
    environment.environment.ambient_light_energy = 0.35
    world.add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-42,-38,0)
    light.light_energy = 0.8
    light.shadow_enabled = true
    world.add_child(light)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 4.0
    camera.position = Vector3(5,3.7,7)
    world.add_child(camera)
    camera.look_at(Vector3.ZERO)
    camera.current = true
    var output := "res://assets/presentation/tower"
    DirAccess.make_dir_recursive_absolute(output)
    var records := {}
    for part in ["floor","roof","base","cornice"]:
        model = Node3D.new()
        world.add_child(model)
        if part == "floor": floor_module()
        elif part == "roof": roof_module()
        elif part == "cornice":
            box(Vector3(0,0.03,0),Vector3(2.8,0.06,2.2),"e1cfa0")
        else:
            for i in range(3): box(Vector3(0,-0.08-i*0.1,0),Vector3(2.75+i*0.20,0.1,2.15+i*0.20),"b7ac8c")
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var image := viewport.get_texture().get_image()
        var error := image.save_png(output.path_join(part+".png"))
        assert(error==OK)
        records[part] = {"size":[384,256],"anchor":[192,128]}
        world.remove_child(model)
        model.queue_free()
    var bottom := camera.unproject_position(Vector3.ZERO)
    var top := camera.unproject_position(Vector3(0,0.86,0))
    records["floor_step"] = bottom.y-top.y
    var file := FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(records,"\t"))
    file.close()
    print("TOWER_ASSETS ",records)
    viewport.queue_free()
    await process_frame
    quit()
