# W4 finish review — 2026-09-21

## 1. Disposition

**SHIP for the Windows first-play W4 scope.** All four material findings are resolved. This is not full W0 visual fidelity, final tower art, Android hardware, or release approval.

## 2. Evidence scope

Read the W4 surface direction, development plan sections 4.1–4.5, design guide tower rules, presentation controller/screen/preferences/feedback, application startup, core session/growth code, and relevant regression tests. Compared the approved B×2 visual authority in `docs/디자인시안.png` against all eleven original native captures and all eleven fresh captures in `tools/out/w4_review_fixed`.

The final tower-specific confirmation inspected `tools/out/w4_tower_final/tower_360x800.png` and `tower_top_360x800.png`, their passing summary, and final tower code. The first image shows ten floors with flat boundary cornice for segment 1 of thirteen total floors. The second shows the remaining three floors with the actual top roof.

Reviewed `tools/out/last_test_run.json` and `gut_unit.xml`: Godot 4.7.2, GUT 9.7.1, 74 tests, zero failures/errors/pending, exit code 0. The reviewer inspected these execution artifacts; the parent ran the suite. Native capture summaries report Windows Godot OpenGL, not Android.

## 3. Material findings and correction scores

| Finding | Final score | Correction and evidence |
|---|---|---|
| Recovery action disappeared after resize | Resolved | Both layout branches reconstruct the mandatory recovery dialog. Settings cannot replace it while recovery is required. The regression resizes during commit uncertainty and verifies the reload action emits `reload_requested`. |
| Primary button text contrast | Resolved | Primary text is now `#21180f` on amber, with approximately 5.16:1 normal, 5.76:1 hover, and 4.79:1 pressed contrast. Primary buttons bypass the shared dimming tween. Fresh modal, settings, cross, and tower captures confirm the changed text. |
| Resumed below-record run lost its first New Best announcement | Resolved | Attach initializes the announcement flag only when positive score equals best. Regression verifies a resumed 50/100 run announces its first record and does not repeat it on the next placement. |
| Intermediate tower segment incorrectly received an apex roof | Resolved | `tower_segment_view()` computes acquired floor count and whether the selected segment contains the actual global top. `_draw_tower()` selects CORNICE for intermediate segments and ROOF for the actual top. Regression covers 10, 11, and 13 floors across segment boundaries; both final native captures match these semantics. |

No remaining material blocker was identified within this bounded Windows first-play review.

## 4. Lower-priority notes

The maximum reward toast can still wrap the final Korean syllable onto a separate line. Settings switches/slider retain default native-engine styling. These are follow-up refinements rather than blockers for this scoped delivery. Supply-specific notification is now reachable. The warm structural board direction, placement validity cues, pending cross, exact clear estimates/rewards, and cumulative tower labels are present and readable in the reviewed evidence.

## 5. Verification limits

This review used source, test artifacts, and native still captures; it did not independently replay live input or audition sound. Still images do not establish motion quality, repeated-session fatigue, device audio latency, sustained frame performance, safe areas, touch dimensions, or hardware haptics. Android and background/gesture behavior require W5 device evidence. No HTML detector ran. The captures use isolated deterministic disk fixtures and must not be represented as production user progression.

The B×2 art direction is recognizable, but full W0 Visual Bible fidelity, final detailed tower ornament/material work, and final art acceptance remain pending. The corrected cornice/roof distinction verifies growth semantics, not final tower art quality.
