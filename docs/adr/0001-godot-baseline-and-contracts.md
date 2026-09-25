# ADR-0001: Godot baseline and contracts mapping

- Date: 2026-09-20
- Status: Adopted working baseline. W1 tooling implemented on 2026-09-21; W2 contracts pending.

## Context

The project has a GDScript design and preflight evidence from Godot 4.7.2 with GUT 9.7.1. Shared C:/DEV conventions assume TypeScript contracts and verification. The tested executable resides in a temporary directory, and the production project does not yet exist.

## Decision

Use Godot 4.7.2 with GDScript and start with the Compatibility renderer as an experiment. Pin GUT v9.7.1 to `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`. Reuse built-in UI/audio before adding optional dependencies.

Map the shared contracts-first requirement to `game/scripts/core/contracts/` and verify using Godot import/headless execution plus applicable GUT tests. Do not add TypeScript or duplicate `src/types/` solely to satisfy a language-specific convention. See [project rules](../../CLAUDE.md).

During W1, prepare and verify an engine copy at a durable explicit path and record that new location separately. Preserve original preflight provenance and reference files. During the first mobile build, match export templates to the engine and record device/toolchain evidence.

## Consequences and evidence

Preflight results establish a usable rules-test baseline. They do not establish full GameSession correctness, atomic persistence, Android/iOS compatibility, rendering performance, or enjoyable balance. Engine/addon upgrades and reference-code adaptations require relevant reruns.

- [Preflight report](../Blocktower_Preflight_Test_Report_2026-09-20.md)
- [Engine provenance](../pretests/results/engine_provenance_2026-09-20.json)
- [GUT execution evidence](../pretests/results/gut_compatibility_2026-09-20.json)
- [Readiness plan](../Blocktower_Development_Plan.md)

Implementation note, 2026-09-21: the engine now runs from `C:/DEV/tools/godot/4.7.2/`; Git, the `game/` project, pinned GUT and reproducible import/test commands exist. [W0/W1 execution evidence](../implementation/W0_W1_Report_2026-09-21.md) supersedes the historical environment description above. Export templates and mobile validation remain pending.
