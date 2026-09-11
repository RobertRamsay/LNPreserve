# LN2 loader and Sewer follow-up

Every LN2 level has a selectable Scene 0 title screen. Fire (# or Xbox A), after release, enters the first gameplay scene. Selecting Scene 1 or another gameplay scene directly bypasses the title for testing. Normal level progression and quick start show the title automatically. The displayed scene labels now match the selector; original source room IDs and saved entrances remain unchanged.

All seven original loader pictures and level-specific music slots are wired. Basement's loader remains a one-second placeholder, which Robert will replace later. The existing Basement gameplay recording is also a placeholder. Gameplay is frozen during the title; dismissing fire cannot carry through into an attack. Saves taken at a title return there and require a fresh fire press.

Sewers source room 10 (now displayed as Scene 11) keeps both false-door sensors but moves their blocking/damage line inside the opening. Inward contact drains the original two health points per contact; stepping back is permitted. Other source routes and false doors remain unchanged.

Sewers source room 14 (now displayed as Scene 15) has its alligator event 12 restored from captured routine $9083. This changes the alligator action pointer, not the ninja weapon. Source actions include the walking, lunge and death continuation. The complete original compositions 105–127, mirrored both ways, use a 256-pixel canvas to avoid clipping. Reproduce art and 440 source comparisons with tools/export_ln2_alligator.py --source-root <capture-root>; private captures are not copied into the project.

The --ln2-followup-test native check compares all 440 original continuation cases, repeated walking/lunge activity, visible sprite pixels, recessed contact, all seven Scene 0 entries, direct gameplay selection, fire gating and save restoration. Existing original-Sewer checks still require actual walking into every false doorway to cause death without teleporting.

Manual playtesting remains required: approach and back out of both recessed doors, bait the alligator, check its masking and attack timing, and hear each level's loader/game music change. Automated room coverage is separate from a full manual playthrough.

## Changed files

- scripts/ln2_levels, ln2_player, ln2_combat and ln2_play: recessed sensors, alligator continuation/rendering, loaders and display labels.
- scripts/ln_scene_test, ln_input, ln2_controls and ln_saves: Scene 0 selection, quick start, frozen controls and title saves/music.
- objects/obj_ln_preserve/Create_0.gml and Draw_0.gml: loader input gating and native follow-up test entry.
- LNPreserve.yyp, datafiles/play/ln2/level3/gameplay.json, sprites/spr_ln2_sewer_alligator, datafiles/verification/ln2_alligator_checks.json: registered original actions, full art and source comparisons.
- tools/export_ln2_alligator.py and tools/run_focused_checks.py: reproducible export and focused check registration.
- evidence/ln2_alligator.json, focused_checks.json, runtime_checks.json and the Sewer/follow-up docs: provenance and verification results.

## Verification

Build succeeds. The complete 36-group native suite passed, including saves/runtime, before the final isolated direct-title-bypass music fix. All 20 focused checks are rerun on the final build and include that music fix. Structural validation passed nine checks; one original-disk-dependent check was skipped. The 440 continuation comparisons execute against original captured 6502 code. No full manual playthrough has been performed, and audio listening/attack feel remain for playtesting. Changes remain local and uncommitted.
