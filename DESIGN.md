---
name: Blocktower W0 and W4
description: Implemented full-width board and gamefeel in the native W4 B material identity; historical W0 retained separately.
colors:
  w4-ink: "#f8ead2"
  w4-muted: "#d8c5a6"
  w4-gold: "#efc06b"
  w4-ready: "#d2e8b1"
  w4-primary-text: "#21180f"
  w4-disabled-text: "#b8ac98"
  w4-invalid: "#f4a591"
  b-sage: "#8ba782"
  b-clay: "#d18b62"
  b-sand: "#e5cfa9"
  b-gold: "#d7aa53"
  b-violet: "#aa8bbc"
  b-blue: "#78a8ba"
  b-panel-top: "#554330"
  b-panel-bottom: "#2b251c"
  b-panel-edge: "#a78553"
  b-tray-top: "#3a3023"
  b-tray-bottom: "#211d17"
  b-tray-edge: "#907047"
  b-board-top: "#392e23"
  b-board-bottom: "#1e1b16"
  b-board-edge: "#765c3b"
  b-button-top: "#efbc68"
  b-button-bottom: "#a96024"
  b-button-edge: "#f6d99c"
  b-disabled-top: "#61503a"
  b-disabled-bottom: "#403629"
  b-disabled-edge: "#967c56"
  b-empty-face: "#453d2e"
  b-empty-edge: "#67563d"
  b-icon: "#f3d7a2"
  charcoal: "#182126"
  surface: "#243238"
  ivory: "#f3eddf"
  muted: "#b8c6c4"
  brass: "#dfba66"
  mint: "#bdebd5"
  board: "#10191d"
  board-border: "#425156"
  empty-cell: "#29383d"
  disabled: "#29363b"
  panel-border: "#556466"
  terracotta: "#c9775f"
  ochre: "#cda453"
  sage: "#83aa99"
  steel: "#7b9cac"
  sand: "#ba9672"
  lavender: "#9889ab"
  invalid: "#f29986"
  wood: "#b48b62"
  wood-edge: "#715440"
  wood-trim: "#e1bc85"
  wood-window: "#2b4146"
  cornice: "#795b43"
  roof: "#536b65"
  roof-edge: "#a9bbb0"
  base: "#665b4f"
  base-edge: "#c8b99d"
typography:
  w4-score:
    fontFamily: "Noto Sans KR"
    fontSize: "28px"
    fontWeight: 700
  w4-heading:
    fontFamily: "Noto Sans KR"
    fontSize: "20px"
    fontWeight: 700
  w4-action:
    fontFamily: "Noto Sans KR"
    fontSize: "14px"
    fontWeight: 700
  w4-body:
    fontFamily: "Noto Sans KR"
    fontSize: "14px"
    fontWeight: 500
  w4-label:
    fontFamily: "Noto Sans KR"
    fontSize: "12px"
    fontWeight: 500
  display:
    fontFamily: "Noto Sans KR"
    fontSize: "38px"
    fontWeight: 650
  score:
    fontFamily: "Noto Sans KR"
    fontSize: "32px"
    fontWeight: 650
  title:
    fontFamily: "Noto Sans KR"
    fontSize: "22px"
    fontWeight: 650
  headline:
    fontFamily: "Noto Sans KR"
    fontSize: "20px"
    fontWeight: 650
  action:
    fontFamily: "Noto Sans KR"
    fontSize: "16px"
    fontWeight: 650
  body:
    fontFamily: "Noto Sans KR"
    fontSize: "13px"
    fontWeight: 400
  label:
    fontFamily: "Noto Sans KR"
    fontSize: "12px"
    fontWeight: 400
rounded:
  w4-focus: "8px"
  b-panel-source: "7px"
  b-panel-inset-source: "5px"
  b-empty-source: "8px"
  empty-cell: "8px"
  tray: "10px"
  control: "12px"
  modal: "16px"
spacing:
  b-texture-margin: "16px"
  b-content-margin: "8px"
  w4-page-inset: "12px"
  b-tray-inset: "12px"
  b-tray-gap: "8px"
  w4-dialog-inset: "24px"
  w4-dialog-stack: "14px"
  stack: "12px"
  inset: "16px"
  panel: "20px"
