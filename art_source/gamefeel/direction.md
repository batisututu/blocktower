# Board-first B refinement

User authority: 2026-09-21 device screenshot rejection and docs/Blocktower_UX_GameFeel_Improvement_Research_v0.1.md. The user explicitly replaces the narrow board/side-rail layout. Keep B structural materials, real controls, saved rules and tower assets; prioritize a full-width 8x8 board, upper navigation, close three-piece tray and restrained score/mode information.

At 360 logical px, board width becomes 336 (old 248), with a 12px margin per side. Settings and tower share the top navigation row, outside board hit geometry. At 320x568 preserve the same width-minus-24 rule using a compact tray and no duplicate lower tower label. Navigation, mode and clear targets stay at least 48 logical px. Respect physical safe insets on Android.

Game feel: immediate finger-follow, nearest legal anchor within 0.70 cell, 0.90-cell release hysteresis; real-material ghost with prospective line highlights. Placement pop, 420ms clear sequence, 280ms input lock, deterministic <=36 fragments, layered authored sound, opt-in haptics and reduced-motion equivalence. No screen shake or full-screen flash. Button down visibly compresses all enabled buttons; up rebounds without moving their layout rectangles.

Verification: new full native review against this request and the rejected screenshot; never treat historical fidelity verdict as current acceptance. Include 320/360/412 widths, transient effect frames, settings/confirmation, exact score extremes and physical Android captures. Static screenshots cannot certify sound or timing; provide deterministic timing samples and a device recording separately. No HTML detector on native Godot. No new reference art/competitor code is vendored.
