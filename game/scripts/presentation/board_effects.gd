extends RefCounted
## 확정 결과의 복사본만 그린다. 파편 수와 이동은 결정적이며 공급 RNG를 사용하지 않는다.
const LIGHT := Color("ffe4a5")

static func cell_rect(board: Rect2, i: int) -> Rect2:
    var step := board.size.x/8
    return Rect2(board.position+Vector2(i%8,i/8)*step,Vector2.ONE*step)

static func draw(canvas: CanvasItem, board: Rect2, art: RefCounted, cells: Array, styles: Array, placed: Array, current_styles: PackedByteArray, rows: Array, columns: Array, progress: float) -> void:
    var step := board.size.x/8
    if cells.is_empty():
        var scale := lerpf(.78,1.06,progress/.55) if progress<.55 else lerpf(1.06,1.0,(progress-.55)/.45)
        for i in placed:
            var r := cell_rect(board,i).grow(-.7)
            canvas.draw_texture_rect(art.cell(current_styles[i]),Rect2(r.get_center()-r.size*scale/2,r.size*scale),false)
            canvas.draw_rect(r.grow(1+progress*3),Color(LIGHT,(1-progress)*.65),false,1.5)
        return
    var t := progress*.42
    var impact := minf(1.0,float(rows.size()+columns.size())/4.0)
    for k in range(cells.size()):
        var i: int = cells[k]
        var r := cell_rect(board,i).grow(-.7)
        var along := float(i%8)/7 if i/8 in rows else float(i/8)/7
        var shrink := clampf((t-.12-along*.055)/.16,0,1)
        var size := r.size*(1.0+.055*sin(minf(t/.08,1.0)*PI))*(1-shrink)
        if size.x > .1:
            var tile := Rect2(r.get_center()-size/2,size)
            canvas.draw_texture_rect(art.cell(styles[k]),tile,false,Color(1,1,1,1-shrink))
            canvas.draw_rect(tile,Color(LIGHT,(.12+.28*sin(clampf(t/.14,0,1)*PI))*(1-shrink)))
    if t>=.045 and t<.23:
        var sweep := clampf((t-.045)/.185,0,1)
        for row in rows:
            var origin := board.position+Vector2(0,row*step)
            canvas.draw_rect(Rect2(origin,Vector2(board.size.x,step)),Color(LIGHT,.09*sin(sweep*PI)))
            var x := board.position.x+sweep*board.size.x
            canvas.draw_rect(Rect2(Vector2(maxf(board.position.x,x-step),origin.y),Vector2(minf(step,x-board.position.x),step)),Color(LIGHT,(.22+.16*impact)*sin(sweep*PI)))
            canvas.draw_line(Vector2(x,origin.y+2),Vector2(x,origin.y+step-2),Color(LIGHT,sin(sweep*PI)),2.0+2.0*impact)
        for col in columns:
            var origin := board.position+Vector2(col*step,0)
            canvas.draw_rect(Rect2(origin,Vector2(step,board.size.y)),Color(LIGHT,.09*sin(sweep*PI)))
            var y := board.position.y+sweep*board.size.y
            canvas.draw_rect(Rect2(Vector2(origin.x,maxf(board.position.y,y-step)),Vector2(step,minf(step,y-board.position.y))),Color(LIGHT,(.22+.16*impact)*sin(sweep*PI)))
            canvas.draw_line(Vector2(origin.x+2,y),Vector2(origin.x+step-2,y),Color(LIGHT,sin(sweep*PI)),2.0+2.0*impact)
    if t>.13:
        var age := (t-.13)/.29
        var count := mini(36,8+6*(rows.size()+columns.size()))
        for k in range(count):
            var r := cell_rect(board,cells[(k*7)%cells.size()])
            var angle := float(k)*2.39996
            var offset := Vector2(cos(angle),sin(angle))*step*(.25+float(k%4)*.12)*age
            offset.y += age*age*step*.35
            var point := r.get_center()+offset
            var extent := (2.0+float(k%3)+impact*1.4)*(1-age)
            if extent < .25: continue
            var shard := PackedVector2Array([point+Vector2(-extent,0),point+Vector2(0,-extent*1.6),point+Vector2(extent,0),point+Vector2(0,extent*1.6)])
            canvas.draw_colored_polygon(shard,Color(LIGHT,(1-age)*.85))
