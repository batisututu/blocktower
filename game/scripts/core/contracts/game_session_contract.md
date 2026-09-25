# GameSession contract v1 (W2/W3)

Scope: headless game state transitions, minimal growth and a synchronous commit boundary. W3 adds disk persistence through [FileSaveRepository](file_save_contract.md); the in-memory adapter remains available for tests.

## Construction and ownership

`GameSession.start(repository, session_id, seed_text, config=null)` requires an empty repository; creates and commits the initial three-piece supply before returning a session. `resume(repository, config=null)` loads and validates an existing snapshot without drawing supply. Both return `{ok, session | error}`; successful resume also forwards `recovered` and `recovery` from the repository. `validate_snapshot(state, config=null)` exposes the same semantic validator used by resume and the disk codec. The repository must exclusively belong to this session profile.

`snapshot()` returns a deep copy. `view()` derives pending lines, tray status, segment counts and unlocked materials/parts. `dispatch(action)` serializes input, computes a deep candidate, commits it, then replaces memory and returns presentation events. Errors return `{ok:false,error,events:[]}` and never publish rewards. Failure after a commit with uncertain outcome requires resume/reload; do not assume rollback.

## State v1

Exact current fields: `schema_version="bt_session_v2"`, `rule_version="bt_rules_v1"`, `session_id`, `revision`, `last_event_id`, `run_id`, `occupancy`, `cell_style`, `queue`, `batch_id`, `batch_success`, `streak`, `best_streak`, `score`, `best`, `auto_clear`, `growth`, `checkpoint`. `growth.segment_parts` maps canonical completed-segment IDs to sorted unique supported part IDs; empty entries are omitted. Strictly validated v1 states migrate in memory with no parts and no resume write; the next successful action writes v2.

- session_id: nonempty String, at most 128 characters; identifies a persistent event stream across new runs.
- revision and last_event_id: equal, start at 0, increment only on accepted/committed actions. Strict GDScript ints; no float coercion.
- run_id and batch_id: positive monotone integers, start at 1. batch_id increases at refill and new run, never resets.
- occupancy/cell_style: PackedByteArray[64], occupancy 0/1; vacant style must be 0, occupied style 1..13 mapped deterministically from family index + 1. Style is presentation data and never affects placement.
- queue: exactly three String slots; known IDs or empty String for consumed slots. A committed snapshot always has at least one unconsumed slot.
- score/best: nonnegative, best >= score. streak/best_streak likewise. No growth reward is awarded on batch completion.
- auto_clear: bool; a committed automatic-mode board has no pending lines.
- growth: `{total_floors, brick_lines, metal_lines, crystal_lines, representative_segment, segment_styles}`. Counters count removed lines, including before unlock. `0 <= crystal_lines <= metal_lines <= brick_lines <= total_floors`. Representative is 0 with no completed segment, otherwise 1..floor(total/10). Sparse segment_styles maps canonical positive decimal segment IDs to unlocked base material IDs for completed segments only; absent entries mean wood. No array allocation per floor.
- checkpoint: generator's exact versioned String fields, validated against active engine/config. It advances only at initial supply, refill or confirmed new run.
- W2 counter range: 0..9,000,000,000,000,000; reaching the boundary returns INVALID_STATE without committing. W3 encodes counters and RNG int64 values as canonical decimal strings in JSON, not round-trip typed snapshots through JSON directly.

## Actions

Every action has exact fields `type`, `session_id`, `event_id`, plus the fields below. event_id must be last_event_id+1. Past IDs return ALREADY_APPLIED with no events; future gaps return EVENT_OUT_OF_ORDER. No old result cache is promised. Invalid requests do not consume an ID. Different session_id is rejected.

