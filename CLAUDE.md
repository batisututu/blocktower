# Blocktower project rules

These project-specific mappings adapt `C:/DEV/CLAUDE.md` to the existing Godot design and the user's Korean planning workflow.

## Sources and language

- Read [GAME-DESIGN.md](GAME-DESIGN.md), [docs/README.md](docs/README.md), and the current development plan before implementation.
- Preserve Korean game planning documents and discuss changes with the user in Korean. Use English for repository conventions, ADRs, identifiers, and commit messages. Keep code comments in Korean.
- Use the established terms: `GameSession`, `SaveRepository`, `occupancy`, `cell_style`, `queue`, `batch_id`, `batch_success`, `streak`, and versioned supply IDs. Define new terms in contracts first.

## Godot mapping of shared conventions

- Runtime language is GDScript. TypeScript syntax, `tsc --noEmit`, and JavaScript naming conventions do not apply to GDScript files. Use Godot naming conventions and explicit types where practical.
- The shared `src/types/` contracts responsibility maps to `game/scripts/core/contracts/`. The v0.2 piece generation and W2 GameSession State/Action/Result contracts now exist. W3 disk encoding/recovery contracts also exist in file_save_contract.md. Do not create duplicate TypeScript contracts.
- Before implementing a feature, read or define its State/Action/Result contracts, ownership, errors, and invariants. Verify with the pinned Godot import/headless runner and applicable GUT tests. Fail on parser errors, failed tests, zero discovered tests, or unresolved required pending tests.
- Keep ADRs in `docs/adr/`. Create other folders as their contents become necessary.

## Implementation boundaries

- Godot 4.7.2 and GUT 9.7.1 are the tested baseline; use an explicit executable path and pinned addon commit. See [ADR-0001](docs/adr/0001-godot-baseline-and-contracts.md).
- `GameSession` serializes actions. Compute a candidate state, commit the complete puzzle/growth/RNG state, then publish presentation events. Animation and acknowledgement callbacks never award growth.
- Treat static definitions as read-only and give runtime state explicit ownership. Resources are not automatically deeply immutable.
- Preserve `docs/examples/` and preflight evidence. Copy/adapt reference code when implementation starts and retest the production target. Historical tests do not prove integration, mobile behavior, or balance.
- Keep engine installations, caches, build outputs, signing files, and secrets outside tracked source. Record asset origin and licenses from first adoption.
- One agent edits a file at a time. Claude Code provides implementation/review evidence; Codex reviews rule boundaries, persistence, input, and readability. Distinguish proposals, working decisions, and executed verification.

## Current scope

The earlier generator-first request established the isolated, tested piece generator. The current request refines the user-selected B direction to reproduce detailed Visual Bible appearance in the actual W4 app. See [ADR-0002](docs/adr/0002-versioned-board-aware-piece-generation.md). v0.2 code and evidence exist. At the user's request, skip Claude Code review; Codex completed a self-review with 25 passing tests (see docs/implementation/piece_generation/Codex_Review_2026-09-21.md). This is not third-party approval. W2 GameSession/minimal growth/in-memory commit integration now passes 45 tests; see docs/implementation/W2_GameSession_Report_2026-09-21.md and ADR-0003. W3 Windows file SaveRepository/startup/recovery now passes 58 total tests and 26 cross-process checks; see docs/implementation/W3_File_Save_Report_2026-09-21.md and ADR-0004. W4 now connects real input/HUD/feedback/settings/minimal wood tower to the file session: 74 total tests and Windows native probes pass; see docs/implementation/W4_Presentation_Report_2026-09-21.md and ADR-0005. Detailed B art and scoped Windows visual review are complete; see docs/implementation/Visual_Fidelity_Report_2026-09-21.md. Full W4-D experience acceptance and W5 remain pending.

