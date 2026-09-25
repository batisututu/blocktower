extends SceneTree
## 목재 랜드마크 원본: 석재 기단, 아치창, 발코니, 목재 골조, 식재, 경사 지붕.
const OUTPUT := "res://assets/visual_bible/tower"
const FLOOR_HEIGHT := 1.18
const VIEW_SIZE := Vector2i(640,480)
var viewport: SubViewport
var world: Node3D
var model: Node3D
var camera: Camera3D
var materials: Dictionary = {}

func _initialize(): _render.call_deferred()

func material(color: String) -> StandardMaterial3D:
    if materials.has(color): return materials[color]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(color).darkened(.18)
    m.roughness = 0.92
    materials[color] = m
    return m

func box(p: Vector3, s: Vector3, color: String, parent: Node3D = null) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = s
    mesh.mesh = shape
    mesh.material_override = material(color)
    mesh.position = p
    (model if parent==null else parent).add_child(mesh)
    return mesh

func bush(p: Vector3, scale_value: float, parent: Node3D = null):
    # 둥근 덩어리 대신 불규칙한 잎·가지 윤곽을 고정 좌표로 만든다.
    for i in range(44):
        var mesh := MeshInstance3D.new()
        var shape := SphereMesh.new()
        shape.radius = scale_value*(.075+.015*(i%3))
        shape.height = shape.radius*2
        shape.radial_segments = 8
        shape.rings = 4
        mesh.mesh = shape
        var radius := scale_value*(.12+.22*absf(sin(i*.73)))
        mesh.position = p+Vector3(sin(i*2.4)*radius,(i%7)*scale_value*.060,cos(i*2.4)*radius)
        mesh.scale = Vector3(.65,1.6,.75)
        mesh.rotation = Vector3(sin(i*1.7)*.9,i*2.4,cos(i*.8)*.8)
        mesh.material_override = material(["425631","66773d","82904d","354d30","9d9b52"][i%5])
        (model if parent==null else parent).add_child(mesh)
    for i in range(3):
        var branch := box(p+Vector3((i-1)*scale_value*.12,scale_value*.12,0),Vector3(.018*scale_value,scale_value*.34,.018*scale_value),"5e5635",parent)
        branch.rotation.z = (i-1)*.35

func arch_face(p: Vector3, width: float, height: float, color: String, parent: Node3D):
    var mesh := MeshInstance3D.new()
    var vertices := PackedVector3Array([Vector3(0,height*.40,0),Vector3(-width/2,0,0),Vector3(width/2,0,0)])
    var edge: Array[Vector3] = [Vector3(-width/2,0,0),Vector3(width/2,0,0)]
    for i in range(13):
        var angle := i*PI/12
        edge.append(Vector3(cos(angle)*width/2,height-width/2+sin(angle)*width/2,0))
    vertices.clear()
    for i in range(edge.size()):
        vertices.append(Vector3(0,height*.42,0));vertices.append(edge[i]);vertices.append(edge[(i+1)%edge.size()])
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    var normals := PackedVector3Array()
    for v in vertices: normals.append(Vector3(0,0,1))
    arrays[Mesh.ARRAY_NORMAL] = normals
    var shape := ArrayMesh.new()
    shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    mesh.mesh = shape
    var mat := material(color).duplicate()
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.material_override = mat
    mesh.position = p
    parent.add_child(mesh)

