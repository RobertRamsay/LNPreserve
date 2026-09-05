# LNPreserve

One editable GameMaker project for The Last Ninja, Last Ninja 2 and Last Ninja 3.

The single shared project is [RobertRamsay/LNPreserve](https://github.com/RobertRamsay/LNPreserve), on `main`. Future updates go into this repository and the same `LNPreserve/LNPreserve.yyp`; separately named project downloads are not the current development copy.

**Current build: a native Wastelands gameplay prototype for the first game. The complete trilogy is not playable, and 1:1 system timing has not been verified.**

Open [LNPreserve/LNPreserve.yyp](LNPreserve/LNPreserve.yyp) in GameMaker LTS 2026 and run it. The project now starts in the game view. No C64 emulator runs inside GameMaker.

![Native game view](evidence/lnpreserve-encounter.png)

## Gameplay in this build

- Original assembled player and enemy poses, including walking, jumping and fighting sequences.
- Native player movement, fractional coordinates, room boundaries, enemy decisions and melee hit ranges.
- The Wastelands' 25 decoded rooms, original exit tables and scenery rendered offline by the original drawing routine.
- Seven original collectible placements, pickup checks and weapon selection. Uncollected items flash twice on scene entry using the original colour ramp, including nunchakus.
- The original FOUND label and item icon appear for 150 game ticks after a pickup, then return to USING. Inventory selection updates HOLDING.
- Enemy wounds update the original bar and survive scene changes. Defeated guards remain defeated for the current run.
- Approach either Wastelands Buddha empty handed, facing northwest, to kneel and see the original missing-item hint. S + D finishes prayer with the original stand-up animation.
- River deaths use the original player graphics sinking behind a waterline mask, and respawn without resuming a death frame. The invented ripple has been removed.
- Per-pixel scenery masks that activate at the original room-specific depth thresholds.

This is **not a completed first level**. Projectile behavior, special enemies, some puzzle and interaction events, level completion, remaining dashboard rendering, visual details and precise timing still need work. Some event handlers record unsupported actions rather than inventing their effects. The dashboard combines a captured original frame with live original status labels, icons and enemy wounds; player power/lives still use temporary text. Original recoverable enemy knockouts still need distinguishing from permanent deaths. Enemy random sampling reproduces the original algorithm but its hardware-read phase is not verified. LN1 levels 2–6 and gameplay for LN2/LN3 are not connected.

## Controls

| Key | Action |
| --- | --- |
| WASD | Original joystick directions, including diagonals |
| J | Original fire button; combine with directions for actions |
| Space | Cycle available weapons |
| 1 | Music toggle |
| 2 / 3 | Next / previous available inventory item |
| 4 | Pause |
| Home | Restart this prototype |
| F12 | Optional conversion workbench |

Music assets are still named silent placeholders. Replace the corresponding WAV in GameMaker to supply music. Sound effects are not recovered.

## Verification

Actual compiled GML passes comparisons against offline execution of original machine code:

- 2,856 player updates: movement, boundary collision, action state and requested pose, including 128 kneeling/standing samples.
- 7,680 enemy updates: decisions and animation with the same supplied random-byte returns.
- 6,843 melee hit tests: directional ranges and defensive states.
- 1,024 selection-key transitions and 192 sprite decompressions.
- 1,536 river sinking timer states, including timer wrap and immediate first descent.

A further 660-update integration check crosses the first original exit and runs an enemy encounter. Feedback regressions check pickup expiry across clock wrap, scene-entry flash state, enemy damage/death persistence, armed/unarmed prayer, sinking and stale death frames after respawn. GPU tests check scenery masking, transparent holes and the waterline cutoff. These checks **do not certify full gameplay, complete combat dispatch, sprite composition, hardware random timing or cycle accuracy**. See [evidence/STATUS.json](evidence/STATUS.json) and [docs/ACCURACY.md](docs/ACCURACY.md).

## Assets and rebuilding

The earlier scenery resources and workbench remain available. All six LN1 scenery datasets match supplied disk payloads or captured original memory. LN2/LN3 reference scenery still needs matching to the supplied disk versions. Edit sprites and native GML directly in GameMaker.

The scenery cleanup restores the final pieces of LN2 loader pictures and the mirrored pieces missing from LN3 scenes. The 2,033 scenery image records now share 1,702 unique PNGs; source IDs remain in the manifest and catalog. In total, 345 duplicate sprite resources and 436 empty preview masks were removed. GameMaker's required frame/layer files and native gameplay masks are preserved. See the [before/after images](evidence/asset_cleanup_comparison.png) and [cleanup evidence](evidence/asset_cleanup.json).

The supplied LN1 Wastelands river was inspected through full submersion in VICE. That routine keeps the original player pose and clears sprite rows at the waterline; no separate ripple was observed. The [reference strip](evidence/ln1_original_river.png) and [checkpoint record](evidence/ln1_river_reference.json) use an injected room/position fixture, not a whole-game input replay.

Build with `tools/compile.ps1`; run native checks with `tools/run_checks.py --runner <installed GameMaker Runner.exe>`. `tools/validate_project.py` checks source identities and project resources. Native code is under `LNPreserve/scripts/ln1_*`; decoded gameplay tables are under `LNPreserve/datafiles/play/ln1`.

Extraction tools use original RAM only offline. They do not become part of the game runtime. `export_ln1_world.py` and `export_ln1_play.py` preserve existing sprite edits unless explicitly invoked with `--refresh`. Original disks, emulator tools and captures remain local under ignored directories.
