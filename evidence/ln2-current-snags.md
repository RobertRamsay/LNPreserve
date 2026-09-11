# Current LN2 snag fixes

- Crates: corrected reading of the user's arrows. Route is upper, right, lower-left, lower-right. Reverse traversal uses the same adjacent supports. Intermediate crates cannot be skipped; each hop requires its specified facing. Bank connections remain available.
- Office fan-side grate: rises 48 source pixels over 48 game ticks (about one second), using the original pixel art without stretching. Mid-rise saves resume correctly; final pixels equal the recovered open panel. Existing passage-opening logic retained.
- Mansion alarms: stair sensor in displayed scene 4 triggers original flashing indicators. Source lamp rooms are internal 2, 3, 7, 8 and 9. Ordinary flashes change every 12 ticks. The scene 9 reset button runs 16 fast changes at three-tick intervals, then stops flashing and prevents retriggering. Original fourfold enemy-hit damage is restored; as in the source, resetting retains the previously-triggered bit and therefore the stronger enemy hits.
- Basement trolley and Office fan: recovered using their room-specific shared sprite colours, dark grey (11) and medium grey (12), rather than character red (2).
- Helicopter: full compositor output retained with a larger canvas and corrected origin, restoring the clipped upper section. Nearby single-fire pickup assistance now admits the helicopter ladder; the original manual grab still works.

Changed runtime scripts: ln2_levels, ln2_items, ln2_play, ln2_combat and ln2_object_rules. New sprites: spr_ln2_basement_trolley, spr_ln2_office_fan, spr_ln2_level5_helicopter, spr_ln2_level6_helicopter and spr_ln2_mansion_alarm, registered in the project. Source addresses and sprite bounds are in the adjacent JSON evidence files.

GameMaker build and targeted runtime checks pass. Structural validation: nine passed, one optional fixture skipped. See runtime_checks.json for the final complete-suite run. Automated checks do not substitute for manual playtesting of movement and visual feel.