components:
  w4-button-primary:
    backgroundColor: "{colors.b-button-bottom}"
    textColor: "{colors.w4-primary-text}"
    typography: "{typography.w4-action}"
  w4-button-secondary:
    backgroundColor: "{colors.b-panel-bottom}"
    textColor: "{colors.w4-ink}"
    typography: "{typography.w4-action}"
  w4-button-disabled:
    backgroundColor: "{colors.b-disabled-bottom}"
    textColor: "{colors.w4-disabled-text}"
    typography: "{typography.w4-action}"
  w4-tray-slot:
    backgroundColor: "{colors.b-tray-bottom}"
  w4-board:
    backgroundColor: "{colors.b-board-bottom}"
  button-primary:
    backgroundColor: "{colors.brass}"
    textColor: "{colors.charcoal}"
    rounded: "{rounded.control}"
    typography: "{typography.action}"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ivory}"
    rounded: "{rounded.control}"
    typography: "{typography.action}"
  button-disabled:
    backgroundColor: "{colors.disabled}"
    textColor: "{colors.muted}"
    rounded: "{rounded.control}"
  icon-button:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.control}"
    size: "48px"
  tray-slot:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.tray}"
  dialog:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ivory}"
    rounded: "{rounded.modal}"
---

# Design System: Blocktower W0 and W4

> Scope, 2026-09-21: unprefixed tokens and “Historical W0 preview” subsections preserve the rejected synthetic preview as history. `w4-` roles and `b-` materials describe the actual native game. The [user Visual Bible](docs/디자인시안.png) governs material identity; the [approved gamefeel contract](art_source/gamefeel/direction.md) replaces the rejected narrow board and side menus. The older B fidelity review remains historical evidence for materials. Current Windows findings GF-01/GF-02 are resolved in the [bounded verdict](.impeccable/review/gamefeel/verdict-pass.md); Android whole-surface acceptance remains recapture.

## Overview

**Creative North Star: "B Structural Frame"**

### Current W4 — full-width board and gamefeel

The user-selected B × warm 2 identity retains six authored structural tile textures, bronze/wood nine-slice HUD materials, a quiet ochre architectural plate, and tapered cream-stone/brown-timber tower modules. The user's rejection of the narrow board and side menus authorizes the new full-width board composition while preserving these materials.

The native screen remains connected to GameSession and the durable repository. The [approved gamefeel contract](art_source/gamefeel/direction.md) and [existing W4 surface brief](.impeccable/surfaces/game-scripts-presentation-puzzle-screen-gd.md) own this screen's layout and interaction. The [Visual Bible refinement contract](art_source/visual_bible/direction.md) remains material history; the [original W4 contract](art_source/w4/direction.md) is first-pass history. Exact scores, 8×8 rules, three supplied pieces, saved growth and modal ownership remain implemented constraints.

**Key Characteristics:**

- Full-width puzzle board with navigation above it and three nearby supply trays.
- Six chamfered structural tile materials shared by board, tray, drag and clear remnants.
- Textured score strip, recessed trays, amber actions and live Korean labels.
- Explicit text, outlines and invalid crosses supplement color.
- Immediate finger-follow, legal-anchor assistance and committed placement/clear feedback.
- Success feedback follows the saved commit; reduced motion preserves factual results.
- Tapered tower segments retain acquired floor counts; only the global top receives a width-matched roof.

Evidence: [PuzzleScreen](game/scripts/presentation/puzzle_screen.gd), [board effects](game/scripts/presentation/board_effects.gd), [20 native cases](.impeccable/review/gamefeel/summary.json), [six real-time samples](.impeccable/review/gamefeel/motion_360x800.timeline.json), [implementation report](docs/implementation/GameFeel_Improvement_Report_2026-09-21.md), and [bounded correction verdict](.impeccable/review/gamefeel/verdict-pass.md). GF-01/GF-02 have disposition **ship** for those two Windows-native corrections only. The older [19-capture fidelity review](.impeccable/review/fidelity/finish-review.md) records material refinement history and does not approve the current experience. Android rendering, physical interaction, sound/haptics and user acceptance remain unverified.

### Historical W0 preview

The supplied B identity lands as matte colored cells with inset architectural frames, a charcoal board, warm ivory text, brass actions, and quiet wood modules. This document records the reusable values in the native Godot W0 preview. It does not create a replacement identity or establish final production art.

