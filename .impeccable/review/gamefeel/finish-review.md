# Disposition

**FIX** — a fresh full review against the user's rejected screenshot and 2026-09-21 research request. Two material corrections, no rebuild. Historical ship reviews are not acceptance evidence. Android emulator capture is pending.

# Material findings

**GF-01 — Reward feedback competes with live placement.** `input_360x800.png` shows the placement reward over the first board row. `_toast()` hides guidance for 0.6–1.15 seconds, while another drag can start after 0.14/0.28 seconds and does not dismiss the reward. Move ordinary rewards outside the board, and dismiss any reward/show current guidance immediately on pickup. Verify valid and invalid rapid successive drags plus exactly one commit.

**GF-02 — Compact safe-area overflow.** At 320×568 the no-inset clear target ends at y560. The current top inset is added to that position, so any top+bottom inset total above8 places part of the target outside usable content. Derive compact spacing/tray from usable height while retaining the full board and 48px action targets. Verify top24/bottom24 and native safe-area geometry.

# Strengths and scope

The board now occupies width minus24, the navigation is above it, and the tray is nearby. This clearly addresses the rejected narrow board/side rails while preserving warm B materials. Ghost/release share strict session validation. The clear sequence has distinct visible phases and bounded fragments. The old tail callback cannot cancel a new drag, and a new commit kills prior effects. Compact dialogs/settings and extreme score copy fit the reviewed captures. No unrelated redesign is requested.

# Evidence and coverage

Reviewed the rejected reference, all18 supplied scenario captures (including 320/360/412 widths), the six real-time motion frames, source for screen/controller/effects/audio/tokens, and relevant tests/JSON records. Real-time Windows samples are settling at230.8ms, idle by309.8ms, complete at466.6ms. Controlled phases and instrumented PNG readback are not physical performance evidence. Root reports80 tests/2834 assertions and18 native probes. No HTML detector was run because this is native Godot. Raster assets are prior B assets; new sound is original synthesis. The JSON companion lists inspected files.

# Remaining validation

Apply the two corrections in one batch and provide targeted confirmation. Android whole-surface acceptance requires **RECAPTURE**: the isolated QA APK installed/launched, but the emulator SwiftShader GLES3 renderer failed SceneShader/CanvasShader linking (261 active fragment uniforms exceed its limit). Its gray `emulator_puzzle.png` is diagnostic only and excluded from acceptance; the Windows evidence remains valid. Obtain native screenshots from a working Android renderer/device, Back behavior, font scale1.3/dark-mode coverage and actual inset geometry. A physical Samsung is absent: physical drag latency, refresh smoothness, sound balance and haptics are still unverified. Current-build physical approval is not claimed. Separate documentation refresh should describe only the confirmed final implementation.
