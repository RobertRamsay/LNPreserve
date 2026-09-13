# LN1 scene painting prototype

All 134 rooms across the six LN1 levels replay the original bitmap construction,
then return to the current room renderer and its live objects, actors and edits.
Gameplay waits during painting. The built-in HUD remains visible and the usual
CRT applies to the completed composition. Painting is presentation state only:
it is excluded from rewind history and saved games. Room entry/respawn starts a
new painting; other games release it. F11 pauses painting while the menu is open.

F11 has a speed slider, 0.1x–4x, plus a reset to 1x. Speed is remembered in
LNPreserve.ini under [ScenePainting], key speed. Default: 1x.

## Timing qualification

1x is a provisional original-code PAL baseline, not measured C64 wall-clock parity.
The offline 6502 executes $5dfe after the room clear/setup at $5452, sampling bitmap
and attribute changes every 19656 instruction cycles. Recorded timestamps are
played at 985248 cycles/second. The room clear is instantaneous; display contention,
interrupt work and source screen-blanking timing are not reproduced or verified.
The game contains patch data, not an emulator. A VICE/hardware recording is still
needed to calibrate the default against the original visible painting duration.

## Verification

evidence/ln1_painting.json records all 134 final-image comparisons against a fresh
execution of the original renderer. They pass; this is automated bitmap coverage,
not a manual playthrough or original timing verification.
Runner flag --ln1-paint-test checks native GPU pixels, 2x timing, finish/resource
cleanup, room re-entry and switching games. Test output: LN_PAINT_PASS.

Regenerate using tools/export_ln1_painting.py --common <unpacked-64K-RAM>
--levels <Integrator-LN1-PRG-folder>. Original captures and PRGs are private local
references and are not included in the game project.

The first displayed frame is the original room background colour. Painting is synchronised before room drawing and cannot advance until this blank frame is presented.