The build is a synthetic state-review surface with Korean text and original SVG geometry. It has no actual drag placement, save integration, or GameSession connection. Android portrait remains a working assumption pending device preference; desktop Godot is the review host. Product and Korean policy authority remain in [PRODUCT.md](PRODUCT.md) and [the design and asset guide](docs/Blocktower_Design_Asset_Guide.md); this document records implementation rather than duplicating those policies.

**Key Characteristics:**

- Matte chamfered cells with a separate inset frame layer.
- Static outlines, edge markers, symbols, and text identify preview states.
- Brass primary actions and mint keyboard focus on charcoal surfaces.
- Front-elevation wood modules with explicit shared attachment dimensions.

Source evidence: [native preview](game/scripts/presentation/design_preview.gd), [vector generator](art_source/build_vector_assets.py), [asset manifest](art_source/vector_manifest.json), and [direction contract](art_source/preview_direction.md). The [capture manifest](docs/design/captures/capture_manifest.json) records 13 regenerated desktop OpenGL captures at logical sizes 320×568, 360×800, and 412×915. Sampled images include [compact puzzle](docs/design/captures/basic_320x568.png), [focused confirmation](docs/design/captures/auto_confirm_320x568.png), and [13-floor tower](docs/design/captures/tower_13_360x800.png). These establish rendered desktop appearance, not Android touch, safe-area, enlarged-font, color-vision, or final acceptance evidence.

## Colors

### Current W4 — full-width board and gamefeel

**Primary:** the amber action gradient uses `b-button-top`/`b-button-bottom` with its light edge and dark `w4-primary-text`. Reward text uses `w4-gold`; valid placement, pending outlines and focus use `w4-ready`.

**Secondary:** the six `b-sage`, `b-clay`, `b-sand`, `b-gold`, `b-violet` and `b-blue` colors are source face colors from `build_surfaces.py`. Thirteen saved family IDs map to these six textures through `VisualBibleTheme.FAMILY_MAP`; they do not change rules or rewards. Invalid coral retains crosses and explanatory text.

**Neutral:** panel, tray, board and disabled top/bottom/edge tokens describe the actual gradient SVG assets. Component backgroundColor in frontmatter names the lower gradient stop, not a substitute flat fill. Empty face/edge and icon ink have separate roles. These colors come from code and editable assets, not sampled scenery.

**The W4 Action Contrast Rule.** Primary text stays dark in normal, hover, pressed, and focused states; all enabled buttons share press modulation without replacing the dark primary text color.

### Historical W0 preview

Warm material colors sit on dark blue-green neutrals; action and state accents have distinct jobs.

### Primary

- **Brass** (`brass`) fills enabled primary actions and outlines the selected tray slot.
- **Mint** (`mint`) identifies pending-line outlines, edge dots, positive hint text, and keyboard focus.

### Secondary

- **Terracotta, ochre, sage, steel, sand, lavender** tint the common white B cell texture. The tray currently samples terracotta, ochre, and steel.
- **Invalid coral** (`invalid`) supplies the invalid overlay's outline and translucent fill; a cross supplies a second cue.
- **Wood, wood edge, wood trim, wood window, cornice, roof, roof edge, base, base edge** are SVG material roles, not additional UI action colors.

### Neutral

- **Charcoal** is the full viewport and primary-button text color.
- **Surface** backs secondary controls, tray slots, and modal panels.
- **Ivory** carries strong content; **muted** carries supporting labels and disabled text.
- **Board**, **board border**, and **empty cell** distinguish the grid from surrounding controls.
- **Disabled** and **panel border** identify their corresponding native control surfaces.

**The Action Contrast Rule.** Primary-button text stays charcoal in normal, hover, pressed, and focused states; focus adds a mint outline.

## Typography

### Current W4 — full-width board and gamefeel

Bundled Noto Sans KR uses variable weights 500 for regular content and 700 for strong content. Recurring roles are the `w4-` type tokens. Puzzle wordmark is 18px strong; tower heading and total are 22px and 28px. The score's nominal role is measured against its available width, with a code fallback down to 8px. If either score exceeds eight characters, score and best become separate 13px/11px rows with exact integers. This fallback is an implementation fact, not a reusable accessibility minimum.

