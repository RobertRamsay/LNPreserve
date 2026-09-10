# Central Park scenes 11, 12 and 17

Scene 11 now handles the original fence triggers. Approach facing northwest with no weapon held to climb. The source ascent/descent action sequences, raised walkway depth and missing action roots have been restored. Movement/action/selection inputs cannot interrupt the blocking sequence.

Scene 12 now handles gap modes 14, 15 and 20, including their seven-step fall and source depth masks. Crossing an unmatched edge falls; successfully jumping across both edges remains safe. Adjacent scene 11 ledge modes 7/8 and a failed descent also fall as in the original.

Scene 17 could execute its stop condition before the boat's first action initialized its position, cancelling arrival immediately after a room transition. The stop condition now waits for that action. The staff jab sets the existing flag, which is retained across scenes and saves. Saves with the exact old cancelled-spawn state resume arrival; missing source animation records are added without overwriting saved records or progression.

Changed files:
- LNPreserve/scripts/ln2_levels/ln2_levels.gml: fence and gap handlers, source action sequences, boat initialization guard, regression checks.
- LNPreserve/scripts/ln2_play/ln2_play.gml and ln2_controls/ln2_controls.gml: blocking sequence updates and input lock.
- LNPreserve/scripts/ln_saves/ln_saves.gml: missing-action merge and cancelled-boat save recovery.
- LNPreserve/datafiles/play/ln2/level1/gameplay.json: missing climb roots; fence_gap_checks.json: original trigger fixtures.
- Object Create/Draw events and project registration: --ln2-fence-gap-boat-test.
- tools/export_ln2_fence_gap_checks.py and run_focused_checks.py: reproducible source fixtures and focused runner.

Validation: final build passed; 36 complete-suite groups passed, including save/runtime checks; 11 focused cases passed. The new check compares 336 original 6502 trigger combinations and exercises actual fence geometry, climb/descent, three gap drop modes, safe crossing parity, one-life loss, staff jab, save/load, boat arrival and older-save recovery. Structure validation passed 9 tests with 1 source-dependent skip. Captures and results are in evidence/ln2_fence_gaps_boat.

These automated component/integration checks and room captures are separate from a full manual playthrough. A continuous manual route through the fence, staff gaps, boat jab and final boat jump remains outstanding. Existing local changes were preserved; no commit or push was performed by the assistant.
