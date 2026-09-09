# LN2 triggers and progression — 9 September 2026

Base main: `39c398b3`. The private reference archive supplied this session passed its manifest checks: 308 files, 152 newly extracted, no differing existing input overwritten. All seven LN2 capture hashes match the previously exported worlds. Captures, snapshots and disks remain excluded from Git. Windows GameMaker and VICE executables are not supplied by this archive.

## Changes

Central Park's wall punch is interaction 18 in scene 2, action 4, facing 1, at x=158..164, y=85..87. Its flag already selected the hole image in scene 1. Missing boundary mode 5 now follows $9fd8/$a081: require crossing bit 7, wait for the current action unless mode bit 6 permits interruption, require odd crossing and flag 18, consume the flag, request five original sinking actions, unlock the exit, then take outgoing slot zero (entry 2, scene 3). The editable native sequence uses existing original poses. Its timing and complete masked presentation still need a runner comparison; no splash is added.

The final safe is drawn by interaction completion, not by room-entry rendering. All previously exported variants were the same because entry rendering alone never drew these panels. The original $7e8a calls after items 17, 18, 16 and 23 now supply five scene stages: initial, reveal, open, contents removed, reward. Successive draws change 820, 244, 42 and 42 pixels. The native completion path retains the stage through subsequent scene refreshes; room entry resets it as the original entry renderer does. This is a narrow final-room correction, not a broad scenery colour update.

## Checks actually run here

`python tools/check_ln2_progression.py` executes original exit routines against stored cases, and tests 32 hole-dispatcher states. Only the blocking sink loop is stubbed in those dispatcher tests; its requested count is recorded, and original entrance code runs afterward. Thus these tests do not verify the sink animation loop or native GML execution.

| Level | Original exit cases | Interaction records inspected |
| --- | ---: | ---: |
| Central Park | 35 | 15 |
| Street | 39 | 15 |
| Sewers | 30 | 8 |
| Basement | 38 | 16 |
| Office | 29 | 5 |
| Mansion | 25 | 6 |
| Final Battle | 3 | 5 |

All 199 exit cases pass. `tools/export_ln2_safe.py` verifies five saved scene images against original drawing. Nine structural/disk tests pass with all eight original LN1/LN2/LN3 disks now available. Updated native checks exercise the wall punch, hole sequence and successful safe drawing stages, but have not run here. No compilation, GPU readback or original-input playthrough was performed this session.

## Still open before complete-level acceptance

The general special-boundary dispatcher is still incomplete. Only Central Park mode 5 is added here; other sensor modes, scripted climbs/exits, hazards and swarm behaviour require individual original-code recovery. Exported sensor kinds are listed per level in `evidence/ln2_progression_audit.json`; inactive/padded records must not be treated as real encounters without checking activation.

Perimeter reachability does not establish puzzle progression. Central Park record 6 and Mansion record 11 are outside their ordinary perimeter graphs; Mansion's alternate scene is already treated specially by the picker. Do not invent connections to make every exported record reachable.

Existing native world tests omit level-end navigation cases and use idle scene visits; object tests directly set some prerequisites. These are component checks, not seven completed levels. All real routes, alternate entrances, item prerequisites, deaths/revisits and final encounter timing still need original input replays. Item flashes, dashboard/eyes, death/game-over and keypad delay also remain incomplete.

Next local test: punch the switch in Central Park scene 2, return normally to scene 1 and enter the hole; in Final Battle reveal and open the safe through normal interactions. Compare against VICE and retain input/log evidence before claiming parity. Continue remaining dispatcher modes using the now-available captures.
