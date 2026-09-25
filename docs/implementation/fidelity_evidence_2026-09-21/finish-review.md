disposition: fix

Inputs: original B×2/Wood image, direction.md, design guide §11, all 19 required native captures, source samples and test summaries inspected; no supplied measured comp spec, region-diff packet or QUALITY BAR card. This is an authorized refinement of the selected B direction, so a new concept roll/approval is not required. Android hardware, motion/audio and complete source-tree review are outside this still-image Windows review.

## persistence

Pass for the reviewable implementation and evidence: PRODUCT.md exists; the selected B authority and six required axes are explicit in `art_source/visual_bible/direction.md` and guide §11; editable surface generation, native 3D generation and runtime theme binding exist. PRODUCT.md still describes B as awaiting selection, and DESIGN.md is explicitly historical/pending: report that documentation drift without treating it as a new design vote or repairing it in this review.

All 19 required PNGs are present, opened, populated and consistent with their named sizes/states: reference 360/412, basic 320/360, cross 412, input/valid/invalid/clear/max 360, modal/settings/large 320, tower 1/9/10/11/intermediate13/top13 360. `summary.json` has 19 reports and all capture checks pass. The current GUT XML contains 74 passing tests and 2,592 assertions; that supports behavior, not visual fidelity. The old W4 basic capture was checked only as a baseline, not as the art target. No HTML detector was run; the native game brief governs over generic Material app scaffolds.

## fidelity

Reference comparison used the original sheet plus a 2× view of the central B×2 panel and a 2× Wood region; judgments are not based on the whole-sheet thumbnail. The six axis verdicts are independent.

| Axis / salient element | Classification and verdict | Evidence |
|---|---|---|
| 1. Composition: compact score/best/auto strip, inset central board, side controls, three trays, lower clear | Acceptable adaptation — pass | Reference 360/412 and basic 320 keep the reference's hierarchy and frame/tray relationships. Actual 8×8 rules, live score, useful side actions and taller viewport normalization are authorized by direction.md and guide §11; omitted mission/shop/record features are product truth, not missing functionality. |
| 2. Block MATERIAL: colored faces, bevels, corner seams, quiet structural texture | Match with authored adaptation — pass | Sage/clay/cream cells visibly carry highlight, shadow and corner structure at 320, 360 and 412. Clay brick segmentation differs from the panel's predominantly diagonal joints but belongs to the supplied B structural tile study; the original geometric asset source is not a cropped screenshot. Valid/invalid and cross overlays retain readable cells. |
| 3. GROUND and background architecture | Temperature/value match; architecture contradicted at tall ratios — fix | Warm ochre remains appropriate and the central field is quiet. At 320 the source's arch curves, balconies and planting frame the board; in reference 360/412 and basic 360, aspect-cover crops most arches/balconies away, leaving near-straight columns and a broad blank upper wall. The reference's arch-lined street/courtyard is a signature feature, not only a warm texture. |
| 4. HUD MATERIAL/light: bronze frames, recessed trays, amber clear | Match — pass | Score panel and trays have inset depth and restrained edge light; cross412 exposes the amber action surface. Disabled clear is deliberately subdued, while modal focus and primary action remain distinct. Actual labels and controls remain independent. |
| 5. TYPE: compact Korean/numeric hierarchy | Acceptable adaptation — pass | Warm high-contrast score, restrained best label and legible Korean controls match the reference's clean sans character. Korean localization, factual scores, explicit instructions and long-number fallback are justified by actual game state; large320 stays inside the HUD. No fake reference score is being used as runtime text. |
| 6. Tower silhouette / volume / Wood detail | Dimensional medium and segmented topology match; window/roof/material details contradicted — fix | 9/10 are tapered, corniced orthographic buildings; 1/11/top13 show real stairs, balconies and roof volume. Intermediate13 has no false top roof and partial segments preserve acquired floors. However front arches read as sealed cream panels, unlike the dark side windows and reference glazing; roof seams protrude as detached ledges; mostly uniform cream surfaces and ball-cluster planting fall short of the reference's wood/stone separation and leafy detail. |

State coverage is coherent: cross shows two pending lines, clear/max show factual result text, invalid has a visible × and explanation, modal/settings fit 320. These stills do not certify animation timing, listening quality, physical touch size or Android system integration.

## ceiling

Not reached in the architecture assets: tall-viewport framing discards the authored arches; tower window depth is hidden; roof seam geometry reads as added objects; warm timber contrast and planting silhouettes remain underdeveloped. The reference's tapered dimensional mass and small architectural ornament are already present, so these are bounded source-asset corrections, not grounds for replacing the chosen visual world or rebuilding the entire puzzle UI.

## material_fixes

1. **VR05 / tower windows:** in `art_source/visual_bible/render_tower.gd`, put front arch and glazing faces definitively outside the facade plane or create true recess openings, then regenerate all affected tower PNGs/scenes. The facade reaches z≈0.9955 while the dark front planes sit at z≈0.990/0.995; 1/11/top13 must show dark, framed front glazing with visible mullions rather than solid cream infill, and 9/10 must retain readable dark window rhythm.
2. **VR03 / tall background composition:** change `puzzle_screen.gd` background framing or produce an aspect-specific architecture plate so 360×800 and 412×915 retain visible side arch curves/balcony rails and planting around the board as 320 does; preserve the quiet central field and live-control readability. `STRETCH_KEEP_ASPECT_COVERED` currently crops away the feature the asset was made to supply; do not resolve this by making the wall busier behind cells.
3. **VR05 / roof seams:** replace the horizontal BoxMesh seam bars in `roof_module()` with a surface-bound tile/seam treatment derived from the actual rotated/scaled roof mesh, then regenerate roof modules. In tower1/tower11/top13 the rows must read as shallow roof courses following both slopes, without floating zigzag ledges or raised shelf shadows.
4. **VR05 / Wood material and planting:** produce and bind restrained editable cream-stone/brown-timber material variation and a finer leaf-cluster treatment in the existing 3D source; strengthen visible timber uprights/cornice undersides against the cream wall, and replace the prominent smooth sphere clumps at the base/terraces with irregular leafy silhouettes. Re-render the same modules; at 1/top13 the result should read as warm architectural wood/stone and planting, while the 9/10 view keeps its existing silhouette and clear floor count. This is a specific asset-finishing requirement, not permission to add unrelated ornaments or features.

