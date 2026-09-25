# Blocktower product context

<!-- impeccable:product-schema 1 -->

## Platform

android

Android portrait is the current experiment assumption, pending the user's device preference. Desktop Godot is the initial design-review host. This does not decide release platform order.

## Stack

The existing approved project direction is Godot 4.7.2, GDScript, native 2D puzzle rendering and a modular 2.5D tower. No web framework is needed.

## Users

Players who place blocks and choose when to clear completed lines. Target demographics, typical session length and device minimums remain open in the development plan.

## Product Purpose

An 8×8 placement puzzle permanently grows a tower that players can customize. Manual clear timing, optional automatic clear, and persistent architectural growth form the main loop.

## Brand Commitments

The user's [Visual Bible image](docs/디자인시안.png) is the visual authority: architectural material detail, beveled blocks, textured HUD, architectural scenery and dimensional tower modules. The existing flat W0 preview was rejected as a faithful rendition and must not set the target palette or art quality. The first A1/B2/C3 combination is awaiting preference; B2 is a working proposal consistent with the earlier default-B direction, not a recorded user selection. Map the image's variant names to the earlier B/C policy explicitly; preserve identical gameplay and rewards across cosmetics. See the [design guide](docs/Blocktower_Design_Asset_Guide.md), section 11.

## Capabilities and Constraints

Rules, scope and future features are authoritative in [docs/README.md](docs/README.md). W1 tooling exists; W0 reference fidelity is unfinished. Mobbin and asset-library research informs production requirements, not a finished art claim. The existing scene previews illustrative states and must not write player progress.

## Accessibility & Inclusion

State information must survive grayscale, muted audio and reduced motion. Use Korean-capable licensed fonts, readable text, explicit pending-line counts, and separate drop/clear input areas. Actual device accessibility and safe-area verification remain W5 work.

## Evidence on Hand

The user Visual Bible, older B/C comparison, consolidated specifications and Godot 4.7.2 test evidence exist. The Visual Bible's local PNG matches the user's attachment at the RGBA pixel level. Mobbin/Godot research is recorded, but reference-faithful replacement art, target-device UX, final game balance and production saves remain unverified or unimplemented.
