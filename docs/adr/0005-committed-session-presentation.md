# ADR-0005: Present committed session state through a cancellable native controller

- Status: Accepted for W4 Windows first-play implementation
- Date: 2026-09-21

## Context

The historical design preview uses synthetic state. W3 supplies a durable GameSession, but pointer gestures and feedback must not create a second rules engine or award rewards before a successful save. Automatic clearing also removes newly placed cells before a screen can reconstruct them from snapshots.

## Decision

AppRoot creates PuzzleScreen attached to its single restored GameSession. PresentationController owns pointer identity, captured revision/batch, modal confirmation and idle/dragging/committing/settling/modal/recovery phases. Preview and PLACE share one core validator. Add pre-removal geometry/styles to CLEARED and placed cells to PLACED; retain the v1 disk schema and generator policy.

Only successful dispatch results trigger success feedback. Cancelled/interrupted effects settle into the latest snapshot; no animation callback dispatches rewards. Conflicting or uncertain commits require reload. A separate validated presentation settings file controls reduced motion, mute, volume and opt-in haptics without changing gameplay state.

Use the user-selected B warm structural direction, original reproducible first art, six bounded audio players and native Godot drawing/Tweens. Exact score integers and delta text avoid interpolating large saved totals. Intermediate tower segments use a flat cornice; only the actual top receives a roof. Keep the historical preview as an explicitly separate scene.

## Consequences and evidence

Windows input, controller, save recovery and rendering are tested in the [W4 report](../implementation/W4_Presentation_Report_2026-09-21.md). This is not final Visual Bible fidelity, Android performance/haptic acceptance, or Phase 2 completion. Detailed art, subjective audio review, full PF coverage and mobile export remain explicit follow-up gates.
