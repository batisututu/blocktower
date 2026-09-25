extends Control
## 검증된 대표 10층의 재질·장식만 읽기 전용으로 그린다.
const TOWER_PATH := "res://assets/visual_bible/tower/"
var tower: Dictionary = {}
var _art: Dictionary = {}
var _floor_step := 106.468368530273

func show_tower(value: Dictionary) -> void:
    tower = value.duplicate(true)
    queue_redraw()

func _texture(key: String) -> Texture2D:
    if not _art.has(key): _art[key] = load(TOWER_PATH+key+".png")
    return _art[key]

func _draw() -> void:
    var representative: int = int(tower.get("representative_segment",0))
    if representative <= 0: return
    var material: String = str(tower.get("material","wood"))
    if material not in ["wood","brick","metal","crystal"]: return
    var parts: Array = tower.get("parts",[])
    var scale_factor := minf(size.x/470.0,size.y/(10.0*_floor_step+205.0))
    var anchor := Vector2(size.x/2,size.y-24)
    var rect := Rect2(anchor-Vector2(320,240)*scale_factor,Vector2(640,480)*scale_factor)
    draw_texture_rect(_texture("base"),rect,false)
    for i in range(10):
        var part := "floor_wide" if i<3 else ("floor_mid" if i<6 else "floor_top")
        if i==0 and representative==1: part = "floor_entry"
        if material == "brick" and i==4 and "brick_landmark" in parts:
            part = "brick_arch_landmark_floor_mid" if "brick_arch_window" in parts else "brick_landmark_floor_mid"
        elif material == "brick" and i==0 and "brick_terrace" in parts:
            var suffix := "entry" if representative==1 else "wide"
            part = "brick_arch_terrace_floor_"+suffix if "brick_arch_window" in parts else "brick_terrace_floor_"+suffix
        elif material == "brick" and "brick_arch_window" in parts:
            part = "brick_arch_"+part
        elif material != "wood": part = material+"_"+part
        draw_texture_rect(_texture(part),Rect2(rect.position-Vector2(0,i*_floor_step*scale_factor),rect.size),false)
    var roof := int(tower.get("total_floors",0))==representative*10
    var cap := "roof_top" if roof else "cornice"
    if material == "brick" and "brick_cornice" in parts:
        cap = "brick_cornice_roof_top" if roof else "brick_cornice"
    draw_texture_rect(_texture(cap),Rect2(rect.position-Vector2(0,10*_floor_step*scale_factor),rect.size),false)