The best caption is 10px and best value 13px; mode and settings labels are 12px. Board hints use 11px normally and 10px in compact layout. Ordinary placement rewards use 14px in the hint strip; clear rewards use two 18px lines. Dialog headings use the heading role and messages use body. Native vertical centering applies; no custom line-height or tracking is established. Android enlarged-text behavior remains unverified.

### Historical W0 preview

**Display and body font:** bundled [Noto Sans KR](game/assets/fonts/NotoSansKR.ttf), using variable weights 400 and 650 through `FontVariation`. There is no separately configured display or mono family. Labels vertically center inside explicit rectangles; the code does not override line height or letter spacing.

The frontmatter records the recurring type roles. Tower totals use display, puzzle scores use score, the wordmark and review title use title, dialog and tower headings use headline, buttons use action, and descriptive copy uses body or label. The auto-clear control overrides its text to 13px at weight 650; the tower entry total is 23px at weight 650. Supporting tower-entry text is 14px and 11px. Compact board hints reduce from 12px to 11px.

The preview-only footer is currently 9–10px. That observed value is not a reusable minimum or a production accessibility standard, so it is excluded from the normative type ramp. Enlarged-font behavior has not been verified.

## Layout

### Current W4 — full-width board and gamefeel

The native canvas remains 360×800 with `canvas_items` stretching and expanding aspect. The puzzle board side is `w-24`: 296, 336 and 388 logical pixels at reviewed widths 320, 360 and 412. Its horizontal origin is 12px and its backing grows 4px around the grid. Tower and settings occupy a 48px navigation row above the 48px score/mode row; no board-side menu lane remains.

Android top/bottom safe insets are read from DisplayServer and converted to logical height. Let `u` be height minus those insets and `side=w-24`. Compact mode uses `u<680`; its spare height is `max(0,u-side-224)`, top padding `min(8,spare)`, row starts separated by 52px, board-to-tray distance 20px, tray height `48+min(16,max(0,spare-top_padding))`, then a 4px gap and 48px clear action. This fits the tested 320px width at 520px usable height, including simulated 24px top/bottom insets at 320×568. Smaller usable heights are not established support.

Normal mode uses top padding `max(8,(u-side-272)*0.30)`, 56px row separation, 32px board-to-tray distance, 104px trays and an 8px gap before the 48px clear action. The accumulated-floor label sits below the action and is hidden in compact mode. Three tray widths are `(w-24-16)/3`; all current pieces share a cell unit capped at 28px and constrained by the actual maximum width/height of the three pieces, using 16px horizontal and 12px vertical allowance.

The hint starts 4px below the board and reserves 20px compact/26px normal. Ordinary rewards temporarily use this strip; every new pickup dismisses the previous reward and restores current placement guidance. Clear rewards have two lines in the central board region until dismissed or faded; milestone summaries use the lower growth label, which remains hidden in compact mode.

The architecture TextureRect uses `STRETCH_SCALE` over the full viewport to retain the full plate. Dialogs retain a wrapping vertical container, the W4 dialog inset/stack and actions at least 48px high. Settings uses `max(12,(h-480)/2)` for its larger stack. Resize interrupts transient feedback and rebuilds the surface, restoring recovery ownership when needed. Simulated inset evidence is Windows geometry validation; physical Android safe areas, dialog insets and enlarged fonts remain unverified.

### Historical W0 preview

Values are Godot logical pixels. The project starts at 360×800 with `canvas_items` stretching and expanding aspect. The only responsive branch is `size.y < 700`; there are no width breakpoints, safe-area insets, or device density rules in this preview.

The puzzle is an 8×8 square centered horizontally. With viewport width `w` and height `h`, growth entry begins at `h - 18 - growth_h`; clear begins 12px above it; tray begins another 12px above clear. Board top is 180px normally and 130px in compact mode. Its side is `min(w - 32, tray_y - board_top - 36)`, reserving 36px before the tray for the hint. The hint occupies a 25px-high rectangle starting 3px below the board.

| Geometry | Normal | Compact (<700px high) |
|---|---:|---:|
| Header top | 20px | 8px |
| Score top | 82px | 56px |
| Tray height | 86px | 58px |
| Clear height | 56px | 48px |
| Growth entry height | 62px | 48px |
| Tray cell size | 29px | 23px |

At 320×568 the board is 208px square (26px per cell); at 360×800 it is 328px (41px per cell); at 412×915 it is 380px (47.5px per cell). The board backing extends 5px beyond its grid. Tray and bottom actions have 16px horizontal insets. Three equal tray lanes each draw a slot 4px narrower than one third of the tray width.

