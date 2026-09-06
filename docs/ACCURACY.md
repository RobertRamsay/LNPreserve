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

Directional testing uses separate host key edges: Right=NE, Down=SE, Left=SW, Up=NW. Those keys never enter the original joystick. Wastelands directions are derived from reciprocal entrance positions/facings, excluding padded exit-table defaults that do not represent connected doors. Each selected boundary point runs the original $7478 routine offline; 54 cases check destination, entrance, position and facing against compiled GML. Both ordinary exits and test jumps share `ln1_play_travel`. Test jumps additionally cancel transient actions and recover dead players, deliberately differing from gameplay. A graph check establishes that all 25 Wastelands rooms are reachable; persistence checks retain items and enemy wounds. These tests do not certify LN2/LN3 gameplay or cycle timing.

The F11 picker exposes native prototypes in all 18 levels, including LN3’s original special entrance to Void’s final encounter. Fire’s isolated partial scene-12 record remains preserved as scenery but has no selectable gameplay entrance. Native prototypes do not establish complete object, objective or playthrough parity.

## Depth and masking

Use two independent actor coordinates: its ground-contact position and its displayed height. Sort ordinary props and actors by the ground position; jumping changes displayed height without changing which side of a prop the actor occupies.

For arches, branches, railings and irregular foreground shapes, use a PNG alpha mask in the scene's original pixel coordinate system. The shader samples the mask at each actor fragment and discards covered fragments above an explicit mask threshold. It uses the actual texture-page UV rectangle, with mask cropping disabled, so transparent borders retain their position in the room. Nearest-neighbour sampling preserves original pixel edges.

An occluder also needs an activation rule: depth baseline, walkable surface or explicit state. `ln_occluder_active` supplies the baseline case. The production conversion must recover each room's actual rules and use the corresponding mask for each actor/depth band; a single unconditional foreground mask cannot model every room. Moving props will need their masks composed or switched with the prop state.

The existing fixture proves partial coverage and holes through actual GameMaker GPU pixel readback. This verifies the shader mechanism. LN1 Wastelands mask-object references and actor-Y activation thresholds are recovered from $df00/$df20. Per-room PNGs encode the maximum covering threshold in alpha; per-pixel equivalence to the original sprite-bit clearing is still unverified. LN2/LN3 gameplay occlusion rules still require recovery. Their scenery X bit 7 is horizontal reversal, not a mask flag.

## Scene assets

The approved exception is LN3 level 1's opening scene (source scene 0). Its 34,560 background pixels match a direct decode of the supplied C64 game's VIC bitmap, screen and colour RAM, with zero differences under the project's palette. Its 13,456-byte scenery payload at $0800 also matches the reference dataset exactly. The original $71f9 drawing routine reproduces those pixels offline. Incorrect inherited panel recolours caused the pink rocks; provisional RGB overlap also miscoloured edges. Only this scene's exported PNG and existing GameMaker sprite/layer were replaced. The audit found 279 changed scene records in total, but the other candidates were explicitly left unapplied. This does not certify LN2 rendering or other LN3 scenes.

Scenery previews are diagnostic reconstructions, not accepted room backgrounds. Special tile blending and colour remapping still require original-game pixel comparisons. The current LN2/LN3 datasets parse without unresolved records. Loader tables contain repeated picture references; source-record counts must not be used as a game-room count.

The corrected parser accepts a three-byte LN2/LN3 entry plus its optional colour bytes and a one-byte terminator at the end of a file. The previous eight-byte boundary check dropped final panel pieces, visibly truncating LN2 loader titles. The renderer now reverses bitmap pixels and cell colours for LN2/LN3 X bit 7; the previous interpretation omitted those pieces. This interpretation was checked against the symbol-bearing Integrator 2012 1.5.2 decoder's load and render paths (`tools/inspect_reference.py`); it is not evidence of matching the supplied LN2/LN3 disk editions. The reference canvas remains 240 × 144 pixels.

Identical image dimensions and RGBA bytes share one canonical PNG and sprite. Each original scene/object ID remains an alias in `graphics/manifest.json`; the catalog shows each sprite once per dataset with its `source_ids`. This removes 331 duplicate scenery images, 14 duplicate character-part resources and 436 empty diagnostic mask resources. Required GameMaker layer/frame copies, animation frame identities and recovered Wastelands depth masks are retained. `asset_rebuild_check.json` records whether re-exporting and rebuilding leaves generated assets unchanged.

The 192 LN1 character parts include body pieces, weapons and other shapes in one source table. Part names retain numeric source IDs because semantic animation names have not been established. The playable LN1 build uses recovered $d000 and $d700 composition records and a decoded action graph. The GML pose requests match the original player and enemy test cases; complete rendered sprite composition still requires pixel comparison.

## Acceptance contract still to implement

Record a fixed original edition, machine model, ROM hashes, PAL/NTSC region, initial snapshot hash, input-event hash and exact observation convention. At those observation cycles compare actor positions and subpixel remainders, facing, animation/frame counters, enemy state, health, inventory, puzzle flags, room/level, timers and random state. Also compare source-palette pixel indices and occlusion at selected checkpoints.

Every discrepancy must identify its first divergent cycle and field. Empty replays, unvisited systems, component fixtures and captures with modified entry PCs must never certify gameplay parity. Asset modifications should be tested separately from a preserved baseline so intentional visual changes do not hide logic regressions.

