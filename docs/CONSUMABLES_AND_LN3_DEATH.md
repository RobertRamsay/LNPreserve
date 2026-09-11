# Deferred consumables and LN3 death transition

LN1 apple and LN3 potion are now inventory items. Pickup alone gives no health or life reward. Select the item (F3/F5 or controller bumpers), release fire, and press fire twice within 18 PAL ticks (0.36 seconds), without a direction. Consumption grants one life and restores health; the existing spiral animates toward full. Holding fire does not count twice. A consumed marker removes the item from selection and prevents repeat collection in the current level. Unused items carry through saves and ordinary level changes. LN1 no longer automatically spends its apple on the final death or cashes it in at a level exit.

LN3 fire-only pickup assistance chooses the nearest point inside an original item rectangle within 18 source pixels. It probes the path using original collision/hazard handling, respects item prerequisites, and starts the original crouch. The source reaching frame performs collection. An active enemy within 20 pixels keeps fire as combat. Weapon changes, climbing, death and input locks block assistance. Existing manual pickup controls remain available.

Ordinary LN3 deaths now use the recovered eight sword parts: nine three-tick sprite-fade steps, downward sword/wipe, the remaining-lives message for 50 PAL ticks, and upward sword. The life is charged once when the wipe finishes. Resumption restores source actor colours and the current room entry. Zero lives shows GAME OVER and completes the transition without respawning. The existing Void special transition and ending remain separate.

Source: original captured LN3 routines $7035-$71e8, text renderer $6da2/$6de9 and font $dd7a. The ordinary sword positions and fade table match the previously recovered Void transition assets. `tools/export_ln3_lives.py` extracts the original message glyphs, including their source colours. The displayed count is centered in the 240x144 bitmap only and supports the actual count beyond the original five-life display cap.

Regression checks cover deferred pickup, distinct/held fire presses, one-time rewards, unused inventory/save persistence, actual assisted crouch through runtime ticks, distance/enemy/wall guards, all-five-level respawn colours, final-life transition, and save/resume during the sword sequence. Original LN3 item comparison vectors still exercise the original routine default; the runtime explicitly opts into deferred potion rewards.

Automated checks and rendered captures are not a full manual playthrough. Playtest feel and each original room approach remain manual verification.

## Changed files and validation

- `scripts/ln1_items/ln1_items.gml`: banked apple and double-fire consumption.
- `scripts/ln1_levels/ln1_levels.gml`, `scripts/ln1_play/ln1_play.gml`: carry unused apple and remove automatic reward paths; integrate input.
- `scripts/ln1_level_checks/ln1_level_checks.gml`: updated intended behaviour and apple save checks.
- `scripts/ln3_items/ln3_items.gml`: deferred runtime potion, guarded nearby pickup, consumption and integration checks.
- `scripts/ln3_play/ln3_play.gml`: inventory carry, assisted input and ordinary death entry.
- `scripts/ln3_special/ln3_special.gml`: original sword/lives flow, source-font drawing, five-level colour regression.
- `sprites/spr_ln3_lives_font/`, `LNPreserve.yyp`, `tools/export_ln3_lives.py`: source glyphs and reproducible extraction.
- Evidence: `runtime_checks.json` (36 passed), `focused_checks.json` (21 passed), `ln1_runtime_checks.json` (14 passed).

GameMaker compilation passed. Full suite passed before the final held-fire edge guard; all 21 focused checks and the independent 14-group LN1 suite were rerun after that final change and passed. Structural validation: 9 passed, 1 skipped because optional original disk fixtures are unavailable. Source comparison vectors remain intact. Rendered lives-message capture inspected. No manual full-game playthrough was performed. No commit or push made.