Modal panels sit 20px inside each horizontal edge and center vertically; one-action panels are 202px high and two-action panels are 260px high. Primary and secondary actions sit at panel y=138 and y=196, each 48px high with 16px side insets. Modal descriptions wrap in a 68px-high rectangle.

Tower preview uses a 160px-wide source module and 40px source floor height. Scale is `min(1.25, (h - 270) / (floor_count * 40 + 78))`; the base bottom sits at `h - 115`. This fits the sampled 0–30-floor review range, not an implemented production camera or long-tower navigation system.

## Elevation & Depth

### Current W4 — full-width board and gamefeel

The background is an independent raster plate; HUD and cells use authored gradient/bevel/texture SVG layers, and towers use transparent orthographic 3D renders. Panel sources include a restrained baked dark offset silhouette, inset border and edge light; there is no general runtime panel-shadow system. Structural tiles retain chamfered faces, light and dark bevels, fine stone grain and corner seams; clay and blue also carry brick divisions.

Modal scrim remains `Color(0.08, 0.06, 0.04, 0.94)`. Enabled buttons compress to scale 0.955 over 65ms with cubic ease-out, then return over 120ms with back ease-out; layout rectangles stay fixed. Placement settles over 140ms through scale 0.78 → 1.06 → 1.0. Clear runs for 420ms: an early material highlight, axis sweep at 45–230ms, staggered shrink after 120ms, then deterministic fragments after 130ms, capped at 36. Input releases at 280ms independently of the clear tail. No screen shake or full-screen flash is authored.

Ordinary placement text holds 450ms, other toast text 1000ms, followed by a 150ms fade; a new pickup dismisses either immediately. The older `TOAST_HOLD=1.8` constant remains in the file but is not the active toast duration. Reduced motion keeps button scale at one with immediate color feedback, skips placement/clear motion and releases settling immediately while preserving text and saved results. Cancelling, layout changes, focus loss and pause interrupt active feedback.

**The Committed Feedback Rule.** Preview motion may describe a candidate placement, but score, clear, unlock, and new-record success feedback comes only from a committed session result.

### Historical W0 preview

No drop shadows, animated transitions, bloom, or runtime camera effects are authored in this preview. Cell depth comes from SVG tonal layering: a black inset at 4.5% opacity, a white inset fill at 6%, a white internal stroke at 66%, and a black bottom edge at 18%. A separate warm-ivory frame adds a 58% opacity stroke. These small bevel cues belong to the B material rather than general panel elevation.

Dialogs dim the entire surface with native `Color(0.025, 0.05, 0.06, 0.85)` and use a bordered panel. Pending lines are static 10%-opacity mint-like fills with mint borders and edge dots. The `reduced_motion` field is initialized but unused: there is no implemented motion preference or production feedback sequence to document.

## Shapes

### Current W4 — full-width board and gamefeel

Occupied tiles are original 128×128 SVG geometry with cut corners, separate bevel planes, inset structural faces and seams. They are drawn 0.35 logical pixels inside each cell rectangle. Empty cells are independently textured. Source radii in frontmatter describe the 128px asset geometry, not fixed runtime corner sizes.

Five panel textures use 16px nine-slice texture margins and 8px content margins through the cached VisualBibleTheme. Native focus remains a transparent 1px ready-color border with the W4 focus radius. Pending row/column and valid/invalid outlines use 2px strokes; invalid placement adds diagonal crosses. The geometric state overlays remain separate from material texture.

### Historical W0 preview

The B cell source is 64×64. Its outer path spans coordinates 2–62 with 8px corner chamfers; the inner frame spans x=13–51 and y=13–49 with clipped top corners and a 2px stroke. Empty cells use a 60×60 rectangle at (2,2), with the empty-cell radius in frontmatter. Frame geometry scales with the cell; it is not a fixed screen-pixel border.

Valid and invalid overlay rectangles are 58×58 at (3,3), radius 7px, with 3px strokes. Their check and cross paths remain geometric SVG marks. Pending-line outlines use a 5px radius, a 1px border, and 2.5px-radius edge dots. The selected tray border and control focus border are 1px.

