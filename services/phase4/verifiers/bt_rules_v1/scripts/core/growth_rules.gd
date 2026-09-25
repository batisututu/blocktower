extends RefCounted
## 실제 제거 줄 수를 누적하고 재질/파츠/구간을 파생한다.
const PARTS := [
    {"id": "brick_arch_window", "progress": 10, "total": 60},
    {"id": "brick_terrace", "progress": 30, "total": 120},
    {"id": "brick_cornice", "progress": 60, "total": 200},
    {"id": "brick_landmark", "progress": 100, "total": 300}
]

static func initial() -> Dictionary:
    return {"total_floors": 0, "brick_lines": 0, "metal_lines": 0, "crystal_lines": 0,
        "representative_segment": 0, "segment_styles": {}, "segment_parts": {}}

static func describe(growth: Dictionary) -> Dictionary:
    var materials: Array[String] = ["wood"]
    if growth.brick_lines >= 2 or growth.total_floors >= 30: materials.append("brick")
    if growth.metal_lines >= 3 or growth.total_floors >= 100: materials.append("metal")
    if growth.crystal_lines >= 4 or growth.total_floors >= 250: materials.append("crystal")
    var parts: Array[String] = []
    if "brick" in materials:
        for part in PARTS:
            if growth.brick_lines >= part.progress or growth.total_floors >= part.total: parts.append(part.id)
    return {"materials": materials, "parts": parts, "completed_segments": growth.total_floors / 10,
        "partial_floors": growth.total_floors % 10, "floors_to_next": 10 - growth.total_floors % 10,
        "representative_segment": growth.representative_segment}

static func award(growth: Dictionary, lines: int) -> Dictionary:
    var before := describe(growth)
    growth.total_floors += lines
    if lines >= 2: growth.brick_lines += lines
    if lines >= 3: growth.metal_lines += lines
    if lines >= 4: growth.crystal_lines += lines
    var after := describe(growth)
    if growth.representative_segment == 0 and after.completed_segments > 0:
        growth.representative_segment = 1
    return {"new_segments": after.completed_segments - before.completed_segments,
        "materials": after.materials.filter(func(id): return id not in before.materials),
        "parts": after.parts.filter(func(id): return id not in before.parts)}
