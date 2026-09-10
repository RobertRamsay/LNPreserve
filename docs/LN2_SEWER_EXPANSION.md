# Sewer doorway expansion

This is an authored, optional extension of Last Ninja 2's Sewers, not a recovered original route map. Scene numbers match the native scene selector. Door labels read left to right.

| Entrance | Destination | Return |
| --- | --- | --- |
| Scene 6 single door | Scene 7 right door | Same pair |
| Scene 7 left door | Scene 9 right door | Same pair |
| Scene 10 right door | Scene 15 maintenance gallery, left arch | Same pair |
| Scene 15 right arch | Scene 12 right door | Same pair |
| Scene 9 middle door | Scene 6 single door | One-way setback |
| Scene 10 left door | Scene 9 middle door | One-way setback |

Walk into the arch. Arrivals face outwards; step away from the doorway before re-entering it. Door links preserve health, lives, inventory and encounter state. Their arrivals and the new gallery survive saves; older Sewer saves acquire the new route records without resetting progress.

The existing doors remain: 1→2, 2→3, scene 5 blue door→0, scene 5 tool-opened grate→6, scene 7 middle→8, scene 9 left→10, scene 12 left→13 and scene 14→Basement. All new links occur after the tool gate. The normal route remains available.

## Maintenance gallery

Scene 15 reuses the original renderer, brick and arch panels, native palette, dogleg floor, pipe housing and depth mask. It adds two arches, torches and end railings. The inherited walls block walking. The exposed pavement edges lead to water, using this level's recovered splash frames and the existing health/life transition. Jump landings outside the pavement also fall into water. The railings close the inherited perimeter exits.

Flames use the original three frames, advancing every six game ticks. They animate in the seven original flame rooms (0, 1, 3, 5, 10, 11, 13), and on both gallery torches.

## Verification and playtest

`--ln2-sewer-network-test` checks all ten door endpoints, real walking approaches, safe arrivals, saved arrivals, the continuous gallery floor, drowning completion and old-save migration. `--ln2-sewer-flames-test` checks original frame differences, timing, wrap, saved phase and the opened grate. The full suite retains the original route comparisons.

Manual playtesting remains required: try both directions through every pair, the two setback routes, gallery jumps and water edges, and the full normal route with the tool gate. Automated room coverage is not a full manual playthrough.