Shared icon sources are 24×24 with 1.7px round strokes. Native icon buttons use the 48px square control size. The shipped state-selected SVG is an available asset; the preview currently selects by outlining the tray slot in brass.

## Components

### Current W4 — full-width board and gamefeel

**Actions and HUD.** Actual Button/Label controls sit over panel assets; no painted text or fake scores. Primary uses `button.svg`, secondary `panel.svg`, disabled `disabled.svg`. Hover modulates texture RGB by `(1.08,1.06,1.02)` and pressed by `(0.92,0.91,0.89)`. Focus adds the native ready outline. All enabled buttons now use shared scale/color press feedback; primary text retains its dark color assignment. Clear uses factual pending counts/rewards and locks during dragging, committing, settling or recovery. Game over changes its action to results.

**Board and tray.** The shared texture routine renders board, tray, drag and clear cells. FAMILY_MAP is sage/clay/sand/clay/gold/sage/violet/blue/sage/clay/sand/blue/violet for saved IDs 1–13. One pointer owns a drag; touch lift is 1.4 board cells. A 3×3 neighborhood searches only legal anchors within 0.70 cell, retaining a legal anchor up to 0.90 cell. Preview and release use the same strict session validator and selected origin. Real-material ghosts and prospective completed-line outlines show the candidate; invalid placement adds crosses and text. Escape, outside release, focus loss and layout change cancel transient input.

**Dialogs, settings and feedback.** Modals block background input/focus, explain pending-line auto-clear rewards and restore focus on dismissal. Recovery cannot dismiss into uncertain saved state. Settings keeps native check buttons and a volume slider, persists preferences separately and restores values after failed writes. Nine cue names use a bounded six-player pool. Five newly authored sounds (`button`, `snap`, `clear`, `air`, `chime`) are bound from `game/assets/audio/gamefeel`; clear layers air, with chime added for two or more lines. Sound sources and hashes live in the gamefeel asset manifest. Optional haptics are off by default and gated to Android/iOS; mute and volume settings remain. These bindings are not device listening or haptic quality certification.

**Wood tower.** Nine editable 3D scenes and their transparent PNGs are `floor_entry`, `floor_wide`, `floor_mid`, `floor_top`, `roof_wide`, `roof_mid`, `roof_top`, `cornice`, `base`. They share a 640×480 canvas, (320,240) source anchor, 1.18 world-unit floor height and 106.468368530273px projected step from geometry.json. Runtime shows at most ten acquired floors: first three wide, next three mid, next four top; the first global floor uses the entry module. Scale is `min(w/470, (h-455)/(count*floor_step+205))` and anchor is `(w/2,h-245)`. Intermediate segments end in a cornice; the actual global top gets a roof matching the current width.

Dark front arch glazing, cream surrounds, brown timber mullions/cornice undersides, balconies, stone stairs and irregular leafy planting are bound in the editable source. Roof courses are UV/material-bound to the actual mesh, with no independently positioned seam bars. Preserve this attachment when regenerating. Completed segments can be representative; incomplete segments remain viewable. No shop, mission or customization controls are fabricated from the reference.

### Historical W0 preview

### Buttons

Rounded native controls share the primary and secondary primitives. Native hover fills are `brass.lightened(0.08)` or `surface.lightened(0.07)`; pressed fills are `brass.darkened(0.1)` or `surface.darkened(0.15)`. Disabled fill and text use their explicit tokens. The transparent focus style adds a mint border while preserving the button's text contrast. No animation duration is defined.

The clear button is wide and disabled when the fixture has no pending lines. Its enabled label includes the pending-line count. Clear opens an explanatory preview dialog and does not commit gameplay. The auto-clear control toggles a preview flag and opens a confirmation when lines are pending.

### Tray and board states

Three tray slots center reusable cell and frame textures. Each slot has a native button target and mint keyboard focus. Clicking selects a synthetic valid-placement fixture; no dragging, snapping, or touch-offset implementation is present.

The draw order is board backing, empty/occupied cells, frames, pending row and column overlays, then valid/invalid overlays. Valid uses a check; invalid uses a cross. Pending lines use perimeter dots and a continuous outline plus a textual count. The blocked fixture's hint directs the player to clear first. The stock cross fixture and stock placement fixtures are separate captures; their existence does not establish coverage of every combined state.

### Dialogs and navigation