## Current gameplay checks

`ln1_player.gml` passes 2,856 original-code update samples, including 128 samples covering $ada5 kneeling and $adbd standing, with only rendering calls intercepted by the offline oracle. `ln1_enemy.gml` passes 7,680 updates with a shared sequence of random-byte returns. `ln1_combat.gml` passes 6,843 directional hit tests for valid attack classes. The 660-tick native integration check is a smoke test, not an original gameplay replay.

The runtime random algorithm currently samples a modeled timer at a scheduling boundary; the original reads it at particular instruction cycles. Therefore enemy decisions in a live playthrough are not yet expected to be identical. Damage dispatch, pickup handlers, deaths, hazards and exits have varying implementation coverage and do not inherit the routine-level verification of player or enemy movement.

Wastelands room PNGs are generated by offline execution of original drawing code, which resolves its bitmap attribute merging. The dashboard frame is a captured original image. Live labels ($69dc/$69e0/$69e4), item icons ($63cb) and 33 enemy wound-bar states ($7c4c) are rendered offline by the original routines into editable sprites. Palette equivalence to raster-dependent captures remains open. Remaining level-specific events are explicitly pending. No complete level or game has passed acceptance.

The feedback integration checks cover FOUND expiry after 150 ticks, two scene-entry colour ramps from $6fc1, persistent enemy wounds and defeated state, prayer prerequisites and the original missing-item order at $53c8. Room entry uses the original $bdbb result for each entrance. These checks establish native regression behavior, not end-to-end original replay parity. The current defeated-state handling deliberately prevents the original $ad16 recovery event from clearing a defeat; recoverable knockouts still require a separate verified state.

Sinking follows $bef2/$bee3: a fixed cutoff of min(player Y + 24, 173), two-pixel movement per two timer ticks, then a 20-tick delay. The original persistent timer at $026f allows an immediate first descent if two ticks have already elapsed. The native timer passes 1,536 comparisons against offline execution of $bee3, with only rendering at $5a8d intercepted. Interrupt phase is excluded.

The sprite-bit trimming at $7b27 becomes a shader cutoff at hardware cutoff minus 29 in scene coordinates. GPU readback checks that cutoff. `tools/inspect_ln1_water.py` places the supplied-disk snapshot in river room 11 and observes the original program through full submersion. The captured frame number stays fixed; original player sprite rows disappear at the waterline, with no separate ripple observed. The invented `spr_ln1_water_ripple` resource, PNG and draw call have been removed. No unrelated recovered graphic has been relabelled as a splash. The fixture changes room/position and entry PC, so it does not establish an authentic input replay, full death-presentation parity or pixel-identical native composition.

The FOUND, wounded, prayer and water screenshots are deterministic native visual fixtures. They are not original-game reference replays.

`inspect_ln1_river_entry.py` extends the river fixture to original walking and failed-jump logic before $bef2, using entrance 44's recovered position/facing and input supplied after the original poll. Both traces retain a fixed player frame during sinking. Logical frames 150–152 reference white bird parts 17–19 and are used by scripts $ae82/$aeaa in Buddha rooms 6/17; they were not observed as river-death sprites. Room/entrance injection and monitor input substitution remain explicit limits of this evidence.


## LN3 native integration

All five original banks now supply native scene prototypes. The PAL timer follows the recovered IRQ byte-counter decrements and 16-bit throw-timer wrap; gameplay uses the original four-frame gate. The relative phase of the IRQ, main loop, bitmap drawing, input and raster-random reads is not verified. No system or whole-game timing claim follows from this integration.

Original comparisons cover 7,191 collision states, 6,000 enemy decisions, 6,000 melee/projectile states and 3,064 scene reset/entry/climbing/falling states, in addition to the previously recorded movement, action, input, animation and mask comparisons. GPU readback validates 66,528 alpha/tint pixels from 132 original ordinary sprite parts, after applying recovered scenery masks. Special-actor expansion/multicolour and complete VIC output remain outside that pixel check.

The native regression run visits 65 selectable scenes, exercises 201 destination records and advances 6,500 ticks. It does not replace original input replays. All 29 item/mechanism records now drive native pickup/use handlers; 3,480 original states cover proximity, pickups, recipes and rewards. FOUND timing has native regression checks. Original portrait animation/panels remain incomplete.

Scenery PNG overlays and masks come from original drawing commands. First-entry and repeating cycles retain 49 animation steps across 50 unique overlays. Selection passes 1,176 original states; rendering passes 6,028 bitmap samples. Fire's lit cauldron uses its original modified commands, the gate its redraw fragment, and Void's impact its original screen-colour IRQ changes: 52 unique overlays and 5,280 further GPU samples.

Mechanisms pass 3,520 original routine states and sequence requests. Earth and Water resume after their original 54/45 PAL-tick fade waits. Void's reflected bolts lead through the native curtain/message sequence into scene 12 at the original position/facing from $69ea-$6a1a. The eight curtain sprites and three messages are original artwork; movement passes 1,260 original IRQ-helper states. Fade/wipe/message integration checks completion and final entrance state, not identical interrupt phase or complete VIC output. The final fight reaches the ENDING loader boundary; that separate program is not converted. The runtime retains the original victory message there.

The original dashboard/portrait, some palette effects, full input replays and whole-system timing remain incomplete. No complete LN3 level or game is certified by these component and integration checks.
