# Blocktower

The Phase 3 building MVP includes a condensed whole-tower view, an enlarged ten-floor view, and atomic single-target appearance copying between completed segments. It preserves the `bt_session_v2` save schema and bounds the overview diagram to 64 bands regardless of tower height. The pinned Godot 4.7.2 suite passes 138 tests / 3,709 assertions; 46 separate-process save checks and 13 Windows native screens / 120 checks pass. Version 8 was installed and exercised on a Samsung Android 13 device with 30/300/3,000-floor fixtures, copy/restart checks, and short frame and memory measurements. Minimum supported hardware and first-play human observation remain open. See the [Phase 3 device record](docs/implementation/Phase3_Android_Device_Validation_2026-09-25.md).

Phase 2-H adds direct segment-number navigation in the tower screen, including the final incomplete segment. Navigation changes presentation state only; it does not write saves or change the representative segment. The pinned Godot 4.7.2 headless import completed without parser errors. See the [Phase 2-H record](docs/implementation/Phase2H_Tower_Segment_Jump_2026-09-25.md); interaction and device checks remain open.

Phase 2-G now adds an equipable brick clock landmark to the existing four materials and three brick parts. It uses the current `bt_session_v2` save contract and has separate ordinary and arch-window floor art. The recorded pinned Godot 4.7.2/GUT 9.7.1 run passed 133 tests / 3,600 assertions; Windows save-process checks, native captures, compact scrolling and eight facade seams passed. See the [Phase 2-G record](docs/implementation/Phase2G_Brick_Landmark_Part_Plan_2026-09-25.md). Human observation and Android validation of this source remain pending.

Phase 2-D adds the first equipable tower part, a brick arch window, with `bt_session_v2` saving and read-only migration of valid v1 saves. The pinned Godot 4.7.2/GUT 9.7.1 suite passes 125 tests / 3,419 assertions; Sol independently reran the suite, 29 process save checks, Windows captures and the new plus prior facade seams. See the [Phase 2-D record](docs/implementation/Phase2D_Brick_Arch_Part_Plan_2026-09-24.md). Other parts, human observation and Android validation of this source remain pending.

Phase 2-C added the fourth basic facade, crystal, and displayed previously saved crystal segments with their own art. Its historical pinned result was 119 tests / 3,342 assertions; Sol verified 11 Windows presentation cases and six crystal seam orientations. See the [Phase 2-C record](docs/implementation/Phase2C_Crystal_Facade_Plan_2026-09-24.md).

W6-A desktop first-play preparation is ready: [`tools/start_desktop_playtest.ps1`](tools/start_desktop_playtest.ps1) opens the real Windows game with a fixed seed and a fresh, isolated save for each Manual or Auto condition. The paired probe, live GUI smoke, and independent pinned suite pass (102 tests / 3,124 assertions). Human first-play observations and Android validation of the latest source remain pending. See the [W6-A record](docs/implementation/W6A_Desktop_Playtest_Readiness_2026-09-23.md).

Latest source adds large-text and grayscale state cues plus bounded combined reward notices to `0.1.0-gamefeel7`; the pinned Godot 4.7.2 suite passes 102 tests / 3,124 assertions. Windows native event captures and Sol's independent regression pass. These source changes have not been built or installed on Android. See the [W4-E verification](docs/implementation/W4E_Event_Clarity_Plan_2026-09-23.md), [readability verification](docs/implementation/W4D_Readability_Plan_2026-09-23.md), and [game-feel report](docs/implementation/BlockBlast_Feel_Refinement_2026-09-23.md). Older W5 status statements below are historical.

Native Godot block puzzle. W5 now combines Android interrupted-save recovery with background/resume input protection. Current checks: 93 unit tests, 37 Windows native input checks and 26 process persistence checks. Version5 ARM64 app/QA builds are prepared; installation and physical-device validation are held at the user’s request. See the [lifecycle and combined validation report](docs/implementation/W5_Lifecycle_Input_2026-09-21.md).

## Run locally

Use PowerShell 7 from the repository root. Configure the official pinned Windows engine outside the repository by copying `tools/engine.local.example.json` to `tools/engine.local.json` and updating its two executable paths. This workspace uses `C:/DEV/tools/godot/4.7.2/`. Alternatively pass `-GodotExe` or set `BLOCKTOWER_GODOT`.

```powershell
pwsh -NoProfile -File tools/test.ps1
pwsh -NoProfile -File tools/run.ps1
pwsh -NoProfile -File tools/run.ps1 -Editor
```

For a fresh desktop observation session, use a new absolute save path under `tools/out/desktop_playtests` each time:

```powershell
pwsh -NoProfile -File tools/start_desktop_playtest.ps1 -Seed 20260923 -SaveDirectory C:\DEV\Games\Blocktower\tools\out\desktop_playtests\manual_20260923
pwsh -NoProfile -File tools/start_desktop_playtest.ps1 -Seed 20260923 -Condition Auto -SaveDirectory C:\DEV\Games\Blocktower\tools\out\desktop_playtests\auto_20260923
```

The test command checks the exact engine version, binary hash and vendored GUT source manifest, imports the project, runs GUT, and rejects engine errors, empty test discovery, failures and pending tests. Logs and JUnit XML are written under ignored `tools/out/`.

Startup stores the complete session in `user://save_v1` using two alternating generations. A corrupt latest generation falls back with a notice; two corrupt generations block initialization. Windows restart/forced-termination checks can be rerun with `python tools/verify_save_restart.py --godot C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64.exe`. W5 implements Android kernel file locking and legacy dead-writer recovery: 84 unit tests, 26 Windows process checks and 44 Android16 emulator checks pass. Physical-device recovery validation is pending after USB disconnection; hardware power-loss durability is not established. See the [W5 save recovery report](docs/implementation/W5_Android_Save_Recovery_2026-09-21.md).

