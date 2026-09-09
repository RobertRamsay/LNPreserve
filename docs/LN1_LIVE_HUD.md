# LN1 live HUD follow-up — 9 September 2026

The captured dashboard was static: the USING icon changed but the bottom weapon inventory and player power spiral did not. Native drawing now selects original recovered graphics using owned inventory entries 11..15 and player_health (0..32).

`tools/export_ln1_live_hud.py` executes supplied RAM routine $65bf for all 32 weapon combinations. The original checks $03f7..$03fb with bit 7 masked; fists do not occupy a slot. It reconstructs the spiral's 33 settled states from $697c/$699c/$69bc, as written by $5586 and erased by $55ad. Offline execution of $5578 matched all 33 reconstructed states. The native display now walks one recovered spiral cell every two PAL ticks towards live health; exact interrupt phase is not reproduced. Raster palette equivalence and native rendering still require the Windows runner.

All ten structural checks passed after the change. A composite HUD preview was inspected. No GameMaker compilation or GPU test was run here.

Existing ordinary level transitions preserve weapon ownership separately within each game: LN1 carries inventory (including smoke count with its spent flag cleared); LN2 carries common inventory/ammunition and clears level flags 17..25; LN3 carries weapons 0..3 and ammunition 28 but clears level objects 4..22. This does not claim the equipped selection survives or inventory transfers between different games. Native transition checks already cover these rules and await a fresh Windows run.

The shared action modifier is now the dedicated UK Windows # key (OEM keycode 222), freeing J. All three gameplay hints and current control documentation were updated. Keyboard layout behaviour requires user runner testing.

## Requested apple enhancement

LN1 apples now award one life immediately and restore health to 32; the spiral animates back up. This immediate life/healing rule is a user-requested deviation from the original deferred extra-life conversion. Inventory marker 128 prevents repeat pickup and excludes the apple from later death/level-exit credit and item selection. Normal level exit clears the marker for the next level. Added native checks cover pickup, repeat contact and level-exit double credit; these await the Windows runner.

## Wilderness climbing crash

The $aa1e climb root was absent from level 2's exported action graph. Recovered both original Wilderness climb roots ($aa1e/$aa4d) and their reachable records from the supplied disk bank: five missing records, with all required actor frames already present. Existing overlapping records matched byte-derived fields. The exporter now explicitly seeds both roots, and the structural gate requires them. This fixes the missing-record cause of the reported flags exception; actual climbing movement still needs Windows testing.
