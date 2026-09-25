extends RefCounted
## 재질 리소스는 캐시하고 입력/점수 규칙과 분리한다.
const ROOT := "res://assets/visual_bible/surfaces/"
const FAMILY_MAP := ["sage","clay","sand","clay","gold","sage","violet","blue","sage","clay","sand","blue","violet"]
var textures: Dictionary = {}
var styles: Dictionary = {}

func texture(name: String) -> Texture2D:
    if not textures.has(name): textures[name] = load(ROOT+name+".svg")
    return textures[name]

func panel(name: String, state: String = "normal") -> StyleBoxTexture:
    var key := name+"/"+state
    if styles.has(key): return styles[key]
    var box := StyleBoxTexture.new()
    box.texture = texture("disabled" if state=="disabled" else name)
    for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
        box.set_texture_margin(side,16)
        box.set_content_margin(side,8)
    if state=="hover": box.modulate_color = Color(1.08,1.06,1.02)
    if state=="pressed": box.modulate_color = Color(0.92,0.91,0.89)
    styles[key] = box
    return box

func cell(style_id: int) -> Texture2D:
    return texture("tile_"+FAMILY_MAP[(maxi(style_id,1)-1)%FAMILY_MAP.size()])
