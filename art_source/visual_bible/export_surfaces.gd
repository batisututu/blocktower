extends SceneTree
## 편집 가능한 SVG 정본을 납품용 PNG로 내보낸다. 런타임은 SVG import를 사용한다.
func _initialize():
    var source := "res://assets/visual_bible/surfaces"
    var output := ProjectSettings.globalize_path("res://").path_join("../art_source/visual_bible/surface_exports").simplify_path()
    DirAccess.make_dir_recursive_absolute(output)
    var count := 0
    for name in DirAccess.get_files_at(source):
        if not name.ends_with(".svg"): continue
        var image := Image.new()
        assert(image.load_svg_from_string(FileAccess.get_file_as_string(source.path_join(name)))==OK)
        assert(image.save_png(output.path_join(name.get_basename()+".png"))==OK)
        count += 1
    print("SURFACE_EXPORTS ",count)
    quit()