func window_unit(x: float, parent: Node3D, balcony: bool):
    var origin := Vector3(x,0.19,1.007)
    arch_face(origin,0.63,0.83,"d7c59e",parent)
    arch_face(origin+Vector3(0,.07,.008),0.46,0.65,"394846",parent)
    arch_face(origin+Vector3(0,.095,.013),0.38,0.56,"4c5745",parent)
    box(origin+Vector3(0,.32,.035),Vector3(.035,.54,.035),"91764a",parent)
    box(origin+Vector3(0,.29,.035),Vector3(.4,.032,.035),"91764a",parent)
    for sign_value in [-1,1]:
        box(origin+Vector3(sign_value*.285,.34,.047),Vector3(.065,.65,.085),"c9ba96",parent)
    box(origin+Vector3(0,.02,.08),Vector3(.73,.09,.24),"d2c29b",parent)
    # 아치 외곽의 쐐기돌은 각도별 고정 구조로 만든다.
    for i in range(9):
        var a := i*PI/8
        var block := box(origin+Vector3(cos(a)*.282,.50+sin(a)*.282,.04),Vector3(.098,.068,.09),"e0cfaa",parent)
        block.rotation.z = a-PI/2
    if balcony:
        box(origin+Vector3(0,.04,.23),Vector3(.88,.07,.53),"b9ad8b",parent)
        for bx in [-.36,-.18,0,.18,.36]: box(origin+Vector3(bx,.19,.47),Vector3(.022,.27,.025),"5e5b43",parent)
        box(origin+Vector3(0,.33,.47),Vector3(.86,.035,.04),"75684a",parent)

func floor_module(tier: float, entry: bool = false, terrace: bool = false):
    var building := Node3D.new()
    model.add_child(building)
    building.scale = Vector3(tier,1,tier)
    box(Vector3(0,.58,0),Vector3(2.62,1.12,1.94),"bca983",building)
    box(Vector3(0,.60,.983),Vector3(2.40,1.04,.025),"d5c6a0",building)
    box(Vector3(1.322,.60,0),Vector3(.025,1.04,1.72),"c5b18a",building)
    for y in [.055,1.115]:
        box(Vector3(0,y,0),Vector3(2.77,.095,2.09),"705437",building)
        box(Vector3(0,y+.047,0),Vector3(2.86,.035,2.18),"dccda8",building)
    for x in [-.42,.42]: box(Vector3(x,.60,1.002),Vector3(.055,.97,.065),"795c3c",building)
    for x in [-1.25,1.25]:
        for z in [-.92,.92]:
            box(Vector3(x,.58,z),Vector3(.15,1.10,.15),"62482e",building)
            for j in range(5): box(Vector3(x,.20+j*.18,z),Vector3(.19,.125,.18),"c0ae87",building)
    for x in [-.78,0,.78]: window_unit(x,building,terrace and x==0)
    var side := Node3D.new()
    building.add_child(side)
    side.rotation.y = PI/2
    side.position.x = .35
    for x in [-.46,.46]: window_unit(x,side,false)
    # 무작위 게임 RNG 없이 반복 가능한 벽돌/회벽 음영.
    for j in range(4):
        for i in range(6):
            var x: float = -1.14+i*.41+(.12 if j%2 else 0)
            box(Vector3(x,.13+j*.24,.972),Vector3(.28,.005,.008),"a69773",building)
    if entry:
        arch_face(Vector3(0,.09,1.045),.80,.98,"d8c6a0",building)
        arch_face(Vector3(0,.10,1.051),.64,.86,"544d36",building)
        for x in [-.22,-.11,0,.11,.22]: box(Vector3(x,.43,1.075),Vector3(.025,.55,.018),"8b7550",building)
    if terrace:
        box(Vector3(-.83,.15,1.09),Vector3(.56,.18,.30),"8e7957",building)
        bush(Vector3(-.83,.35,1.08),.47,building)
        bush(Vector3(1.28,.28,.57),.40,building)
        for j in range(3): bush(Vector3(1.33,.88-j*.23,.68),.21,building)

