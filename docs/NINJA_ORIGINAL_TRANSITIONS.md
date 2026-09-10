# Original LN1/LN2 death transitions

## Findings in supplied original bytes

LN1 does have text rendering. Routine $790a banks in the C64 character ROM ($d800 glyph pointers) and enlarges the letters into the bitmap. Strings include GAME OVER, THE QUEST / CONTINUES, PRESS FIRE and the copyright line. This is not a separately drawn custom alphabet. No new LN1 lives lettering has been added; a replacement font can still be supplied later.

LN1 death routine $7875 calls $7db3, then $7d0e, clears the bitmap and deducts a life. The first pass makes 4,865 random two-row multicolour pixel clears using masks $3f/$cf/$f3/$fc. The second follows the exact 16-colour darkening table at $6fe1, for 15 rounds with the original six-frame wait. The source then restores the entrance and redraws the scene; it does not reverse the random dissolve.

LN2 $9239 calls $93af before clearing the bitmap and decrementing lives. The sprite setup recovers a red curtain with vertical stripes and a shaped yellow/grey lower edge, not an alpha fade or random dissolve. Raster routine $1d13 repeats five horizontally expanded sprites across the bitmap. $0232 advances from 29 toward 189 in two-line steps; $8fa4 retracts it in two-line steps. The patterns are at $3fb0/$3fb3, copied into sprite slots $30/$31.

## Native implementation

LN1 now uses the recovered pixel mask sequence, followed by a palette substitution shader with the original darkening table. It resumes at the entrance after the fade. LN2 replaces the alpha fade with the recovered descending/retracting curtain, retaining the lives message in the centre of the 240x144 gameplay bitmap. Both effects exclude the surrounding status panels and outer debug HUD.

The mask order is recovered offline with deterministic CIA timer samples; it is not the random sequence of every possible C64 run. The pixel pass is presented over 40 native ticks; the palette phase takes 90 ticks. LN2 uses 80 ticks in each direction and retains the existing 75-tick message hold. Sprite geometry and colours are source-derived; VIC raster timing/DMA and complete original-machine frame parity are not claimed.

New assets: spr_ln1_death_dissolve, spr_ln2_death_wipe, sh_ln1_palette_fade. Runtime changes: ln1_play and ln2_levels. Tests: ln1_feedback_checks, obj_ln_preserve transition hooks and tools/run_focused_checks.py. Reproduction: tools/export_ninja_transitions.py accepts an unpacked LN1 common-code capture and LN2 gameplay capture. Source hashes are recorded in evidence/ninja_transition_source.json; raw captures remain private/untracked.

The complete suite passed all 36 groups (126.53 seconds), including save/runtime checks. All 15 focused checks passed. Additional rendering checks exercise save restoration across successive Draw frames. LN1 drawing now explicitly restores its view/projection matrices after rendering to the bitmap surface, fixing a blank/mispositioned display after a save recreates that surface. Manual playtesting of pacing remains necessary; automated room coverage is not a full manual playthrough.