The modal covers the viewport, stops pointer input, removes background buttons from keyboard focus, and focuses its primary action. Closing restores the recorded background focus modes. Escape closes the modal or returns from tower to puzzle. Settings opens a review-state chooser, not production settings.

The puzzle's tower entry is a single secondary button with nested labels. The tower page has back/settings icon controls, a floor total, material summary, and a wide return action. There are no implemented text inputs, chips, purchase navigation, or customization controls.

### Wood tower modules

Original front-elevation SVGs share 160px source width: floor 40px high, cornice 12px, roof 42px, base 24px. The visible floor facade spans x=8–152, with three windows and common top/bottom edges. Floors stack upward by exactly one floor height. A cornice crosses a completed ten-floor boundary when additional floors exist above it; the roof is drawn once above the last floor. The zero-floor fixture substitutes explanatory text.

These are the first reusable wood assets, not the final 2.5D tower render specification. Final camera, lighting, Blender source, material expansion, and production rendering remain governed by the Korean guide.

## Do's and Don'ts

### Current W4 — full-width board and gamefeel

- **Do** derive board, tray, dragged, and clearing cells from the same six authored structural textures.
- **Do** preserve dark primary text across all control states.
- **Do** retain explicit pending counts, placement text, and invalid crosses alongside color.
- **Do** tie success feedback to saved commits and keep text when motion or audio is reduced.
- **Do** preserve full-plate architecture framing and a quiet central board field.
- **Do** use a cornice on intermediate segments and a width-matched roof only at the actual top.
- **Do** keep roof courses bound to mesh UVs and editable source assets aligned to runtime exports.
- **Don't** promote the scoped GF-01/GF-02 Windows correction verdict into whole-surface Android or physical-device acceptance.
- **Don't** apply historical W0 or superseded first-pass W4 materials to the refined surface.

Native default settings widgets and unverified physical safe-area/enlarged-font behavior are limits, not a new production standard. PRODUCT.md's older selection-awaiting and synthetic-only statements are pre-existing drift and remain unchanged. Sidecar HTML/CSS specimens are illustrative translations; native code and reviewed captures remain rendering authority.

### Historical W0 preview

### Do:

- **Do** derive new B cells and tray pieces from the shared cell and frame geometry.
- **Do** preserve charcoal primary text through focus and retain the mint focus border.
- **Do** keep the board hint reserve when adapting the compact preview layout.
- **Do** label synthetic state and desktop rendering evidence accurately.

### Don't:

- **Don't** replace the pinned B identity with glossy gem styling or an unrelated brand concept.
- **Don't** treat the 9–10px preview footer as an approved body-text minimum.
- **Don't** infer mobile verification, final acceptance, or completed gameplay from the W0 captures.
- **Don't** treat front-elevation wood vectors as the final 2.5D production specification.

Not canonized: tiny preview-only disclosure text and unverified device behavior are limitations, not reusable accessibility rules. No final review approval is claimed. The sidecar's self-contained HTML/CSS samples are illustrative translations for a design panel; native Godot source and captures remain rendering authority.


<!-- impeccable-documenter evidence footer, 2026-09-21 -->
Documentation scope: merged the approved gamefeel implementation into current W4 descriptions and sidecar; preserved all Historical W0 preview subsections. Source inspection and the recorded 82 tests / 2,843 assertions plus 20 Windows-native cases support these implementation statements. Six instrumented real-time frames cover requested 0/60/140/220/300/460ms points; PNG readback is not a device latency benchmark. The ARM64 versionCode 3 APK was built, but the Samsung physical device is absent and this build was not installed there. A separate pre-fix QA build installed/launched on an emulator whose SwiftShader shader-link failure produced gray output; that is diagnostic evidence, not an Android visual pass. Sound balance, haptics, Android Back/font-scale/dark-mode and real-world acceptance remain pending. PRODUCT.md drift and runtime edits are outside this documentation pass.


Physical follow-up (2026-09-21): version3 was subsequently installed on SM-N981N/Android13.26checks passed across the real user app and an isolated QA package with180byte-identical runtime assets. Native captures/22-second motion recording and state comparisons are in [the device report](docs/implementation/GameFeel_Device_Verification_2026-09-21.md). The user1047-point/9-floor state was preserved and QA removed. This supersedes the earlier absent-device status for installation/basic smoke only; full experience, audio/haptics and expanded Android acceptance remain open.
