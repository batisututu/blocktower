# Verdict

- **GF-01 resolved.** Refreshed `input_360x800.png` puts the reward entirely below the board. `clear_pick_360x800.png` shows the old reward dismissed while fragments are still active, a new valid ghost, and immediate placement guidance. JSON and source confirm dismissal precedes both valid and invalid preview updates.
- **GF-02 resolved.** `inset_320x568.png` retains a 296px board and the complete clear action within simulated 24px top/bottom safe insets. JSON confirms navigation and clear bounds; refreshed `basic_320x568.png` also fits. Action heights remain 48px.
- No material regression from these corrections observed in the targeted refreshed captures.

# Remaining

The scored material corrections are clear. **Ship covers GF-01 and GF-02 only**, not a whole-surface re-review. Android whole-surface validation remains **recapture**: its emulator produced a shader-link failure and gray diagnostic output, so a working renderer/device native capture is still required. Physical Samsung drag latency, smoothness, sound balance, haptics and current-build acceptance remain unverified. Android Back/font-scale/dark-mode coverage remains open. Root reports 82 tests/2843 assertions and 20 native probes pass, plus ARM64 APK export/signature validation; these do not replace native visual evidence.

disposition: ship