W1 provides pinned engine/GUT tooling. The existing W0 preview and first SVGs are functional drafts; the user identified a material mismatch with the supplied Visual Bible. Keep the delivered B refinement aligned with [design guide section 11](docs/Blocktower_Design_Asset_Guide.md) and [visual target](art_source/visual_target.json). Mobbin and asset research do not establish completed art. Preserve existing test evidence and synthetic preview behavior. W2 headless GameSession is implemented. W3 Windows persistence is implemented; Windows playable input is implemented; detailed B art now lives under art_source/visual_bible and game/assets/visual_bible; mobile export/stale-lock recovery remains unfinished.

W5 interim follow-up: Android ARM64 debug APK is installed on SM-N981N (Android 13). Real OS touch input, auto clear/growth, background/restart/update persistence and Android back navigation pass; 75 tests / 2,602 assertions. See docs/implementation/W5_Device_Interim_Report_2026-09-21.md. AppRoot owns Android back; screen.handle_back handles modal/drag/tower before root exit. Android stale-writer-lock recovery remains unimplemented; do not represent post-commit restart as kill-during-commit validation.


W5 storage update (2026-09-21): Android native FileChannel locking and conservative legacy PID-claim recovery are implemented; see [ADR-0006](docs/adr/0006-android-process-death-save-recovery.md) and the [W5 recovery report](docs/implementation/W5_Android_Save_Recovery_2026-09-21.md). Current results: 84 unit tests / 2,867 assertions, 26 Windows process checks, 44 Android16 emulator recovery checks. SM-N981N disconnected after initial QA install; version4 production installation and physical-device recovery matrix remain pending. This supersedes earlier stale-lock implementation status, not historical evidence or full-W5 acceptance.


Latest W5 lifecycle update (2026-09-21): [ADR-0007](docs/adr/0007-application-lifecycle-input-boundary.md) and [lifecycle report](docs/implementation/W5_Lifecycle_Input_2026-09-21.md) define focus/pause blockers, stale-control rejection and mandatory-recovery retention. 93 tests / 3,005 assertions, 37 Windows native checks and 26 process persistence checks pass. Version5 combines lifecycle changes with Android recovery. User explicitly holds APK installation and physical-device recovery validation until the combined run; do not treat reconnection alone as permission to resume it.


Latest W5 physical-device update (2026-09-23): The user explicitly resumed installation and combined device validation. Version6 is installed on SM-N981N (Android13), preserving the original complete session and preferences. The 44 physical-device save recovery checks pass. A real OS notification propagation bug blanked the startup recovery notice in version5; deferred notice replacement with immediate stale-control invalidation fixes it. Post-fix checks: 95 tests / 3,027 assertions and 22 Windows lifecycle input checks. See [combined device report](docs/implementation/W5_Device_Combined_Verification_2026-09-23.md) for the final physical input matrix and remaining performance/experience limits. This supersedes the September21 installation hold and implementation-status statements, while preserving historical evidence.

Latest Phase 3 Android update (2026-09-25): Version8 was installed on the connected SM-N981N after the main package was absent at the start of this run. The Phase 3 MVP passes 138 tests / 3,709 assertions and current-source QA package checks for 30/300/3,000-floor views, copy/restart and short frame/memory measurements. The QA package was removed after validation; the main app remains installed with a new revision0 save. See [Phase 3 device report](docs/implementation/Phase3_Android_Device_Validation_2026-09-25.md). Minimum supported hardware and first-play human observation remain open.

Phase 4 local MVP work (2026-09-25): [ADR-0008](docs/adr/0008-phase4-verified-weekly-challenge.md) and the [online contract](game/scripts/core/contracts/online_phase4_contract.md) define a separate guest weekly challenge, UTC cutoff, full action replay, prefix-only updates, and read-only verified tower viewing. The [implementation](docs/implementation/Phase4_Online_MVP_2026-09-25.md) and [local E2E validation](docs/implementation/Phase4_Local_E2E_Validation_2026-09-25.md) records cover server replay, Android QA challenge persistence/submission, and verified tower viewing. Public deployment and release operations remain open; do not treat this as release-ready online ranking.
