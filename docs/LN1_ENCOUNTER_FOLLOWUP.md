# LN1 encounter follow-up — 9 September 2026

Base: main `30a3952e`. User music and unrelated project changes preserved.

## Original evidence

The privately supplied `last_ninja_the.zip` has SHA256
`9bbea4ea6af78bb2f90f5f2bfc20bfb4c00c892a6ed51e0286fcad3d955dddb7`, matching the existing disk inventory. Extract CCS banks privately using the existing disk extraction helpers. `tools/unpack_ln1_common.py` recovers common code from the CCS loader with py65 1.2.0, implementing its NMOS DCP instruction and skipping title UI to the original bank-copy/unpack path. This is bounded offline execution, not a booted C64 or gameplay replay. Original archives, banks and recovered RAM remain ignored.

Run `python tools/check_ln1_encounters.py` after recovery:

- Dog: six missing action records at $4e08 and $4e20..$4e29 match source bytes. Five $bdc4 boundary cases verify approach release; idle pose is 142. Export now discovers JSR and JMP action setters, correcting the earlier false dispatcher diagnosis.
- Dye: five $561f cases, including byte wrap, confirm colour 2 on player slots 1–3 while protection is 2 and expiry after 250 player ticks. Existing pickup/expiry logic was present; rendering was missing. Native shader replaces black player pixels with palette red (129,51,56), preserving alpha and the usual nonblack face. Exceptional composite poses and flashing overlap still require per-part/GPU parity verification. Shader-unavailable fallback has no dye effect.
- Spider: level-four $5513 tables select shared colours 11 and 1 (grey/white), not exporter defaults 7 and 8. `tools/fix_ln1_spider_palette.py` refreshes only frames 141–144 and their mirrors, including editable layers: 16 PNGs. All alpha geometry matches the previous images; saved pixels match the source compositor.
- Final approach: all 15 room exit tables match; ten original $7478 exit selections in rooms 12–15 match navigation. No level-one reset was reproduced offline. Room 15's NW exit to room 1 is in the original table and remains within Inner Sanctum. No speculative exit change was made. `LN1_TRAVEL` debug lines now identify level, source room, entry and target room; target 0 denotes level-end handling.

## Validation limits and next local test

`python tools/validate_project.py` ran nine tests: eight passed and the full disk-inventory test failed because only four of eight required disks are available (LN2/LN3 inputs missing). Available LN1 disk hashes and extracted bytes matched before that completeness assertion. Updated native integration checks cover dog idle/release/contact, dye expiry and the 12→13→14→15 route, but require the user's GameMaker runner. No compilation, GPU test, full original-disk playthrough or cycle-accuracy claim is made for these changes.

In GameMaker: enter room 11 normally and via F11, wait, then approach the dog; collect dye in room 12 and inspect its expiry; view dungeon room 20; walk the final approach. If a reset occurs, supply the `LN1_TRAVEL` lines and exact direction. Home intentionally starts a new LN1 game. The broader reference archive and Windows GameMaker/VICE tools are still not supplied here.