## keep

Keep the live 8×8/three-piece game, factual score and floor accounting, compact framed B HUD, warm restrained palette, independent state overlays, exact partial-segment counts and global-top-only roof; score these four fixes against the same recaptured files without reopening unrelated design choices.

---

## verdict

Post-fix scoring, 2026-09-21: all 19 replacement captures in `tools/out/fidelity_review_fix1/` were opened and validated after `summary.json` completed. This explicitly supplied replacement directory is the evidence for this verdict. Dimensions match filenames, no capture is blank or malformed, and all 19 reports pass their checks. The fresh 14:41 test run remains 74 passing tests / 2,592 assertions.

1. **Front glazing — resolved.** Tower1, tower11 and top13 now show dark front arch openings with separate cream surrounds and timber mullions; tower9/10 retain that dark window rhythm at the smaller display scale. The former cream infill is gone.
2. **Tall background framing — resolved.** Reference360/412 and basic360 now retain side arch curves, balcony rails and plants, with the central board field still quiet. The full-plate aspect adaptation is visible as taller architecture, an acceptable framing adjustment for these game viewports; basic320 and modal/state readability remain intact.
3. **Roof seam attachment — partial.** Tower1, tower11 and top13 lose the former bright raised shelf thickness, but useful-scale (3×) crops of tower1/top13 show each dark course ending in a short hooked stub across the hip instead of a continuous surface course. The fix was initially judged resolved at native display scale; closer scoring of the same evidence corrects that judgment. Replace the remaining independently positioned strips with UV/material-bound courses following the roof mesh, so the rows terminate or continue cleanly at the actual hip without detached-looking dark hooks.
4. **Wood/stone and planting treatment — resolved at the requested asset-finishing scope.** Tower1/top13 show brown framing and cornice undersides separated from cream walls, and irregular individual leaf forms replace the former smooth ball clumps at bases and terraces. Tower9/10 preserve taper and countable floors. This supports the bounded correction, not a claim that the authored 3D render is pixel-identical to the illustrative Wood reference.

Six-axis status at this verdict's scope: composition, block material/bevel, HUD material/light and type retain their prior pass/adaptation findings; background architecture passes the scored framing correction; tower silhouette/volume/detail still requires the remaining roof-course correction, with its window and material/planting findings resolved. No new material regression from this fix batch was observed in the supplied captures. This is a verdict on the four findings, not a new unrestricted whole-surface review.

## remaining

Only item 3 remains partial: clean roof-course attachment/termination at the hips in tower1/tower11/top13. Items 1, 2 and 4 are resolved. Android/W5, physical-device legibility/touch/insets, motion/audio acceptance and the previously reported documentation drift remain outside this visual-fix verdict. No user approval or pixel-identical acceptance is implied.

disposition: fix

---

## verdict

Final bounded scoring, 2026-09-21: opened all six replacement tower captures in `tools/out/fidelity_roof_final/` (1, 9, 10, 11, intermediate13, top13), verified valid 360×800 content and all six passing summary reports, and inspected 3× roof crops from tower1/top13. The other 13 states retain the reviewed `tools/out/fidelity_review_fix1/` evidence. This round scores the remaining roof finding and checks for regressions caused by that correction; it does not open a new general polish review.

1. **Front glazing — resolved, retained.** Dark front openings, cream surrounds and timber mullions remain visible in the new tower images, including 9/10 at their smaller display scale.
2. **Tall background framing — resolved, retained.** The previously accepted full-plate framing remains in the new tower images; the prior reference360/412/basic360 verdict is unchanged.
3. **Roof seam attachment — resolved.** The actual images now show continuous shallow courses across both visible slopes, meeting cleanly at the roof hip. The short hooked stubs from the first fix are gone in both native-size views and the 3× tower1/top13 crops. There are no independent seam ledges or shelf shadows. Tower9/10 retain a quiet roof read, and intermediate13 still correctly omits the global-top roof.
4. **Wood/stone and planting treatment — resolved, retained.** The accepted timber/cream separation and irregular leaf silhouettes remain present in the latest tower render.

Six-axis status at this scoped conclusion: **composition — pass/adaptation retained; block material/bevel — pass retained; background architecture — scored correction resolved; HUD material/light — pass retained; type hierarchy — pass/adaptation retained; tower silhouette/volume/detail — all three scored corrections resolved.** No material regression caused by the final roof correction was observed.

## remaining

Clear for the four material findings: the reviewer scored all four fixes resolved. This ship verdict covers that fix list and the stated Windows evidence; it is not a pixel-identical reproduction claim, user approval, new unrestricted whole-surface certification, Android/W5 acceptance or motion/audio certification. Documentation updates remain the parent's separate completion work.

disposition: ship
