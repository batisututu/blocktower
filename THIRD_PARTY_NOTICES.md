# Third-party notices

This file records third-party software used by the Blocktower project, its license, the exact version/commit, and where the license text lives. Entries are added at first adoption. Asset production details are in the [design/asset guide](docs/Blocktower_Design_Asset_Guide.md).

| Component | Version / pin | License | License text | Use |
|---|---|---|---|---|
| Godot Engine | 4.7.2.stable.official.ed1daf0bf (official Windows x86_64 build) | MIT (engine); bundled third-party components under their own permissive licenses | Engine About dialog and `COPYRIGHT.txt`/`LICENSE.txt` in the official source tree; MIT text below | Runtime engine and editor. Binary is kept outside the repository (see `tools/engine_provenance.json`). |
| GUT (Godot Unit Test) | v9.7.1, commit `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605` | MIT | `game/addons/gut/LICENSE.md` | Development-time tests. Export exclusion must be configured in W5; no export preset exists yet. |
| Noto Sans KR | Google Fonts commit `b38c5c93af322c45f633e17ac440ec1e6c94d489` | SIL OFL 1.1 | [OFL.txt](game/assets/fonts/OFL.txt) | Korean, Latin and numeral UI; original variable TTF, historical preview weights 400/650; W4 playable weights 500/700 selected at runtime. [Source and hashes](art_source/font_provenance.json). |

## Godot Engine

Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Distribution note: shipped builds must reproduce the Godot license text and the licenses of the engine's bundled third-party components (available at runtime through `Engine.get_license_text()` and `Engine.get_copyright_info()`). Wire this into an in-game credits/licenses screen before any public release.

## GUT (Godot Unit Test)

The MIT License (MIT)

Copyright (c) 2018 Tom "Butch" Wesley

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Notes: `game/addons/gut/fonts/` contains editor-panel fonts shipped with GUT (Anonymous Pro, Courier Prime, Lobster Two; SIL Open Font License, see the `.txt` files in that folder). They are development-only and must be excluded from export presets together with the rest of `addons/gut/`. The pinned source manifest hash of `addons/gut` is verified by `tools/test.ps1` against `tools/engine_provenance.json`.

## W4 project-created assets

The architecture background was produced using the built-in image generation tool, with the user-supplied Visual Bible as a direction reference. Its exact prompt is preserved in `art_source/w4/background_prompt.txt` and PNG metadata. The four transparent tower modules are rendered from original project geometry in `art_source/w4/render_tower.gd`; no third-party mesh or texture was imported. Six WAV cues are synthesized by `art_source/w4/build_audio.py`, with original synthesis parameters. These are project-created assets, not third-party CC0 packages; no third-party license is invented. See `art_source/w4/manifest.json` and `game/assets/audio/manifest.json` for exact files/hashes. User-provided reference art remains reference material and its ownership is not asserted here.

### Detailed B refinement

The playable scene now uses `game/assets/visual_bible/`. Original code-authored geometric SVG materials/icons are generated by `art_source/visual_bible/build_surfaces.py`. A replacement architecture plate was produced with the built-in image generation tool using the exact prompt in `art_source/visual_bible/background_prompt.txt`. Nine original Godot 3D modules/scenes, including leaf geometry and a mesh-UV roof material, are generated by `art_source/visual_bible/render_tower.gd`. These introduce no third-party model or texture pack. Source/output hashes and exact image dimensions are in `art_source/visual_bible/manifest.json`; PNGs preserve provenance metadata. The earlier W4 source set is retained as implementation history.

### Board-first game feel (2026-09-21)

Five additional original synthesized cues (button, snap, clear, air, chime) are generated by `art_source/gamefeel/build_audio.py`; exact PCM format, duration and hashes are in `game/assets/audio/gamefeel/manifest.json`. Native geometric clear effects are authored in `game/scripts/presentation/board_effects.gd`. Research informed the implementation; no competitor code, Kenney package or Juicee addon is included. Existing B art provenance is unchanged.
