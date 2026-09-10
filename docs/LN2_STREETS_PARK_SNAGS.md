# LN2 Streets and Park snag fixes

## Behaviour and source evidence

- Streets scenes 5/7: pot action graphs already contained the complete fall and smash. The old 96-pixel canvas clipped the lower parts: frame 113 reaches y=141 relative to a y=64 origin. Recovered frames 99–114 into a 256x192 canvas, including both mirrored versions. Existing animation timing and damage events remain in place.
- Streets scene 8: the bottle is the small white object beside the seated man outside Drugs. Its uncollected image already matched the original source. Recovered and checked both panels, retaining the 26-pixel pickup/removal difference. Native fire-assisted pickup is exercised; no bottle was invented in scene 7.
- Traffic: original IRQ $1e9e increments $b0 every fourth game tick. $9ac4 toggles inventory flag 18 every 50 increments (200 game ticks). Recovered the two bitmap light panels for scenes 1/4/5/8/9/11 and draw them over the room. Timing survives saving and pauses with gameplay.
- Motorcycles: original boundary handlers $9db1/$9dcb/$9de5 gate modes 35/36/37 against the signal and an empty scenery actor slot. They start actions $c8ce/$c8ec/$c8f8 and apply the original fatal damage. Recovered bike frame 114 with the source red/white shared palette. Native checks verify entry and departure/reset; 192 independent original-machine dispatch comparisons cover signals, occupied actor, crossing flags and ongoing actions.
- Streets scene 14: successful wrench use drew an immediate removed panel at $bb73 that the existing entry-only image variants omitted. Restored its 416 changed pixels. Fire assistance now supports this mechanism when the wrench is selected. Open art survives saves, including old saves with stale scene metadata, and the open hole starts the existing sewer descent.
- Park scenes 5/7: pickup assistance now uses the nearest point in the source interaction rectangle rather than its centre. The latter teleported players into the far interior of the oversized chain rectangles. Both chains and their nunchakus combination are tested through actual action updates.
- Park toilets: reproduced inward walking out of the far end into the neighbouring room. Added native end caps joining the wall endpoints of all four cabins. This is an intentional collision repair, not a claim that the original boundary table included those caps. Inward movement is stopped; outward movement remains available, including for older saves already beyond the cap. Tests retain the original boundary comparisons and separately exercise the repair.

## Changed areas

Runtime: ln2_levels, ln2_play, ln2_player, ln2_items, ln_saves. Data/resources: level2 world/gameplay records, six Streets sprite resources, project registration. Tests: obj_ln_preserve entry point and tools/run_focused_checks.py. Reproducible source recovery: tools/export_ln2_street_snags.py and tools/export_ln2_traffic_checks.py, each with --source-root pointing to supplied captures. Source hash and sprite bounds are recorded in evidence/ln2_street_art.json.

## Verification

The build and all 16 focused checks pass, including --ln2-street-snags-test. Project validation: nine pass, one source-dependent skip. Native screenshots cover both smashed pots, the bottle, motorcycle and open manhole. All 36 complete-suite groups passed in 128.72 seconds, including save serialization and runtime checks; no failed or unreached groups remain. Results are recorded in evidence/runtime_checks.json. The older scenery comparison fixture needed its native-only custom-actor field restored; all original expected values and comparisons remain unchanged.

Automated room/component coverage is not a full manual playthrough. Manual follow-up: approach each toilet from normal room entry, try traffic crossing timing, and continue from the open manhole into the sewers.
