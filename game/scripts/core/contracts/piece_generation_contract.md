# Piece generation contract v0.2

Scope: isolated, deterministic, finite 8×8 / three-slot supply module. No UI, saves, scores, cosmetics, network or global RNG. Existing `piece_supply.gd` v0.1 stays unchanged.

## API

- `PieceGenerator.create(config = null) -> {ok, generator | error}` validates and snapshots a `PieceGeneratorConfig` Resource. Default: 29 fixed variants / 13 families, soft policy. Published definition/config hashes identify exact ordered data and policy parameters.
- `generator.initial_checkpoint(seed_text) -> {ok, checkpoint | error}` accepts canonical signed decimal int64 strings only. Checkpoint fields: rng_seed, rng_state, engine_version, catalog_version, supply_policy_version, definition_hash, config_hash.
- `generator.generate(occupancy, remaining_ids, checkpoint) -> {ok, piece_ids, checkpoint, decision, guarantee_met, metrics | error}`. Occupancy must be PackedByteArray of exactly 64 values 0/1; remaining_ids must be an Array of known String IDs and must be empty. Nonempty trays cannot be rerolled. Invalid input produces no random draw or caller-state change.
- `generator.analyze_tray(occupancy, remaining_ids) -> {ok, status, witness, pending_rows, pending_columns, post_clear}`. Status: REFILL_REQUIRED, CAN_PLACE, MUST_CLEAR, GAME_OVER. All IDs are validated before early success. MUST_CLEAR means an existing legal clear action remains, even if a placement witness is unavailable after clearing.
- `generator.catalog()` and `generator.config_snapshot()` return defensive copies.

## Selection

Policy IDs: `bt_family_weighted_v0_2` (raw control), `bt_easy_family_v0_2` (easy only), `bt_soft_one_move_v0_2` (default). Weighted integer ticket selects family; one uniform variant draw follows even for a singleton. Duplicates allowed. Zero weights disable sampling and fallback.

Easy/soft: if the raw tray lacks an easy family, choose a replacement slot uniformly, then an enabled easy family by its configured weights and a variant uniformly. Soft: accept if any tray piece fits current occupancy or occupancy after simultaneously clearing the union of all currently full rows/columns. Initial candidate plus at most `max_rerolls` additional candidates (0–3).

After exhaustion, enumerate legal variants of enabled easy families on both boards. Select family with its original weight, then uniformly among that family's legal variants; do not weight by placement count. If no easy variant fits, enumerate all enabled families and preserve an existing easy piece in a different slot. If no enabled variant fits, return a valid three-piece tray with `guarantee_met=false`; this is not an input error. Report clear availability separately from game over. No unbounded retries/search, no speculative placement/clear during generation.

## Guarantees and limits

All successful valid calls return exactly three known IDs. Easy policies include at least one enabled easy family. Soft policy supplies a witnessed placement on current/post-clear board whenever any enabled catalog piece fits either. Default positive-weight single implies this condition for every valid occupancy (a full board has pending lines and clears). This deliberately prevents immediate dead supply at refill, not mid-tray failure, a solution for all three pieces, a future clear, permanent survival or fair/enjoyable balance.

Same engine + exact config/catalog hashes + checkpoint + occupancy produce the same result. Seed alone does not determine board-aware output. Returned checkpoint and queue must later be committed atomically by GameSession/SaveRepository. A failed save retries with the old checkpoint; mode/skin changes do not call generate. Cross-engine RNG identity and tamper-proof checkpoint authenticity are not guaranteed.
