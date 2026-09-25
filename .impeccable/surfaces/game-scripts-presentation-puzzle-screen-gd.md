---
version: 1
slug: "game-scripts-presentation-puzzle-screen-gd"
primary_target: "game/scripts/presentation/puzzle_screen.gd"
related_targets: ["game/scripts/presentation/board_effects.gd","game/scripts/presentation/visual_bible_theme.gd","game/scripts/presentation/presentation_controller.gd","game/scripts/presentation/feedback_tokens.gd","game/scripts/presentation/feedback_player.gd","game/scripts/presentation/presentation_preferences.gd"]
---

# W4 playable game — full-width board and gamefeel

Primary target: `game/scripts/presentation/puzzle_screen.gd`
Related targets: `game/scripts/presentation/board_effects.gd`, `game/scripts/presentation/presentation_controller.gd`, `game/scripts/presentation/feedback_tokens.gd`, `game/scripts/presentation/feedback_player.gd`, `game/scripts/presentation/presentation_preferences.gd`

Mode: Operate / game play.

## Direction contract

This brief records the user's approved replacement of the narrow board and side menus under the [gamefeel contract](../../art_source/gamefeel/direction.md), informed by the [UX/GameFeel research](../../docs/Blocktower_UX_GameFeel_Improvement_Research_v0.1.md). The B warm architectural identity is retained. The [Visual Bible contract](../../art_source/visual_bible/direction.md) remains material history and the [original W4 contract](../../art_source/w4/direction.md) remains first-pass history.

THESIS: Let the player place blocks and choose when to clear, with saved architectural growth as the consequence. The actual board, candidate placement, and pending counts lead.

OWN-WORLD: User-confirmed B, structural B × warm 2 from `docs/디자인시안.png`: warm umber and sandstone, matte beveled blocks, Korean typography, and dimensional architecture. Current materials refine B×2 and the Wood tower through six structural tile textures, bronze nine-slice panels, a complete ochre architecture plate and nine editable 3D modules.

STORY: Read the board, drag a supplied piece, see a valid or invalid candidate, commit placement, clear completed lines, then inspect persistent tower growth. Success feedback follows the durable session result.

FIRST VIEWPORT: Wordmark, tower and settings in a 48 px top row; live score/best/mode in a 48 px row; full-width 8×8 board with 12 px side insets; below-board hint/reward strip; three nearby supply trays; distinct 48 px amber clear action. Board side is w-24: 296/336/388 at 320/360/412 widths. Compact mode uses usable height after safe insets, 48–64 px trays and no duplicate lower tower label; normal trays are 104 px. The tested compact minimum is 520 px usable height at width 320. Shared tray unit adapts to actual maximum width/height across all three pieces, capped at 28 px. Full-plate STRETCH_SCALE architecture framing remains. Scores longer than eight characters use separate exact score/best rows.

INTERACTION: One pointer follows immediately with 1.4-cell touch lift. Legal-anchor assistance searches a 3×3 neighborhood within 0.70 cell and retains a valid anchor through 0.90 cell; release commits the same validated origin. Material ghosts, prospective line outlines, invalid crosses and explanatory text identify the candidate. Saved placement settles in 140 ms. Clear visuals run 420 ms, input releases at 280 ms, and deterministic fragments cap at 36. Ordinary placement rewards use the below-board hint strip; every new pickup dismisses any previous reward and immediately restores guidance. Clear reward is two lines; milestone summary uses the lower label and remains hidden in compact mode. Enabled buttons press in 65 ms to 0.955 scale and rebound in 120 ms. Reduced motion preserves saved results and text while skipping decorative movement. Five original gamefeel sounds join the existing six-player audio pool; muted/volume/opt-in haptic preferences remain.

FORM: Existing native Godot game with a user-authorized board-first composition replacement. The Visual Bible governs B materials; the approved gamefeel contract governs the new layout. No new aesthetic direction is introduced.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Evidence and limits

The [current 20-case native matrix](../review/gamefeel/summary.json) covers Windows Godot OpenGL at 320×568, 360×800 and 412×915 across the matrix, including basic/valid/invalid input, exact score extremes, cross and maximum clears, settings/confirmation, button press, tower top, simulated 24 px safe insets and immediate pickup during the clear tail. This is not every state at every size. [Six real-time samples](../review/gamefeel/motion_360x800.timeline.json) target 0/60/140/220/300/460 ms and record actual elapsed timestamps. Instrumented PNG readback does not establish physical device latency or frame rate. The [implementation report](../../docs/implementation/GameFeel_Improvement_Report_2026-09-21.md) records 82 tests/2,843 assertions passing.

The [initial current finish review](../review/gamefeel/finish-review.md) identified GF-01 reward interference and GF-02 compact safe-area overflow. The [bounded confirmation](../review/gamefeel/verdict-pass.md) resolves both with disposition **ship for those two Windows-native corrections only**. The Android whole-surface disposition remains **recapture**. The [older fidelity review](../review/fidelity/finish-review.md) and its 19 captures are historical material evidence, not acceptance of this revised experience. No HTML detector ran on this native surface.

ARM64 versionCode 3 (`0.1.0-gamefeel3`) APK was built, but the Samsung physical device is absent and the current build was not installed there. A separate pre-fix QA APK installed/launched on the emulator; SwiftShader GLES3 SceneShader/CanvasShader linking failed and produced a gray diagnostic image. No Android visual pass is claimed. Physical safe areas, Back/font-scale/dark-mode behavior, drag latency, smoothness, sound balance, haptics and real-world/user acceptance remain pending.

<!-- impeccable-documenter evidence footer, 2026-09-21 -->
Documentation scope: DESIGN.md, .impeccable/design.json and this existing W4 surface brief only. Current statements are extracted from PuzzleScreen, board_effects, feedback_tokens, presentation_controller and feedback_player plus the linked current evidence. Historical W0 subsections and metadata remain preserved. Native code and reviewed captures govern rendering; sidecar HTML/CSS is illustrative. PRODUCT.md's pre-existing drift and runtime implementation are outside this write boundary.


후속 실기기 증거: 2026-09-21 version3 SM-N981N 설치 및26개 기능 검증 통과. [기기 보고서](../../docs/implementation/GameFeel_Device_Verification_2026-09-21.md)의 본 앱/QA 분리, 네이티브 녹화와 세이브 대조를 따른다. 위 미연결 기록은 당시 상태이며 사람의 체감·음향/햅틱과 전체 Android 품질 승인은 여전히 미완료다.
