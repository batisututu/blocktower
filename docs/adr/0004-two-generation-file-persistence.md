# ADR-0004: Two-generation file persistence

- Date: 2026-09-21
- Status: Implemented and tested on Windows; mobile crash recovery remains pending.

## Decision

Implement the GameSession repository port with two alternating committed files and one uncommitted pending file. Encode the entire snapshot as canonical JSON with SHA-256; encode growing counters and RNG integers as decimal strings and packed cell arrays as hex. Reuse the session's semantic validator. Reject unknown versions instead of silently replacing them.

Write, flush, close and verify pending before touching the inactive slot. Preserve damaged originals before replacing them. Rename pending into the inactive slot, verify publication, then acknowledge. The previous valid slot remains throughout this operation. Ambiguous acknowledgements freeze the session until reload. Load the highest valid revision; reject divergent identities or equal-revision states. Corruption recovery reports possible rollback. Two corrupt slots never authorize initialization.

Use atomic per-PID directory claims for cooperative local writers. On the pinned Windows engine, Godot's process-running API only tracks its own children. Use the Windows tasklist CSV process list for foreign claims; inconclusive checks fail closed. Mobile needs a platform liveness adapter. PID reuse may conservatively block access. This is not an external-editor or network-filesystem lock.

The application entry scene restores or creates the session once through SavedGame, with explicit recovery and retry notices. The existing design preview remains a separate child scene; real gameplay controls must connect to GameSession in W4.

## Evidence and consequences

[W3 report](../implementation/W3_File_Save_Report_2026-09-21.md): 58 tests, 2,495 assertions, and 26 cross-process checks, including six forced writer terminations. Keep actual v1 save fixtures for future migrations; there is no invented legacy migration.

These checks establish tested Windows process-interruption behavior, not hardware power-loss durability, directory fsync or mobile behavior. Each accepted action commits synchronously; measure latency on target devices before introducing a serialized asynchronous adapter. Normal storage is bounded to two committed files plus pending; damaged originals are content-addressed and deliberately not auto-purged.
