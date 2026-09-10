> Transition presentation updated: see [Original transitions](NINJA_ORIGINAL_TRANSITIONS.md) for the source-derived curtain replacing the initial alpha fade.

# LN2 falls, lives message and nearby pickup

Fatal falling, sinking and water paths now reach the original directional death poses before respawn. Water keeps its source splash sequence. The body remains visible as health drains. Nonfatal drops that travel to another room retain that behaviour.

After the death hold, fade the C64 game area and built-in HUD out over 20 ticks, deduct one life, display the original yellow message font for 75 ticks, reload the entrance and fade in over 20 ticks. The font is recovered by executing the original $1583 text printer with the lives message attributes. The alpha-fade timing is a native presentation choice, not a cycle-exact recreation of the C64 raster transition. Saves retain transition phase/count and do not deduct another life on restore.

Fire alone within 20 source pixels of an available pickup rectangle aligns the ninja and starts the original pickup chain. Original object events select the appropriate height/pose and prerequisites. A living active enemy within 20 pixels leaves fire available for combat. Climbing, locked actions, deaths, keypad and ending sequences do not start assisted pickups. Keyboard and controller share this input path.

Changed implementation: scripts/ln2_levels, ln2_play and ln2_controls; obj_ln_preserve test hooks; spr_ln2_message_font and project registration. Added tools/export_ln2_message_font.py and --ln2-lives-pickup-test in tools/run_focused_checks.py.

Validation: compiled successfully; all 36 complete-suite groups and all 14 focused checks pass. Complete suite took 128.17 seconds, including save serialization and runtime checks, with no failed or unreached groups. New checks cover fatal falls in Park/Mansion, transition phases, save/restore, last-life game over, a source pickup in each of seven levels, and the 20/21-pixel enemy boundary. Existing checks retain original comparisons for water, gaps, fence, boat, controls and saves. Project validation: nine pass, one source-dependent skip.

Manual follow-up: playtest fall cutover/fade pacing and the pickup reach around crowded or overlapping objects. Automated room coverage is separate from a complete manual playthrough. LN1 and LN3 life transitions remain future work.


