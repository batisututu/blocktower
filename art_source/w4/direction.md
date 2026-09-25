# W4 playable surface direction

User request: implement W4 according to docs/Blocktower_Development_Plan.md. User confirmed **B** during implementation on 2026-09-21. The B×2 warm structural tile panel in docs/디자인시안.png is the visual reference. No concept redesign was requested.

Mode: Operate / game play. Authoritative board, drag preview, pending lines and manual clear outrank score and persistent tower growth. Use warm umber/sandstone, matte beveled structural blocks, clear Korean typography and quiet architecture. Explicit text/outline/cross cues survive color loss. Native Godot Windows is this implementation's review host; Android hardware is W5.

Build: separate playable PuzzleScreen, preserve historical synthetic preview as a review-only scene. All commands go through one GameSession and durable W3 repository. Before commit, no success feedback. Input is serial, cancellable, with modal/failure handling. No gameplay RNG in effects.

Assets: generated architecture plate with exact prompt in background_prompt.txt; original geometric cells drawn by Godot; six project-synthesized WAV effects; original 3D geometry rendered to transparent floor/roof/base modules by render_tower.gd. These are first playable assets, not a claim that W0 detailed Visual Bible fidelity or final Blender source is complete. Camera/anchor/step are reproducible; target intricacy remains a W0 art task.

Review required Windows captures: basic 320×568 and 360×800, cross 412×915, input/valid/invalid/clear/max/tower 360×800, modal/settings 320×568. All use actual GameSession with isolated deterministic disk fixtures. No HTML detector; inspect native code/screenshots. No Android, device audio latency, safe-area or final art acceptance claim.

Quality bar: readable board/controls, no clipped content, correct clear count/reward, accurate saved state, no blocked cancellation or overlapping celebrations. Basic art should carry B's warm architecture rather than old charcoal synthetic preview. Full scene fidelity, detailed final tower ornaments and C are tracked separately, not silently accepted.
