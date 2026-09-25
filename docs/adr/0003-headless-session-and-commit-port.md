# ADR-0003: Headless GameSession and synchronous commit port

- Date: 2026-09-21
- Status: W2 implemented and tested. Durable W3 persistence remains pending.

## Decision

Connect the v0.2 generator to a headless GameSession that owns a validated snapshot and serializes actions. Define the [State/Action/Result contract](../../game/scripts/core/contracts/game_session_contract.md) before implementation. Calculate a complete candidate, commit it, replace memory and only then return presentation events.

Use a synchronous repository port with optimistic revision checks. Supply an explicitly non-durable memory adapter for W2 integration tests. Definite commit failure leaves the prior memory and repository state intact. An uncertain outcome or a competing writer freezes dispatch until the caller resumes from the repository. Do not treat an uncertain acknowledgement as a rollback.

Keep session_id stable across new runs; increment run_id and batch_id. Require consecutive event IDs and reject past IDs without re-awarding or pretending to cache old results. Snapshot counters are strict GDScript integers bounded below int64 overflow; W3 will explicitly encode counters/RNG strings and validate decoded state.

Persist growth counters and sparse completed-segment material overrides. Derive unlocks and segment counts. This avoids allocating one object for every floor, preserves edited sections across new growth and keeps unspecified metal/crystal parts outside the implementation.

## Evidence and limits

[W2 execution report](../implementation/W2_GameSession_Report_2026-09-21.md): 45 total tests, including 20 new session tests, 200 replayed actions and 40 in-memory session resumes. Generator code/configuration are unchanged from the prior review.

No actual file durability, process restart, corruption recovery, mobile compatibility, UI input or art fidelity is established by the memory adapter. The next step is W3 durable SaveRepository and its interruption/serialization fixtures, followed by playable presentation integration.