| type | Additional fields | Behavior |
|---|---|---|
| PLACE | batch_id, slot, x, y (ints) | Validate current batch/unconsumed slot/entire shape; place, score cells, detect newly completed lines, optionally clear, settle exhausted batch, refill, determine game over |
| CLEAR | none | Manual mode only; clear every pending row/column union; NO_LINES if zero. Does not change queue, RNG or batch_success |
| SET_AUTO | enabled:bool, confirmed:bool | Manual→auto with pending lines requires confirmed=true; otherwise CONFIRMATION_REQUIRED. Confirmation is tied to current event revision; cancel is no dispatch. Same mode is NO_CHANGE |
| NEW_RUN | seed_text:String, confirmed:bool | Confirm if current run is playable; reset board/score/streak/batch_success, new RNG and supply, increment run/batch; preserve best/best_streak/growth/auto_clear/session_id/event sequence |
| SET_SEGMENT_STYLE | segment:int, material:String | Completed segment only; unlocked base material only. Preserve other overrides. No part/roof editing in W2 |
| SET_SEGMENT_PART | segment:int, part:String, enabled:bool | Completed segment; `brick_arch_window` (10 lines OR 60 floors), `brick_terrace` (30 lines OR 120 floors), `brick_cornice` (60 lines OR 200 floors), and `brick_landmark` (100 lines OR 300 floors) can each be equipped on unlocked brick; all four may coexist. Unequip can clear dormant parts after switching materials. Styling does not touch puzzle/RNG/growth counters. |
| COPY_SEGMENT_APPEARANCE | source:int, target:int, confirmed:bool | Copy one completed source segment's material and visible brick parts atomically to a different completed target after explicit preview/confirmation. Nonbrick sources copy no dormant brick parts; the target's prior part records are replaced. Same appearance is NO_CHANGE. Score, floor and unlock counters, RNG, and representative selection stay unchanged. |
| SET_REPRESENTATIVE | segment:int | Completed segment only; retain selection when future segments complete |

PLACE/CLEAR are rejected after GAME_OVER. Settings and tower selection remain available. Presentation has no reward acknowledgement action.

## W4 read-only presentation API

`piece_for_slot(slot)` returns an owned catalog entry or `{}`. `preview_placement(slot,x,y)` shares the PLACE validator and never commits or advances RNG. `view()` exposes authoritative `clear_lines` and integer `clear_points`. PLACED contains placed cell indices; CLEARED contains rows, columns, sorted unique cells and corresponding styles captured immediately before removal, including newly placed cells in automatic mode. See [presentation contract](presentation_contract.md). These additive transient fields do not change the v1 save schema.

## Rules and commit protocol

Authoritative rules: game design §§5/35 and growth design §§1–5. Placement adds area points; clear N lines adds N × [100,120,140,160 capped at N>=4] points and N floors. Detect full row/column IDs before and after placement, before automatic clear. Only newly full lines set batch_success. Settle streak once at three-slot exhaustion, then refill. Game over ends current streak without settling unfinished batch.

Unlock wood by default; brick by brick_lines>=2 OR total>=30, metal by metal_lines>=3 OR total>=100, crystal by crystal_lines>=4 OR total>=250. Brick parts have progress/total thresholds 10/60,30/120,60/200,100/300 and require unlocked brick. Undefined metal/crystal part thresholds are not invented. Completed segments/partial floors are derived; first completion selects representative 1; new segments implicitly wood.

Repository interface: `load_snapshot()->{ok,found,snapshot?}` and `commit(candidate,expected_revision)->{ok,error?}`. Initial expected_revision=-1 requires no existing snapshot. The adapter must commit the whole state or return a definite failure; competing writers return SAVE_CONFLICT. An ambiguous commit response is a distinct COMMIT_UNCERTAIN error requiring recovery. GameSession holds a busy gate through commit to reject reentrant dispatch with BUSY. Memory adapter supports failure before commit and uncertainty after commit for tests. The W3 disk adapter implements this port; see [file encoding, recovery and platform limits](file_save_contract.md). RECOVERY_REQUIRED also freezes dispatch until resume.
