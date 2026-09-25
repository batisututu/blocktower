# W0 native preview visual review

Date: 2026-09-21. Independent finish reviewer; actual Godot desktop PNGs, no web detector ran. The established B reference and `art_source/preview_direction.md` define this bounded first-asset scope. A new brand tournament or bitmap comp was not requested.

First pass inspected all 13 matrix captures and returned **fix**:

1. Focused modal primary text was ivory on brass (missing `font_focus_color`).
2. The 320×568 hint's 25px rectangle overlapped the tray because only 14px was reserved.
3. Full-board copy incorrectly suggested collecting more lines before clearing.

One repair batch set dark focused text, reserved 36px below the board and directed blocked users to clear first. All 13 captures were regenerated. The reviewer re-opened the five affected captures: compact basic, game-over, save-error, auto-confirm and blocked. Final disposition: **ship within W0 desktop preview scope**, with all three findings resolved and no visible regression in those captures.

This visual verdict does not certify Android accessibility, physical input, saved progress or final 2.5D wood art. Keyboard modal behavior has separate GUT signal-test evidence.
