# LN3 ledges and last-life restart

Wind level 2, displayed scenes 1 and 4 (internal rooms 0 and 3), now use the existing Wind fall sequence at four exposed sloped ledges. Their original extents and slopes remain unchanged. These records were solid in the extracted data; changing them to falls is an intentional gameplay adjustment, not a claim of original-game parity. Back boundaries, climb windows and exits are unchanged. Save restoration applies the same adjustment to older saves.

The final death completes its wipe, then fades into the current level artwork. It skips the zero-life/Game Over message and waits for a fresh fire press. The new attempt resets level progress, lives, health and inventory while retaining music and one-hit preferences. Legacy game-over states also return to this splash.

## Changed implementation

- `LNPreserve/scripts/ln3_play/ln3_play.gml`: Wind ledges and fresh same-level restart.
- `LNPreserve/scripts/ln3_special/ln3_special.gml`: final-death routing, message suppression and regression checks.
- `LNPreserve/scripts/ln2_levels/ln2_levels.gml`: shared splash fade and input gating.
- `LNPreserve/scripts/ln_saves/ln_saves.gml`: migrate saved Wind collision records.
- `LNPreserve/scripts/ln3_items/ln3_items.gml`: update final-life test expectation.
- `LNPreserve/objects/obj_ln_preserve/Create_0.gml` and `tools/run_focused_checks.py`: reusable `--ln3-edge-probe` regression entry.

## Validation

- Native build passed.
- All 36 main runtime groups passed, including save serialization and GPU mask checks.
- Edge probe: 110 sampled sloped hazard records across all five levels reached a death transition; zero misses.
- Normal movement reached all four adjusted Wind ledges.
- Last-life checks passed across all five levels, including reset state, held-fire gating and splash save/load.
- Project validation: 10 passed, one skipped for unavailable original local disk input.

Automated hazard sampling is not exhaustive spatial coverage or a full manual playthrough. Wind scene 1/4 ledge feel, climbing routes and the visible fade still need playtesting.

Additional focused LN3 HUD checks passed: 243 prayer-wheel vectors, consumables, reverse rolls, five-level respawn colours and save persistence.
