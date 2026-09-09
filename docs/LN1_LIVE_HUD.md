# LN1 live HUD follow-up — 9 September 2026

The captured dashboard was static: the USING icon changed but the bottom weapon inventory and player power spiral did not. Native drawing now selects original recovered graphics using owned inventory entries 11..15 and player_health (0..32).

`tools/export_ln1_live_hud.py` executes supplied RAM routine $65bf for all 32 weapon combinations. The original checks $03f7..$03fb with bit 7 masked; fists do not occupy a slot. It reconstructs the spiral's 33 settled states from $697c/$699c/$69bc, as written by $5586 and erased by $55ad. Offline execution of $5578 matched all 33 reconstructed states. The native display reflects health immediately; the original interrupt-paced animated draining is not reproduced here. Raster palette equivalence and native rendering still require the Windows runner.

All ten structural checks passed after the change. A composite HUD preview was inspected. No GameMaker compilation or GPU test was run here.

Existing ordinary level transitions preserve weapon ownership separately within each game: LN1 carries inventory (including smoke count with its spent flag cleared); LN2 carries common inventory/ammunition and clears level flags 17..25; LN3 carries weapons 0..3 and ammunition 28 but clears level objects 4..22. This does not claim the equipped selection survives or inventory transfers between different games. Native transition checks already cover these rules and await a fresh Windows run.

The shared action modifier is now the dedicated UK Windows # key (OEM keycode 222), freeing J. All three gameplay hints and current control documentation were updated. Keyboard layout behaviour requires user runner testing.
