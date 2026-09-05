# Accuracy and the native design

The target is editable GameMaker gameplay verified against the original C64 programs. The current build does **not** satisfy that target yet.

## Evidence levels

1. **Source identity:** SHA-256 hashes identify the ZIP, disk, extracted file and captured memory region. Equal bytes establish provenance, not correct rendering.
2. **Data decoding:** Original compressed sprite bytes are decoded independently and compared with execution of the recovered 6502 decompressor.
3. **Isolated native routine:** Actual GML is compiled and run. Its output is checked against original-code vectors. Intercepted calls and excluded timing are stated explicitly.
4. **System behaviour:** Same input events, initial state, machine model and observation cycles must produce matching gameplay state. **Not implemented or passed.**
5. **Whole-game acceptance:** Transitions, puzzles, combat, deaths and endings across every level and relevant branch must pass reference replays. **Not implemented or passed.**

The project must not be described as cycle accurate on the strength of levels 1–3.

## Timing

The native clock accumulates integer microseconds against 985,248 PAL cycles per second, with 63 cycles × 312 lines = 19,656 cycles per video frame. It retains fractional credit and host-stall debt. GameMaker's host refresh rate does not set the preservation clock.

LN1 now schedules its main gameplay ticks at the recovered CIA1 timer period of 18,433 cycles (latch $4800). This is distinct from the 19,656-cycle video frame. The precise phase of input reads, rendering and random sampling is not recovered. Original logic may poll inputs or update state between video boundaries. CIA timers, IRQ/NMI entry, raster waits, branch/page costs, self-modifying code, sprite DMA and bad-line bus stalls still require analysis. Counting one update per PAL frame is not a substitute for that work.

`ln1_unpack_sprite` is a direct native implementation of the original sprite decompressor. Its returned instruction-cycle count includes branches and indexed page crossings. All 192 source entries pass against py65 execution of the recovered original bytes. It **excludes C64 bus stalls and interrupts**. Decoded PNGs are used for drawing, so the runtime does not need to execute the decompressor during gameplay.

The selection routine's tests cover state and request order only. Its two display calls are intercepted by the offline oracle. Those tests do not prove original dashboard behaviour, original input polling cadence or instruction/system timing.

## Input

Input observations enter a queue with integer cycle timestamps. Catch-up updates consume only events visible by their cycle boundary. Opposing directions cancel; diagonals remain possible. WASD maps to the original joystick bits; J supplies its separate fire bit. Space stays on the weapon-selection keyboard bit. Keys 1–4 map to F1/F3/F5/F7.

Host keyboard polling cannot recover key transitions that occur entirely between two host observations. A reference acceptance replay must inject its recorded transitions directly into the queue; it must not depend on interactive wall-clock input.

## Depth and masking

Use two independent actor coordinates: its ground-contact position and its displayed height. Sort ordinary props and actors by the ground position; jumping changes displayed height without changing which side of a prop the actor occupies.

For arches, branches, railings and irregular foreground shapes, use a PNG alpha mask in the scene's original pixel coordinate system. The shader samples the mask at each actor fragment and discards covered fragments above an explicit mask threshold. It uses the actual texture-page UV rectangle, with mask cropping disabled, so transparent borders retain their position in the room. Nearest-neighbour sampling preserves original pixel edges.

An occluder also needs an activation rule: depth baseline, walkable surface or explicit state. `ln_occluder_active` supplies the baseline case. The production conversion must recover each room's actual rules and use the corresponding mask for each actor/depth band; a single unconditional foreground mask cannot model every room. Moving props will need their masks composed or switched with the prop state.

The existing fixture proves partial coverage and holes through actual GameMaker GPU pixel readback. This verifies the shader mechanism. LN1 Wastelands mask-object references and actor-Y activation thresholds are recovered from $df00/$df20. Per-room PNGs encode the maximum covering threshold in alpha; per-pixel equivalence to the original sprite-bit clearing is still unverified. LN2/LN3 mask flags are decoded provisionally, with no original-game parity claim.

## Scene assets

Scenery previews are diagnostic reconstructions, not accepted room backgrounds. Object aliases, special tile blending, colour remapping and some unresolved records remain. Loader datasets also contain fields that can look like locations; generated preview counts must not be used as a game-room count.

The 192 LN1 character parts include body pieces, weapons and other shapes in one source table. Part names retain numeric source IDs because semantic animation names have not been established. The playable LN1 build uses recovered $d000 and $d700 composition records and a decoded action graph. The GML pose requests match the original player and enemy test cases; complete rendered sprite composition still requires pixel comparison.

## Acceptance contract still to implement

Record a fixed original edition, machine model, ROM hashes, PAL/NTSC region, initial snapshot hash, input-event hash and exact observation convention. At those observation cycles compare actor positions and subpixel remainders, facing, animation/frame counters, enemy state, health, inventory, puzzle flags, room/level, timers and random state. Also compare source-palette pixel indices and occlusion at selected checkpoints.

Every discrepancy must identify its first divergent cycle and field. Empty replays, unvisited systems, component fixtures and captures with modified entry PCs must never certify gameplay parity. Asset modifications should be tested separately from a preserved baseline so intentional visual changes do not hide logic regressions.

## Current gameplay checks

`ln1_player.gml` passes 2,856 original-code update samples, including 128 samples covering $ada5 kneeling and $adbd standing, with only rendering calls intercepted by the offline oracle. `ln1_enemy.gml` passes 7,680 updates with a shared sequence of random-byte returns. `ln1_combat.gml` passes 6,843 directional hit tests for valid attack classes. The 660-tick native integration check is a smoke test, not an original gameplay replay.

The runtime random algorithm currently samples a modeled timer at a scheduling boundary; the original reads it at particular instruction cycles. Therefore enemy decisions in a live playthrough are not yet expected to be identical. Damage dispatch, pickup handlers, deaths, hazards and exits have varying implementation coverage and do not inherit the routine-level verification of player or enemy movement.

Wastelands room PNGs are generated by offline execution of original drawing code, which resolves its bitmap attribute merging. The dashboard frame is a captured original image. Live labels ($69dc/$69e0/$69e4), item icons ($63cb) and 33 enemy wound-bar states ($7c4c) are rendered offline by the original routines into editable sprites. Palette equivalence to raster-dependent captures remains open. Remaining level-specific events are explicitly pending. No complete level or game has passed acceptance.

The feedback integration checks cover FOUND expiry after 150 ticks, two scene-entry colour ramps from $6fc1, persistent enemy wounds and defeated state, prayer prerequisites and the original missing-item order at $53c8. Room entry uses the original $bdbb result for each entrance. These checks establish native regression behavior, not end-to-end original replay parity. The current defeated-state handling deliberately prevents the original $ad16 recovery event from clearing a defeat; recoverable knockouts still require a separate verified state.

Sinking follows $bef2/$bee3: a fixed cutoff of min(player Y + 24, 173), two-pixel movement per two timer ticks, then a 20-tick delay. The sprite-bit trimming at $7b27 becomes a shader cutoff at hardware cutoff minus 29 in scene coordinates. GPU readback checks the cutoff. Its starting interrupt phase and full death presentation remain unverified. The four-frame `spr_ln1_water_ripple` is an editable presentation reconstruction; no distinct splash animation was identified in the inspected original sinking routine.

The FOUND, wounded, prayer and water screenshots are deterministic native visual fixtures. They are not original-game reference replays.
