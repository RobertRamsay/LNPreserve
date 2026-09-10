# Central Park water and juggler fixes

The original approach boundaries now launch the juggler's four knife trajectories. Both sprite-buffer phases for all four projectile kinds were missing from the artwork export; these have been recovered, together with the original juggler colours and three-part poses. Existing projectile movement and damage logic handles the launched knives.

Central Park water boundary modes 11, 16, 30 and 31 now run the original drowning and splash action sequence. Boat-supported landings use the source footprint tables, crossing parity and scene 17 lip adjustment. The island's mode 43 edge uses its original eight-step fixed-depth sink. Drowning blocks movement, fire, weapon/item changes and consumption assists; it completes before one life is deducted and the normal respawn runs.

Changed runtime files:
- scripts/ln2_levels/ln2_levels.gml: knife/water boundary handlers, boat support, drowning loop and focused tests.
- scripts/ln2_play/ln2_play.gml: source data loading, update and rendering integration.
- scripts/ln2_projectiles/ln2_projectiles.gml: the missing knife artwork mappings.
- scripts/ln2_controls/ln2_controls.gml: selection lock during drowning.
- objects/obj_ln_preserve/Create_0.gml and Draw_0.gml: --ln2-water-knife-test.
- LNPreserve.yyp, level1/gameplay.json, three new sprite banks and supporting data/fixtures.

Reproducible source tools: export_ln2_water_art.py, export_ln2_juggler_art.py and export_ln2_water_knife_checks.py. Each accepts --source-root containing source/local/captures. The focused runner includes the new check.

Validation: build passed; all 36 complete-suite groups passed, including save/runtime checks; all 10 focused cases passed. New tests compare 512 boat-support decisions and 160 knife spawns directly with the original 6502 routines. Integration checks cover all four knife triggers, actual shore geometry, all five Central Park water modes, locked input, splash rendering and exactly one life lost on respawn. Structure validation: 9 passed, 1 source-dependent skip. Render captures and machine-readable results are in evidence/ln2_water_knives.

Scope is the reported Central Park encounters. Automated room/component coverage is not a full manual playthrough. Manual playtesting through the juggler and boat jumps remains outstanding. Existing local sprite metadata/project edits were preserved. No commit or push was made.
