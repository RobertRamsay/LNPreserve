# LN2 Office, Mansion and Basement follow-up

Implementation is now present in commit 73264566e (LN2 adjusmtnest). The assistant did not commit or push. Latest test evidence and this report remain local. Existing LN3 backward-roll work preserved.

## Repaired

- Office computer: code uses LN2 keypad glyphs in FOUND, replacing the held-item graphic while viewing the computer. Existing code, known-code flag, save persistence and one-time score protection retained and tested through Mansion to the final safe.
- Office scene 6 pen door and scene 10 fan grate: original successful-interaction bitmap panels recovered. Open state restored on load and revisit.
- Office scene 7 ladders: original facing/weapon prerequisites and ascent/descent action sequences enabled. Scene 11 falls and conveyor exit-lock release enabled.
- Mansion: restored missing boundary fall/trap dispatch, including survivable versus fatal drops, rope prerequisite, and switch-panel open/close graphics. Existing source outgoing-slot order retained.
- Basement: source ladder sequences enabled, scene 9 crate-gap falling and double-fire jump assistance added, final key-card door now changes graphics. Drugged drumstick replaces 46 red pixels with C64 green.
- LN3 backward somersault retains native timing and reverses the component frames together.

## Files

Runtime: scripts/ln2_levels, ln2_items, ln2_play, ln2_status, ln2_object_rules and ln_saves. Recovered action data: datafiles/play/ln2/level4/gameplay.json and level5/gameplay.json. Assets: five spr_ln2_panel_* resources and spr_ln2_drugged_drumstick, registered in LNPreserve.yyp. LN3 backward-roll changes are in ln3_actions, ln3_animation, ln3_input, ln3_movement, ln3_play and ln3_special.

Recovery: tools/recover_ln2_later_panels.py --source-root <original capture directory>. Panel addresses/pixel changes and source hashes are recorded alongside this report. Focused suite now includes --ln2-safe-code-test.

## Validation and limits

GameMaker build succeeds. Targeted runtime checks cover six ladder modes, thirteen later-level fall modes, four persistent open panels, FOUND-area pixels, drugged-item pixels, double-fire versus manual input, and saving during an assisted jump. Office-code tests cover disk saves between levels, correct-code acceptance, the requested 0000 testing alternate, rejection of another code, and prevention of repeat score awards. Original source comparisons are unchanged.

Final result: all 36 full-suite groups passed; all 22 focused cases passed, with the code/HUD case rerun after a test-only capture repair. See runtime_checks.json and focused_checks.json for individual outcomes. Structural checks: nine passed, one optional source-fixture check skipped.

Automated room coverage is not a full manual playthrough. Office/Mansion end-to-end progression, exact visual/timing parity of every trap, and jump-assist feel still require playtesting. In particular, verify Office scenes 6/7/10/11, Basement scene 9 in both directions, and Mansion safe drops/rope use. The Basement electrical trap currently enters the common death flow; its original palette-flash timing has not been reproduced by this change.

