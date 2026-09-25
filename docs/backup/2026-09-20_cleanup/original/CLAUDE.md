# Blocktower project rules

These project-specific mappings adapt `C:/DEV/CLAUDE.md` to the existing Godot design and the user's Korean planning workflow.

## Sources and language

- Read [GAME-DESIGN.md](GAME-DESIGN.md), [docs/README.md](docs/README.md), and the current readiness plan before implementation.
- Preserve Korean game planning documents and discuss changes with the user in Korean. Use English for repository conventions, ADRs, identifiers, and commit messages. Keep code comments in Korean.
- Use the established terms: `GameSession`, `SaveRepository`, `occupancy`, `cell_style`, `queue`, `batch_id`, `batch_success`, `streak`, and versioned supply IDs. Define new terms in contracts first.

## Godot mapping of shared conventions

- Runtime language is GDScript. TypeScript syntax, `tsc --noEmit`, and JavaScript naming conventions do not apply to GDScript files. Use Godot naming conventions and explicit types where practical.
- The shared `src/types/` contracts responsibility maps to `game/scripts/core/contracts/`. This is a planned location, not a claim that code exists. Do not create duplicate TypeScript contracts.
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

The 2026-09-20 readiness review updates documentation only. The next implementation task is W1 in readiness v0.2: repository setup, stable engine path, minimal Godot project, and reproducible tests. No production project or mobile build is claimed to exist.
