# LN2 nearby held-item interactions and Sewer grate

Sewers scene 5 now displays the original open-grate panel after successful tool use. The panel at $a74d is rendered by $73f2 and changes 132 pixels. It is selected from persistent inventory flag 20 on use, revisit and save restoration. The original handler's required item ID 12 is retained; Streets manhole retains item ID 11. No new item substitution or sewer-door puzzle behaviour was introduced.

Pressing fire alone within 20 source pixels of a supported mechanism starts the existing interaction animation when its required item is selected and available. Mechanisms take priority over nearby loose pickups when the held tool matches. Directional fire remains manual; living enemies within 20 pixels retain combat priority. Busy animations and blocked sequences retain their existing input locks. Consumed items cannot qualify.

Supported tool uses: Park passage key; Streets manhole tool; Sewer grate tool and bottle use; three Basement tool mechanisms, including the loaded-tool prerequisite; final-room orb return after defeating the Shogun. Candle assistance keeps its existing double-fire control. Eligibility inspection is read-only: original interaction handlers still perform the action and enforce completion prerequisites.

Changed runtime files: ln2_items, ln2_levels and ln_saves. Added spr_ln2_sewer_grate_states, source-recovery tool export_ln2_sewer_grate.py and evidence/ln2_sewer_grate.json. The object test entry point and focused runner include --ln2-item-use-test.

Verification: build passed; all 17 focused checks passed. New checks cover all eight eligibility mappings, wrong/unavailable tools, prerequisites, manual/combat priority, actual grate-use animation with an in-progress save, all 132 changed source pixels, open-state saves/revisit and the existing descent. Project validation: nine passed, one source-dependent skip.

Complete suite: all 36 groups passed in 126.05 seconds, including save serialization and runtime checks. No failed or unreached groups.

Automated component/room coverage is separate from a full manual playthrough. Manual follow-up: approach the grate and other held-tool mechanisms during normal play.
