# ADR-0008: Server-replayed weekly challenge

Status: working MVP decision, 2026-09-25.

The local permanent tower is not an authenticated history. Phase 4 uses a separate weekly challenge issued by the server. The server stores a random seed and binds it to a guest account and a UTC Monday-to-Monday week. The client records successful `GameSession` actions in a separate two-generation journal and may submit the entire trace before the week closes. The server runs the same pinned Godot reducer from the issued seed, then derives the floor count and representative tower style from the result. A device-provided snapshot or floor count is never accepted as evidence.

An identical retry is idempotent. Updated traces must extend the previous accepted prefix; divergent device histories require a manual choice in a later product iteration. Guest tokens have no recovery or cloud-save promise. The server binds to loopback for local development; remote exposure requires TLS, rate controls, monitoring, backup, and retained verifier binaries before launch. Automated play detection and cross-device personal save synchronization are outside this prototype.

This decision implements the scoped D09/D10 rules recorded in [the online contract](../../game/scripts/core/contracts/online_phase4_contract.md). It does not close the release policy or the full Phase 4 acceptance gate.
