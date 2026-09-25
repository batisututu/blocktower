# FileSaveRepository v1 (W3)

## API and ownership

`FileSaveRepository.open(directory="user://save_v1", config=null)` returns `{ok,repository | error}`. Absolute test paths are allowed; resource/relative/filesystem-root paths are rejected. Repository methods implement the GameSession port. `load_snapshot()` additionally returns `recovered`, `recovery` and `ignored_pending`; `GameSession.resume()` forwards recovery metadata. The same frozen generator configuration validates both generations before selection. Public `GameSession.validate_snapshot(state,config)` is the single semantic validator.

All operations are synchronous on the main thread. Windows acquires an atomic directory claim `.writer_<PID>.lock`; System32/tasklist.exe CSV output checks unrelated processes. Concurrent claims may both back off, but cannot both access the save. Godot is_process_running only knows its own children and is not a liveness oracle here.

Android (W5) acquires an exclusive, nonblocking Java FileChannel.tryLock on the stable `.writer.guard` inode through JavaClassWrapper. The OS releases it when the process dies; the guard file is never deleted. A canonical-path reservation prevents another repository in the same process from opening/closing a second channel and invalidating the first POSIX lock. Contention returns SAVE_BUSY; bridge/lock/close errors fail closed. No age/timeout forcibly steals a lock.

Under this guard Android also checks legacy `.writer_<PID>.lock` directories. android.system.Os.kill(pid, 0) succeeds for a live process; ESRCH alone permits removing an empty dead-owner claim, EPERM means live/inaccessible, and other errors return SAVE_PROCESS_CHECK_FAILED. Invalid names or nonempty claims are preserved and block writes. PID reuse can conservatively return SAVE_BUSY. Upgrade assumes the old app process has stopped (Android package replacement); simultaneous old/new protocol writers are unsupported. Unknown-platform foreign claims still fail closed. This is a cooperative local-filesystem protocol, not a lock against arbitrary external editors or a network-filesystem guarantee.

## Disk encoding

Files: `slot_a.json`, `slot_b.json`, `pending.json`, `preserved/` for damaged committed originals. No save is stored in the source tree by default.

Canonical UTF-8 JSON envelope: `{format:"bt_save_envelope_v1",payload:<canonical JSON String>,checksum:<lowercase SHA-256 of payload UTF-8>}`. Exact fields only. The payload uses the v1 GameSession fields; all growing integer counters are canonical signed decimal strings, occupancy/cell_style are exactly 128 lowercase hex characters, checkpoint integers remain strings. Queue, bools and IDs retain their JSON types. Decode checks bytes, size, envelope/hash, exact fields, canonical encoding, counter ranges, then complete GameSession semantics. No Variant/object/resource deserialization. Maximum envelope: 2 MiB. Unsupported versions/configurations are not corrupt-data fallback candidates. This is checksum-based corruption detection, not authentication.

## Read/recovery

Read both committed slots under the claim. Any unsupported format/schema/rules/checkpoint blocks writes even if the other slot is supported. Access/read errors block rather than treating data as absent. Select the greatest valid revision. Different session IDs or differing states at equal revision are SAVE_DIVERGED. Invalid JSON/hash/types/state in one slot permits fallback to the other with explicit `recovered=true`, selected revision and damaged filenames. Both invalid yields SAVE_CORRUPT; never initialize over them. `pending.json` is uncommitted and ignored. Only pending/no committed slots means no completed initial save, not a rewarded game to resume.

## Commit and interruption points

Under a claim, rescan and require expected revision and session identity. Candidate revision must be expected+1 (initial expected=-1, revision=0). Validate/encode before touching committed state.

1. Write pending, flush, close; check errors.
2. Reopen and verify checksum, full semantics and exact encoded contents.
3. If the target slot is damaged, copy its original bytes to a content-addressed preserved file and verify the copy before proceeding. Preserve failure aborts.
4. Remove only the inactive target slot if present; latest good slot remains intact.
5. Rename pending to target in the same directory: publication point.
6. Read published target and verify; then acknowledge and release the claim.

Before publication, failure is definite and the latest valid state remains. After publication, verification/acknowledgement failure returns COMMIT_UNCERTAIN; GameSession freezes until resume. A failed initial commit exposes no session. No reward is published before commit acknowledgement. A stale/corrupt changed head cannot be overwritten by an old session: revision conflict and recovery-required results force reload.

Normal operation retains at most two committed generations and one pending file. Corruption originals are preserved, deduplicated by hash, not auto-purged. Recovery can lose the latest damaged action(s); report the chosen revision. Do not promise zero rollback after corruption.

## Evidence limits

Tests must include separate Godot process launches and forcibly terminated writers before/after publication, plus codec precision, corrupt latest/both, unsupported versions, backup preservation, stale writers and read-only path failures. Android tests must use an isolated QA package and the production repository/codec, exercise actual JNI and force-stop/relaunch at all six checkpoints. FileAccess flush and same-directory rename do not establish directory-fsync/hardware power-loss durability, iOS or network-drive semantics. There is no fictitious v0 migration; preserve actual v1 fixtures for future migrations.
