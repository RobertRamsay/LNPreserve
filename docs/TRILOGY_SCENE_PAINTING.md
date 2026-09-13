# Scene painting: all three games

LN1: 134 room records, LN2: 93, LN3: 66, using original offline drawing routines.
These counts include room records outside the normal progression route; automated
asset coverage is separate from a complete manual playthrough.

Every entry first displays the original room background across the 240x144 game
bitmap. Native patch playback follows, then the current renderer resumes with
the actual saved puzzle, inventory, scenery, enemies and HUD state. Gameplay is
held during painting; history recording resumes afterwards. F11 pauses playback.
Game, level, room and entry epoch identify each painting, preventing cross-game
cache collisions. Surfaces are recoverable from recorded patches after GPU loss.

F11: shared Scene Painting speed, 0.1x–4x, reset 1x. The existing [ScenePainting]
speed INI preference applies to all games. Loaders, LN3 intro/outro and LN2 ending
presentations are excluded. LN1 behavior and its recorded assets are retained.

1x is the original drawing code's PAL CPU-cycle baseline (985248 Hz), not a
verified C64 wall-clock recording: display contention and interrupts remain
uncalibrated. The initial screen clear is immediate. Existing edits and dynamic
puzzle graphics appear on handover; painting assets represent source room builds.

Regeneration: tools/export_ln23_painting.py --ln2-captures <folder>
--ln3-common <original-64K-RAM> --ln3-levels <original-Integrator-PRG-folder>.
Original RAM/PRGs stay outside the game. Evidence: evidence/ln23_painting.json.
Native --ln1-paint-test now also exercises all twelve LN2/LN3 levels, checking
source background pixels, final GPU pixels, surface recovery, room completion
and presentation exclusions. Marker: LN_PAINT_TRILOGY_PASS.
