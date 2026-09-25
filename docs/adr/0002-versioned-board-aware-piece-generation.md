# ADR-0002: Versioned board-aware piece generation before game integration

- Date: 2026-09-21
- Status: Implemented, tested and self-reviewed by Codex; ready for GameSession contract/integration work.

## Context

The user's new algorithm document requests family weighting, easy-piece repair and bounded board-aware retries before full development. The earlier v0.1 baseline deliberately avoided assistance. Combining these under the same policy would invalidate replay and misrepresent balance.

## Decision

Preserve v0.1 code and evidence. Introduce `bt_catalog_29_v0_2` and three separately identified policies: raw, easy-only and default `bt_soft_one_move_v0_2`. Snapshot and hash configuration before use; reject incompatible checkpoints. Preserve the original 19 variant IDs and append 10 variants.

The default policy explicitly guarantees one witnessed placement at refill, on current occupancy or after simultaneously clearing existing completed lines. It does not guarantee a solution for all three pieces. Initial sampling plus at most three retries is followed by finite enumeration of enabled legal variants. Preserve the easy-family invariant, including when only a non-easy variant fits. No-fit custom configurations return a valid tray with a false guarantee flag; pending clear availability remains a separate decision.

Use pure GDScript with local RNG and row masks, not an external solver or native extension. Definition/config hashes and exact engine version guard replay compatibility. A future GameSession owns serialized actions and atomic persistence of queue, checkpoint and the complete game state. This module has no UI, save or reward side effects.

## Evidence and consequences

- [Contract](../../game/scripts/core/contracts/piece_generation_contract.md)
- [Current design](../Blocktower_Piece_Generation_Algorithm_Design_v0.1.md)
- [Executed tests, simulation and provenance](../implementation/piece_generation/README.md)

The positive-weight single piece makes refill assistance unconditional for valid binary boards under default configuration. This is an explicit product behavior change from v0.1. Final output distribution differs from configured raw weights; balancing and mobile performance require separate evidence. No whole-game correctness or unlimited survival claim follows from these tests.

The Claude Code terminal initially returned a model usage-limit message. The user then explicitly requested skipping Claude's response and direct Codex review. [Codex self-review](../implementation/piece_generation/Codex_Review_2026-09-21.md) is complete with 25 passing tests; no third-party approval is claimed or pending. Existing presentation and historical supply implementations remain unchanged. GameSession integration, persistence and mobile/balance validation are still required.
