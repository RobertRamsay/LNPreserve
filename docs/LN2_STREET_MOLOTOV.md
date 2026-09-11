# Street traffic and Molotov

Motorcycles retain the original three trigger lines and light phases. Displayed Street scenes 2, 5 and 9 correspond to source rooms 1, 4 and 8. Rooms 1 and 8 are dangerous with flag 18 clear; room 4 is dangerous with it set. Original action $c8ce enters from the left at (32,128), $c8ec from the right at (216,124), and $c8f8 from the left at (48,132). The original 200-tick light phase remains. The other light panels belong to the same road layout; motorcycles are summoned at the original crossing lines, not on a free-running ambient schedule.

Bike cleanup now clears its X as well as Y, and a new approach starts from a clean position. The previous exit X could push a repeated bike offscreen on its first update. Existing original dispatcher comparisons remain unchanged. Actual walking checks cover all three crossing lines in both light phases, plus a repeated motorcycle approach.

The bottle is plain until combined automatically with available paper. Picking up either ingredient second completes the wick. The Central Park map is consumed as paper (inventory value 128 keeps its pickup removed but skips item selection). Without that map, the fallback newspaper uses the same paper inventory slot. The new persistent molotov record distinguishes map/newspaper paper and whether it is lit; those fields survive level changes and saves. Older saves with the original Sewer lighting flag retain their lit state.

## Newspaper artwork placement

Use **Street Scene 8 (source room 7)**, near the burger, for a discarded newspaper. The pickup rectangle is **X 134–144, Y 100–108**, in the original 240×144 playfield; a visual at about **(138,100)** fits the approach. It uses the floor pickup action and the existing nearby-fire assist. World artwork is intentionally pending Robert's addition; the existing paper/map inventory icon is reused. Do not bake a permanent paper image into the background without a collected variant: availability is inventory[9]==0, and collection sets molotov.newspaper_taken. The pickup is appended at runtime by ln2_molotov_prepare, including on old-save restore.

## Lighting and UI

Hold the prepared bottle and press fire near the original flame in **Sewers Scene 14 (source room 13)**, just before the alligator. A bare bottle is rejected; a paper wick is required. The native pickup/use pose runs and the original lighting flag is set. The HUD switches to a red wick and a three-frame flame taken from the original Sewer torch panel, advancing every six game ticks. Both HOLDING and FOUND bottle icons use the new states. Flaming projectiles use the persistent lit state rather than unrelated per-level flag 19 (such as the Street manhole flag).

spr_ln2_molotov_states frames: 0 plain, 1 white wick, 2–4 red wick with flame. tools/export_ln2_molotov_art.py regenerates these from existing game assets. The bottle's ten white wick pixels are removed only in the plain HUD state; the tiny original scenery bottle panel is retained.

Changed runtime scripts: ln2_items, ln2_levels, ln2_play, ln2_projectiles, ln2_status and ln_saves. LNPreserve.yyp registers the new sprite; evidence/ln2_molotov_art.json records its source pixels. The follow-up native test now covers crafting in both orders, actual newspaper pickup and flame use, HUD animation, save/level persistence, rejection without paper, real crossings and repeated bikes. Existing source comparisons remain separate from the requested paper-crafting design change.

Manual playtesting and the newspaper world artwork remain outstanding. Automated coverage is not a complete manual playthrough.
