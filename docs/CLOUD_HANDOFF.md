# LNPreserve cloud continuation

Prepared 9 September 2026. Use the existing repository https://github.com/RobertRamsay/LNPreserve and its main branch. Do not create a replacement repository or duplicate GameMaker project. Last gameplay checkpoint at preparation: b5df40f9.

## Goal and constraints

Convert all three supplied C64 Last Ninja games into one editable native GameMaker project, verified against the originals. An embedded C64 emulator is not the requested product. Offline execution of original 6502 code is used for recovery and verification. All 18 levels are accessible as prototypes; no complete game or cycle-accurate playthrough has passed acceptance.

Controls: WASD movement; # plus direction for original fire/actions; Space selects weapons; 1–4 replace F keys. Testing arrows: Right NE, Down SE, Left SW, Up NW. F11 selects scenes and offers an off-by-default enemy-damage protection switch; environmental hazards remain active. F12 opens the optional workbench. Keep the gameplay interface nontechnical.

Keep original graphics. LN1 river deaths use sinking and masking, with no invented splash. Earlier broad scenery colour corrections were restricted by the user to LN3's opening scene. Do not apply the remaining diagnostic colour proposals without a new request. Preserve the user's GameMaker edits and fetch before publishing to the same main branch.

## Current project and evidence

- Open `LNPreserve/LNPreserve.yyp`. Editable GML lives in `LNPreserve/scripts`; converted graphics in `LNPreserve/sprites`; recovered records and comparison vectors in `LNPreserve/datafiles`.
- Read `README.md`, `docs/ACCURACY.md`, `evidence/STATUS.json` and `evidence/runtime_checks.json` for scope and actual results. Some older research notes describe earlier stages; do not treat them as current acceptance claims.
- Published dungeon fixes: original guard colours, 88 refreshed special poses, and spider steering/descent timing. Original maze retained; see `docs/DUNGEON_TESTING.md`. Skeleton scene 8, giant spider scene 20, exit scene 23. Source comparisons cover 1,024 spider states.
- All six LN1 levels share the original ordinary enemy colour bank. Inner Sanctum's 78 special poses were also refreshed after finding stale frame images.
- Correction from the privately supplied CCS disk: $4e08/$4e20 ARE animation records, reached by JMP tail calls that the exporter missed. The dog now waits in pose 142 ($4e08); approach boundary 13 starts $4e0c, and contact uses $4e20. Pursuit preserves dog frames and leaving room 11 clears encounter mode. Earlier claims calling these pointers executable dispatchers were incorrect. See `docs/LN1_ENCOUNTER_FOLLOWUP.md` for current evidence and outstanding runner tests.
- LN2 thrown weapons now use original art, ammo/lifetime/damage rules, per-part masking and three body sprites while a projectile occupies the fourth slot. Checks cover 14,336 projectile states, 2,976 original full-sprite mask probes, 1,499,904 projectile GPU pixels and 2,764,800 body GPU pixels. Full display timing and original input replays remain pending.
- LN2 final keypad, boss release, candles and native ending are present. LN3 mechanisms and the original ending picture/text sequence are present; completeness remains limited as documented.
- Latest local compilation, full native regression run and eight structural checks passed. Existing reports describe that Windows run; do not present them as a new cloud run.

## Next work

Graphics cleanup: read `docs/CHARACTER_ASSETS.md` before changing character art
or running old exporters. LN1/LN2 assembled character banks now resolve through
`datafiles/graphics/characters.json`; legacy bank names are logical identifiers,
not sprite resources. Type-specific overrides allow independent replacements.
Existing part-based projectile/LN3 paths and special-actor mappings remain.

LN1 Shogun follow-up: native hurt/death now uses original actor-136 branches
$50c7/$507e, including the defeat event that sends the player to the scroll
room. See `docs/LN1_SHOGUN_FOLLOWUP.md`; original state checks pass, updated
native integration checks await the user's Windows run.

The private reference archive is now supplied and all seven LN2 captures are available in this cloud workspace. See `docs/LN2_PROGRESSION_AUDIT.md`: Central Park's switched-hole mode 5 and original final-safe interaction drawing are connected; 199 original exit cases and 32 bounded hole-dispatcher cases pass here. Native/GPU checks remain pending on the Windows runner. The other special-boundary modes are still open.

Prioritise reported gameplay defects and original behaviour over diagnostic UI. The next identified LN2 gap is its special boundary dispatcher: hazards, climbs and scripted exits. The original level-1 dispatcher starts at $9fd8; other banks relocate it. It requires boundary-crossing bit 7, waits for an action to finish unless boundary bit 6 allows interruption, then dispatches the low six mode bits. Its low return-address table is obtained from the absolute operand at dispatcher + 26; handler addresses are table words plus one. Do not confuse these with ordinary perimeter exits. Some boundary records may be inactive/padding; verify original activation before implementing their apparent modes.

Other unfinished areas: LN2 swarm behaviour, remaining item details/flashes, HUD/eyes, full death/game-over and keypad delay; LN1 remaining puzzles, projectile collisions, special sequences, recoverable knockouts and ending; LN3 high-score program, HUD/portraits and raster details. All three need original input replays and system-timing validation. Twelve LN1 music resources now contain user-supplied MP3 audio; 29 LN2/LN3 resources remain silent placeholders. Loader tracks are registered but no loader-screen playback path exists yet.

## What is and is not transferred

The Git repository contains the editable game, PNG assets, native logic, extracted gameplay data, comparison vectors and published evidence. A cloud worker must first verify that its GitHub connection or shell can read this repository; cloud task creation alone does not guarantee repository write access.

`source/local/`, `tools/vendor/` and `build/` are deliberately ignored. Original ZIP/disk files, unpacked original RAM captures, VICE snapshots, downloaded reference tools and compiled binaries are not in Git. They have not been uploaded by this handoff. Further original-code recovery requires these inputs to be supplied privately to the chosen cloud workspace, or recovered from supplied originals using the documented tools. Do not publish original disk archives into the repository as a substitute for private transfer.

The original source archives are `last_ninja_the.zip`, `last_ninja_2_the.zip` and `last_ninja_3_the.zip`. Extraction procedures are in `docs/REPRODUCING.md`; dependencies in `tools/requirements.txt`. Several scripts currently depend on Windows, local VICE and existing snapshots. Inspect prerequisites before invoking them in a cloud environment.

The working GameMaker runtime was Windows LTS 2026.0.0.23. Build with `tools/compile.ps1`; run `tools/run_checks.py --runner <installed Runner.exe>`. An authenticated compatible runtime is not supplied by this repository. A cloud worker can inspect and edit source without that runtime, but must not claim GameMaker compilation or GPU tests passed there without actually running them. Never edit project files during an active compilation.

## Starting the cloud task

Read this brief and current repository status, confirm repository access and available tools, then report which local-only prerequisites are missing. Continue using the existing repository. If source captures or a compatible GameMaker runtime are unavailable, work on bounded changes that can be checked with the available evidence and report the remaining validation explicitly.

Save slots: Ctrl+S adds a local persistent snapshot; click the right-side list to restore. Ten shared slots, newest first, named LN1_SAVE_1410 etc. See docs/SAVE_SLOTS.md for implementation and pending Windows checks.