func roof_module(tier: float):
    var building := Node3D.new()
    model.add_child(building)
    building.scale = Vector3(tier,1,tier)
    box(Vector3(0,.04,0),Vector3(2.87,.08,2.2),"d8c9a2",building)
    var roof := MeshInstance3D.new()
    var shape := CylinderMesh.new()
    shape.top_radius = .24
    shape.bottom_radius = 1.99
    shape.height = 1.24
    shape.radial_segments = 4
    roof.mesh = shape
    roof.scale.z = .78
    roof.rotation.y = PI/4
    roof.position.y = .70
    # 지붕 UV에서 직접 줄눈을 계산해 꼭짓점/경사면과 분리될 수 없게 한다.
    var shader := Shader.new()
    shader.code = """shader_type spatial;
uniform vec4 roof_color : source_color;
void fragment() {
    float course = fract(UV.y * 8.0);
    float seam = 1.0 - smoothstep(0.012, 0.042, min(course, 1.0-course));
    ALBEDO = roof_color.rgb * mix(1.0, 0.78, seam);
    ROUGHNESS = 0.92;
}
"""
    var roof_material := ShaderMaterial.new()
    roof_material.shader = shader
    roof_material.set_shader_parameter("roof_color",Color("657768").darkened(.18))
    roof.material_override = roof_material
    building.add_child(roof)
    box(Vector3(0,1.40,0),Vector3(.20,.22,.20),"bd9d61",building)
    box(Vector3(0,1.68,0),Vector3(.035,.43,.035),"6e6040",building)
    box(Vector3(.12,1.80,0),Vector3(.25,.14,.022),"cda54f",building)
    bush(Vector3(.78,.16,.7),.47,building)

func base_module():
    for i in range(3): box(Vector3(0,-.065-i*.11,0),Vector3(2.85+i*.25,.10,2.25+i*.25),"acaa8e")
    box(Vector3(0,-.40,0),Vector3(3.80,.15,3.0),"898d6d")
    for x in [-1.62,1.62]:
        box(Vector3(x,-.24,.94),Vector3(.35,.34,.48),"a2936e")
        bush(Vector3(x,.09,.95),.72)
    for i in range(3): box(Vector3(0,-.11-i*.1,1.32+i*.17),Vector3(1.30,.10,.36),"c8bea0")
    for x in [-1.32,1.32]:
        box(Vector3(x,-.05,-1.15),Vector3(.18,.66,.18),"91846a")
        bush(Vector3(x,.48,-1.15),.7)

func own_tree(node: Node, owner_node: Node):
    for child in node.get_children():
        child.owner = owner_node
        own_tree(child,owner_node)

func _render():
    viewport = SubViewport.new()
    viewport.size = VIEW_SIZE
    viewport.transparent_bg = true
    viewport.own_world_3d = true
    viewport.msaa_3d = Viewport.MSAA_4X
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    world = Node3D.new()
    viewport.add_child(world)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_CLEAR_COLOR
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color("eee4cf")
    env.environment.ambient_light_energy = .32
    env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    world.add_child(env)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-48,-38,0)
    key.light_color = Color("fff0d3")
    key.light_energy = .65
    key.shadow_enabled = true
    world.add_child(key)
    camera = Camera3D.new()
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
    for part in ["floor_entry","floor_wide","floor_mid","floor_top","roof_wide","roof_mid","roof_top","cornice","base"]:
        model = Node3D.new()
        model.name = part
        world.add_child(model)
        match part:
            "floor_entry": floor_module(1.0,true,true)
            "floor_wide": floor_module(1.0,false,true)
            "floor_mid": floor_module(.83,false,true)
            "floor_top": floor_module(.66,false,true)
            "roof_wide": roof_module(1.0)
            "roof_mid": roof_module(.83)
            "roof_top": roof_module(.66)
            "cornice": box(Vector3(0,.035,0),Vector3(2.87*.66,.07,2.2*.66),"d8c9a2")
            "base": base_module()
        own_tree(world,world)
        var packed := PackedScene.new()
        assert(packed.pack(world)==OK)
        assert(ResourceSaver.save(packed,scene_directory.path_join(part+".tscn"))==OK)
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        assert(viewport.get_texture().get_image().save_png(OUTPUT.path_join(part+".png"))==OK)
        world.remove_child(model)
        model.queue_free()
    var step := camera.unproject_position(Vector3.ZERO).y-camera.unproject_position(Vector3(0,FLOOR_HEIGHT,0)).y
    records["floor_step"] = step
    var file := FileAccess.open(OUTPUT.path_join("geometry.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(records,"\t"));file.close()
    print("VISUAL_BIBLE_TOWER ",records)
    viewport.queue_free()
    await process_frame
    quit()
