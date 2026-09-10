# LN2 reported encounter fixes

Central Park scene 15 now executes the original event 16 bee handler: three independently jittering sprite parts, pursuit and contact damage. Scene 14, 16 and 17 boats use their original scene-specific VIC shared colours (10/9, 10/8 and 8/10).

The status renderer now selects original icons by level. Streets weapon IDs no longer display Central Park artwork in either the collected-item notice or selected-weapon panel. Existing transparent HUD padding and the dedicated final orb icon remain intact.

Changed runtime files: scripts/ln2_levels, ln2_combat, ln2_play, ln2_status. The object Create/Draw events add a focused regression switch; the project registers nine sprite banks and the swarm fixture. tools/export_ln2_reported_art.py and export_ln2_swarm_checks.py reproduce the recovery with --source-root pointing to a directory containing source/local/captures. tools/run_focused_checks.py includes --ln2-reported-encounters-test.

Validation: build passed; 256 native bee cases match execution of the original 6502 routine, including rejected random steps, byte boundaries and contact damage. Native room renders are in evidence/ln2_reported_encounters. The complete existing suite passed all 36 groups, including save/runtime checks. Structure validation passed 9 tests with 1 source-dependent skip. Only capture positioning changed after that full-suite run; the rebuilt focused test passed again.

Automated checks and room captures are not a full manual playthrough. Controller playtesting through the boat jumps and bee encounter remains to be done. Existing user changes in the project and ln_checks.yy were preserved. No commit or push was made.
