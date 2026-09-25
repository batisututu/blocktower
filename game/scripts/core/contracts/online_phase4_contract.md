# Phase 4 online challenge contract (working MVP)

## Ownership

- `GameSession` remains the only reducer of puzzle, growth, and tower state. Existing `user://save_v1` data belongs to the personal offline game.
- `ChallengeRepository` owns a separate, two-generation action trace under `user://phase4_challenges/<challenge_id>`. A successful challenge commit writes the next action and its revision together. Replay reconstructs the challenge snapshot. The server never accepts the local snapshot as a score.
- The server owns UTC week assignment, a random seed and one challenge per guest account per week. Its private SQLite file owns account token hashes, challenges, and verified submissions. The client stores the guest bearer token in its private application data.
- A challenge also owns immutable `rule_version` and `supply_profile`. The server stores them with the issued seed and selects the matching frozen replay project. Existing database rows migrate to `bt_rules_v1` and `classic`; challenges in weeks beginning 2026-09-28 UTC use `reduced_single`. The client accepts only the rule version it implements, treating a missing version in a legacy local fixture as v1, and replays its local action journal with the issued profile. Neither field can be changed for an issued challenge.
- The server replays every submitted action through the pinned Godot `GameSession`; it publishes only the resulting floor count and representative segment. Other clients receive read-only derived tower data.

## Action and response rules

- The challenge starts at revision 0 from the server's decimal `seed` and `session_id == challenge_id`. Challenge actions use the existing `GameSession` action schema. All integer fields are decimal strings on the wire, because Godot JSON parsing does not preserve integer types. `NEW_RUN` is rejected for challenges.
- The complete ordered trace is submitted. A repeated identical trace is idempotent. A later submission must extend the previously accepted trace exactly; shortening or branching returns `TRACE_NOT_EXTENSION`. The server checks every action, event ID, state transition, and final revision.
- An invalid action returns an error without changing the leaderboard. Local challenge progress remains available for correction or continuation. Failed local trace writes leave the previous valid generation available.
- Offline personal actions never enter the public ranking. Offline challenge actions may be queued locally, but the complete trace must arrive before the challenge week's Monday 00:00 UTC boundary. There is no late submission window in this MVP.

## Identity, conflict, and visibility

- The guest token identifies one online account. An authenticated account may issue a 128-bit recovery code; only its hash is stored by the server and issuing a new code invalidates the old code. The code is shown once for the player to keep outside the app. Recovery rotates the bearer token, invalidating the previous device's token, while the recovery code remains usable if a response is lost. The client accepts recovery when it has no token or the server rejects its stored token; it does not replace a still-valid account. A lost token without a saved recovery code cannot be recovered.
- An authenticated challenge response includes its already accepted action trace. On challenge open, the client replays and commits that trace only when its local trace is an exact prefix. If the local trace is longer, it keeps the local suffix for submission. Divergent traces return `TRACE_NOT_EXTENSION` without replacing either journal. The player may explicitly choose the server's accepted trace; before replacement the client copies both local journal generations to a distinct private conflict archive. A failed archive leaves the current journal untouched. The personal save and personal tower never synchronize across devices.
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
| `RECOVERY_CODE_INVALID` | server | Unknown or malformed recovery code; do not disclose whether an account exists. |
| `VERIFIER_UNAVAILABLE` | server | The pinned engine cannot run; do not trust a client floor count as fallback. |
| `UNSUPPORTED_VERSION` | client | The issued challenge uses rules this app cannot replay; leave its journal untouched. |
| `RATE_LIMITED` | server | Per-client request budget is exhausted. HTTP 429 includes `Retry-After` in seconds; no request action is applied. The client may retry later. |
| `VERIFIER_BUSY` | server | Replay worker slots are occupied. HTTP 503 includes `Retry-After`; no submission is accepted. |

The server limits requests per normalized client IP in 60-second windows and caps concurrent replay processes. A public TLS reverse proxy must overwrite one `X-Real-IP` header and the loopback server must explicitly opt in to trusting it; without that opt-in, only the socket peer is used. Limits are per process and reset on restart. The server exposes loopback liveness/readiness endpoints and emits one sanitized JSON access event per handled GET/POST response, without bodies, credentials, query strings, or raw client IPs.

The server must run the same pinned engine, rules, generator catalog, and assets for every live challenge. It selects one of two pinned weight profiles per challenge. The v1 verifier project is a frozen source bundle with a SHA-256 file manifest; startup verifies its files and refuses to serve a database containing an unconfigured rule version. A future rules release must add its own frozen project, register it, and retain every version used by an open challenge. The Godot executable remains an operator-pinned deployment artifact and must be retained with those projects until their submission windows close.
