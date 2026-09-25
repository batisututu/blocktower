# Phase 4 online challenge contract (working MVP)

## Ownership

- `GameSession` remains the only reducer of puzzle, growth, and tower state. Existing `user://save_v1` data belongs to the personal offline game.
- `ChallengeRepository` owns a separate, two-generation action trace under `user://phase4_challenges/<challenge_id>`. A successful challenge commit writes the next action and its revision together. Replay reconstructs the challenge snapshot. The server never accepts the local snapshot as a score.
- The server owns UTC week assignment, a random seed and one challenge per guest account per week. Its private SQLite file owns account token hashes, challenges, and verified submissions. The client stores the guest bearer token in its private application data.
- The server replays every submitted action through the pinned Godot `GameSession`; it publishes only the resulting floor count and representative segment. Other clients receive read-only derived tower data.

## Action and response rules

- The challenge starts at revision 0 from the server's decimal `seed` and `session_id == challenge_id`. Challenge actions use the existing `GameSession` action schema. All integer fields are decimal strings on the wire, because Godot JSON parsing does not preserve integer types. `NEW_RUN` is rejected for challenges.
- The complete ordered trace is submitted. A repeated identical trace is idempotent. A later submission must extend the previously accepted trace exactly; shortening or branching returns `TRACE_NOT_EXTENSION`. The server checks every action, event ID, state transition, and final revision.
- An invalid action returns an error without changing the leaderboard. Local challenge progress remains available for correction or continuation. Failed local trace writes leave the previous valid generation available.
- Offline personal actions never enter the public ranking. Offline challenge actions may be queued locally, but the complete trace must arrive before the challenge week's Monday 00:00 UTC boundary. There is no late submission window in this MVP.

## Identity, conflict, and visibility

- The guest token identifies one online account. The MVP does not recover the token after app deletion, merge personal saves, or synchronize the personal tower across devices. Copying a token to another device is outside the supported UI; if it happens, both devices still submit to one server challenge and the strict trace-prefix rule prevents summing divergent histories.
- Rank is descending verified floors, then the first server verification time at which that floor count was reached, then account ID. No ranking reward, prize, or paid entitlement depends on it. A correction can change a public rank; no reward clawback is required in this MVP.
- A public entry contains a random alias, verified floor count, and a representative 10-floor style derived from the replayed state. It contains no raw action trace, seed, account token, personal save, or free-form profile text.
- The server's receipt time cannot prove when an offline move was performed. The fixed challenge week and hard submission cutoff prevent a prior week's trace from being assigned to a later week, while in-week replay is still a competition prototype rather than a bot-proof tournament.

## Errors and invariants

| Error | Owner | Meaning |
|---|---|---|
| `ACCOUNT_REQUIRED`, `UNAUTHORIZED` | client/server | Guest token missing or invalid; do not reassign an old challenge automatically. |
| `CHALLENGE_NOT_FOUND`, `CHALLENGE_CLOSED` | server | Wrong account/challenge or UTC cutoff passed. Personal progress is unaffected. |
| `INVALID_ACTION`, reducer error, `REVISION_MISMATCH` | verifier | Trace is not a valid deterministic GameSession history. No public score changes. |
| `TRACE_NOT_EXTENSION` | server | Another device/history already committed a different prefix. Manual merge is unsupported. |
| `TRACE_CORRUPT`, `SAVE_FAILED` | client repository | A local generation is damaged or could not be committed. Never clear the personal save. |
| `VERIFIER_UNAVAILABLE` | server | The pinned engine cannot run; do not trust a client floor count as fallback. |

The server must run the same pinned engine, rules, generator catalog, and assets for every live challenge. Deployments that change deterministic rules need a versioned verifier retained through the current week; the MVP server is not yet set up for rolling verifier versions.
