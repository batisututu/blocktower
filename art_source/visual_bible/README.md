# B visual assets

Visual authority: `docs/디자인시안.png`, user-selected B×2 and Wood tower. These assets replace the first W4 playable material set; the old set remains historical evidence.

## Editable sources

- `build_surfaces.py`: six 128×128 material tiles, an empty cell, five nine-slice panels, six line icons (settings, tower, back, and since 2026-09-23 close, best and streak) and two 48×28 switch states. Runtime SVGs are in `game/assets/visual_bible/surfaces/`; PNG exports are in `surface_exports/`. Geometry and subtle stone flecks are original, deterministic source, not reference-image crops.
- `background_prompt.txt`: exact built-in image generation prompt. Runtime `backgrounds/architecture_b.png` is the independent background plate with no labels, board or buttons. Actual dimensions are in `manifest.json`.
- `render_tower.gd`: original Godot geometry, lights and orthographic camera. `tower_scenes/` contains nine editable packed scenes, including their camera and lighting. Transparent outputs share a 640×480 canvas, anchor (320,240), and 106.4683685px floor step.
- `render_brick_tower.gd`: original code-authored Godot 3D brick facade, with no external models or textures. `tower_scenes/brick_floor_{entry,wide,mid,top}.tscn` are the four editable modules. Their runtime PNGs and `brick_geometry.json` live in `game/assets/visual_bible/tower/`; they use the same camera, key/environment lighting, 640×480 canvas, (320,240) anchor, and 106.4683685px floor step as wood. Brick courses, inset gridded windows, stone corner pilasters and belt courses provide structure beyond a color tint.
- `render_metal_tower.gd`: original code-authored Godot 3D metal-and-glass facade, with no external models or textures. `tower_scenes/metal_floor_{entry,wide,mid,top}.tscn` are four editable modules; runtime PNGs and `metal_geometry.json` live in `game/assets/visual_bible/tower/`. They share wood's camera, key/environment lighting, 640×480 canvas, (320,240) anchor and 106.4683685px floor step. Gunmetal pilasters, mullions, bright metal highlights and broad glazed window bays define the facade beyond a tint.
- `render_crystal_tower.gd`: original code-authored Godot 3D crystal facade; no external models or textures. `tower_scenes/crystal_floor_{entry,wide,mid,top}.tscn` are editable modules with four transparent runtime PNGs and `crystal_geometry.json` under `game/assets/visual_bible/tower/`. They share the wood camera/key/environment lighting, 640×480 canvas, (320,240) anchor and 106.4683685px floor step. Hexagonal crystal corner columns, triangulated glass facets and restrained cyan/lavender emissive planes distinguish the structure from wood, brick and metal without bloom effects.
- `render_brick_arch_tower.gd`: original code-authored arch-window variation for completed brick facades, with no external models or textures. `tower_scenes/brick_arch_floor_{entry,wide,mid,top}.tscn` are four editable modules; their transparent runtime PNGs and `brick_arch_geometry.json` live in `game/assets/visual_bible/tower/`. They share the brick/wood camera, lighting, 640×480 canvas, (320,240) anchor and 106.4683685px floor step. Faceted voussoirs and keystones surround arch-shaped glazing, so the part changes structure and silhouette beyond tint.
- `render_brick_terrace_tower.gd`: original renderer composes a projecting limestone terrace and balustrade onto brick and brick-arch modules, with no external models or textures. Four editable compositions (`brick_terrace_floor_{entry,wide}.tscn` and `brick_arch_terrace_floor_{entry,wide}.tscn`) and four transparent PNGs plus `brick_terrace_geometry.json` use the shared 640×480 canvas, (320,240) anchor and 106.4683685px floor step. Terrace appears on the selected segment's entry floor; the two combined modules preserve the arch facade below it.
- `render_brick_cornice.gd`: original Godot 3D geometry for a projecting limestone dentil cornice and three preserved hip-roof silhouettes with additional stone bands/merlons; all three decorated roof variants retain the gold finial and flag from their matching base roofs. Four editable scenes (`brick_cornice.tscn`, `brick_cornice_roof_{wide,mid,top}.tscn`) and four transparent runtime PNGs plus `brick_cornice_geometry.json` share the 640×480 canvas, (320,240) anchor, wood camera/key light and 106.4683685px floor step. No external models or textures are used.
- `manifest.json`: original source and runtime file hashes, origins and panel margins. No external model, texture pack or audio dependency was introduced in this pass.

## Reproduce

From the repository root, use the pinned 4.7.2 engine:

```powershell
python art_source/visual_bible/build_surfaces.py
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --path game --script ../art_source/visual_bible/render_tower.gd
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --path game --script ../art_source/visual_bible/render_brick_tower.gd
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --path game --script ../art_source/visual_bible/render_metal_tower.gd
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --path game --script ../art_source/visual_bible/render_crystal_tower.gd
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --path game --script ../art_source/visual_bible/render_brick_arch_tower.gd
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --path game --script ../art_source/visual_bible/render_brick_terrace_tower.gd
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --path game --script ../art_source/visual_bible/render_brick_cornice.gd
& C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path game --script ../art_source/visual_bible/export_surfaces.gd
pwsh -NoProfile -File tools/test.ps1
python tools/verify_visual_fidelity.py
```

The tower renderers need a Windows desktop GPU context. The brick, metal and crystal renderers each write four editable packed floor scenes, four transparent 640×480 PNGs, and their geometry metadata; the wood renderer writes nine editable packed scenes (floors, base, cornice, and roofs), its runtime PNGs, and `geometry.json`. Surface export is headless. Regeneration overwrites the corresponding generated outputs, so refresh their sizes/hashes in `manifest.json` afterward. The architecture plate is not deterministically recreated by the code commands; its exact selected PNG is preserved.

## Runtime geometry

VisualBibleTheme caches textures/styles. Every panel uses 16px texture margins and 8px content margins; text stays in native Controls. Families map deterministically onto six visible material palettes without changing saved style IDs or placement rules. Input uses the same board/tray rectangles as drawing.

The tower displays a selected segment with at most ten floors: first three wide, next three middle, last four narrow. The entry module is used only at the actual first floor. Every visible module counts as one acquired floor; decorative base/cornice/roof do not count. Intermediate complete segments end in cornice; actual top uses a roof matching its current width. The renderer does not synthesize floors to match the reference silhouette.

The packed scenes use Godot's [standard 3D materials](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html). Camera, color and light choices are project art decisions evaluated in native captures, not universal lighting recommendations.