Drag a tray piece onto the board. Completed lines remain until you press Clear in manual mode; switching to automatic mode asks for confirmation when lines are pending. Settings control sound, motion and new game. The tower shows cumulative growth and representative segments. Escape cancels a drag/dialog or returns from the tower; mandatory save recovery requires reload.

## Reproduce design artifacts

Use `python tools/verify_presentation.py` for isolated actual-session native captures and input checks; use `--cases tower:360x800,tower_top:360x800` for tower boundary views. Outputs use a fresh profile folder each run. The commands below reproduce the historical synthetic W0 preview only.

```powershell
python art_source/build_vector_assets.py
pwsh -NoProfile -File tools/capture_design.ps1
```

Captures require a desktop rendering session and briefly open native windows. They cover 320×568, 360×800 and 412×915 logical sizes; they are not Android device verification. Original vectors and their manifest live in `art_source/` and `game/assets/vector/`. Font source and license are recorded in [third-party notices](THIRD_PARTY_NOTICES.md).

Read the [current Korean document index](docs/README.md), [W0/W1 evidence](docs/implementation/W0_W1_Report_2026-09-21.md), and [project rules](CLAUDE.md). Detailed B art and scoped Windows review are recorded in the [visual fidelity report](docs/implementation/Visual_Fidelity_Report_2026-09-21.md) and [side-by-side comparison](docs/implementation/fidelity_evidence_2026-09-21/comparison.html), following the [visual target](art_source/visual_target.json) and [Mobbin/Godot research](docs/design/Reference_Research_2026-09-21.md). W3 now restores the session at application startup; see the [save/restart evidence](docs/implementation/W3_File_Save_Report_2026-09-21.md). See the [W4 implementation and evidence](docs/implementation/W4_Presentation_Report_2026-09-21.md) for real input, first 2.5D wood modules, six original sound effects, settings and current limitations. Next complete remaining W4-D experience checks and W5 Android export, mobile persistence and physical-device verification.

Use `python tools/verify_visual_fidelity.py` for the 19-state B visual matrix. Editable sources and reproduction commands: [art source](art_source/visual_bible/README.md).

Android device interim check: [SM-N981N / Android 13 report](docs/implementation/W5_Device_Interim_Report_2026-09-21.md) documents APK installation, real Android input, save restoration and the system-back fix. Historical version2 regression suite: 75 tests / 2,602 assertions. Latest version3: 82 tests / 2,843 assertions; current physical-device installation and26smoke checks pass (see the follow-up report). Use the Android Device Debug export preset; Android stale-writer recovery is now implemented; physical-device recovery and broader device/performance verification remain pending.

Latest preview: [board-first screen](docs/implementation/gamefeel_evidence_2026-09-21/basic_360x800.png). Installable ARM64 output: `game/export/blocktower-device-debug.apk` (`com.blocktower.game`, `0.1.0-w5-lifecycle5`; installation held by user). `Android Emulator Debug` is a separate x86_64 QA package; the current emulator has a documented GLES/SwiftShader rendering failure.

Version3 physical follow-up: [SM-N981N installation,26checks and native recording](docs/implementation/GameFeel_Device_Verification_2026-09-21.md). User progress preserved; controlled play tests used an isolated QA package that was removed afterward.


Latest W5 physical-device update (2026-09-23): The user explicitly resumed installation and combined device validation. Version6 is installed on SM-N981N (Android13), preserving the original complete session and preferences. The 44 physical-device save recovery checks pass. A real OS notification propagation bug blanked the startup recovery notice in version5; deferred notice replacement with immediate stale-control invalidation fixes it. Post-fix checks: 95 tests / 3,027 assertions and 22 Windows lifecycle input checks. See [combined device report](docs/implementation/W5_Device_Combined_Verification_2026-09-23.md) for the final physical input matrix and remaining performance/experience limits. This supersedes the September21 installation hold and implementation-status statements, while preserving historical evidence.

Phase 2-E development (2026-09-24): [Brick terrace implementation and independent verification](docs/implementation/Phase2E_Brick_Terrace_Part_Plan_2026-09-24.md) added a second equipable brick decoration that can coexist with arch windows. The pinned suite passed 127 tests / 3,453 assertions; Windows save-process, native screen and facade seam checks also passed.

Phase 2-F development (2026-09-24): [Brick cornice implementation and independent verification](docs/implementation/Phase2F_Brick_Cornice_Part_Plan_2026-09-24.md) added decorated horizontal and gold-flag roof caps as a third independent brick part. Its pinned suite passed 130 tests / 3,510 assertions; Sol also verified 37 save-process checks, 11 native captures with 203 checks, and 22 new/legacy seam orientations. Human observation and current-source Android validation are deferred.

Phase 4 local MVP work (2026-09-25): [Online implementation record](docs/implementation/Phase4_Online_MVP_2026-09-25.md) adds a server-replayed weekly challenge, guest account, verified leaderboard, and read-only representative tower viewing. [Local server and Android QA validation](docs/implementation/Phase4_Local_E2E_Validation_2026-09-25.md) passed; the personal offline save remained separate. Public deployment and release operations remain open.

Current puzzle refinement: [single-piece supply and tray background](docs/implementation/Piece_Tray_Refinement_2026-09-25.md). New personal saves use a lower single-piece weight, issued weekly challenges pin their supply profile, and the waiting-piece tray panel is hidden. The new profile and Android version 10 have not yet been run on a device.
