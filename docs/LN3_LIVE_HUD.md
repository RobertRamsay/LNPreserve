# LN3 live status panel

All five native LN3 levels now use a 320 x 200 game picture: the 240 x 144 playfield plus the original right and bottom status areas, displayed at 3x inside the existing window. The surrounding save/debug controls remain outside CRT coverage.

The panel shows six score digits, animated player/enemy health spirals (0–44), the Bushido dragon (0–40), selected objects, timed pickup notices, weapon-change notices, the nine-stage prayer wheel, and the original portrait eye flashes. Consumed/unowned objects clear from the selected-item area. Existing gameplay inventory, score and honour logic remain authoritative. Save restoration retains the displayed meters and wheel progress; older saves inherit the new presentation fields from the constructor.

## Source recovery

Original bitmap and drawing routines were recovered offline from the DMAgic C64 disk edition linked at https://www.c64games.de/phpseiten/spieledetail.php?filnummer=809. The common panel and 25 icon records are extracted from the Earth bank and used by the five-level runtime. No emulator runs inside GameMaker. This is not a certification of identical UI data in every disk edition.

`tools/export_ln3_hud.py` reads ignored source captures `source/local/captures/ln3-hud-ram.bin` and `ln3-hud-io.bin`, and creates editable sprite frames. It requires Pillow and py65. Source hashes and resource dimensions are in `evidence/ln3_hud_art.json`.

Original routines: score $6eb6; selected/notice icon $6faf and label $7019; prayer wheel $6ae3/$6b19/$6bc1/$6c0f; health $79f9/$7a48; Bushido $7a98; portrait flash $7b2a. Colour RAM is modelled separately from RAM beneath I/O during extraction.

## Checks

`--ln3-hud-test` independently exercises 243 original wheel-state comparisons, live meter updates, actual item-handler pickups from each level, selected/consumed item display, weapon notices, portrait flashing and saves. It captures `ln3-hud-level1.png` through `ln3-hud-level5.png` in GameMaker's local save directory. The test is included in `tools/run_focused_checks.py`.

The existing original gameplay comparisons remain unchanged. Automated coverage and these controlled captures are separate from a full manual playthrough. Remaining manual checks: play each level normally, inspect wheel reveals approaching/leaving objects and enemies, check CRT at the chosen window scale, and observe the panel during boss/death transitions.
