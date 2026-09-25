# Visual assets contract v1

VisualBibleTheme owns presentation textures, nine-slice margins, icons and style-to-texture mapping. Each cell texture occupies a 128×128 canvas; drawing bounds match the existing placement grid. Materials must never change occupancy, style IDs, piece geometry, score or RNG.

HUD, score, labels, toggle and interaction areas remain independent native controls. Panels expose normal, hover, pressed, disabled and focus styles. The architecture plate contains no interactive/text content. Safe layout has explicit board/tray/control rectangles shared by drawing and input.

2026-09-23 HUD refinement adds original line icons `icon_close`, `icon_best` and `icon_streak`, and the two switch textures `switch_off` and `switch_on` (48×28). All come from `build_surfaces.py`. The switch knob position is the shape cue for the state, and color is supplementary. The HUD chip uses the line `icon_tower`, so it never implies a floor count. The results card draws the actual top segment with the same sprite, anchor, floor step and roof/cornice rules as the tower screen. Every module it draws is an acquired floor.

Tower sprites share one camera, viewport, origin anchor and floor step recorded in geometry.json. Floor variants are visual only; every acquired floor draws exactly one floor module. Cornice is decoration at an intermediate segment; roof appears only at the actual global top. Base decoration is not a floor. Source geometry remains editable and reproducible outside the runtime project.
