# ADR-0007: Application lifecycle input boundary

Date: 2026-09-21. Status: implemented; physical-device validation held by user.

## Problem

W4 stopped drag/clear feedback on focus loss, but did not prevent actions while the app was suspended. A pressed button, stale confirmation or preference callback could outlive the interruption. Focus and pause notifications can overlap; receiving one resume notification must not reopen input while another blocker remains.

## Decision

Godot exposes mobile pause/resume notifications separately from desktop/mobile application focus notifications. We therefore model both conditions rather than assuming a single callback pair. Reference: [Godot Node lifecycle notifications](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-constant-notification-application-resumed).

AppRoot owns independent focus/pause blockers and forwards the resulting active state to PuzzleScreen. Repeated notifications are idempotent. Screens created during an inactive period inherit that state. PresentationController gates drag, modal submission and all action dispatch with `application_active`, separate from its existing phase, so recovery remains mandatory.

Suspension cancels transient presentation and audio, invalidates control callbacks and drops pointer ownership. Resume rebuilds controls from the authoritative in-memory committed snapshot without a save, RNG transition or historical feedback replay. Puzzle/tower location remains. Old controls fail generation/visibility checks, and background controls cannot execute through an open modal. A second finger during a drag is consumed before Godot GUI dispatch.

Root startup recovery/failure notices are recreated on resume. Their callbacks require both an active app and the current notice identity. Commit uncertainty still requires the existing explicit save reload; resume does not bypass it. The save schema and Android kernel lock protocol are unchanged.

## Validation and limits

Tests cover notification order/duplicates, stale button and preference callbacks, drag cancellation, clear-tail interruption, mandatory recovery, failed startup retry and repeated resume with unchanged full session state. Windows native probes exercise real Godot mouse/touch event dispatch and file-backed sessions at 360×800 and 320×568. These simulate lifecycle notifications and do not establish Android OS notification ordering, physical touch feel, audio/haptic behavior or mobile performance. See the [W5 lifecycle report](../implementation/W5_Lifecycle_Input_2026-09-21.md) and [presentation contract](../../game/scripts/core/contracts/presentation_contract.md).
