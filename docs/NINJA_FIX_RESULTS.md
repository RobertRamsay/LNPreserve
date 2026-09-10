# Ninja handoff implementation results

10 September 2026. Repository: `D:/POLYTRICITY/LNPreserve`.

NINJA-01, NINJA-02 and NINJA-03 are complete. NINJA-04 ordinary manual progression is blocked by Windows capture, not a demonstrated game fault.

Existing local work was preserved. This session did not reset, commit or push. HEAD advanced from `0e866ebe` to `bca55e28` during the session, so some changes are already in that concurrent commit and the rest remain local. The file list below describes this handoff work, not merely the final unstaged diff. No gameplay rules were changed by these handoff fixes.

## Validation

| Check | Result |
|---|---|
| GameMaker build | Passed |
| Combined suite | 36/36 groups passed; every required original PASS marker observed; 126.55 seconds |
| LN2 enemy oracle | 50,432 original updates across all seven level banks passed |
| Revival integration | 16 level/room/costume/defeat contexts passed; only the undefeated final-room Shogun extinguishes candles |
| Previously blocked save checks | Passed for LN1, LN2 and LN3; methods, state restoration, active LN1 animation and snapshot independence checked |
| Previously blocked graphics/runtime | Passed, including LN2 ending/projectile graphics and LN3 graphics; runtime completed eight host frames |
| Independent LN1 suite | 14/14 groups passed, including LN1 save serialization, mask/render captures and runtime; 7.42 seconds |
| Seven focused checks | All passed: magic/weapon lock, pickup/CRT, jump assist, reverse roll, live CRT, window presets, Xbox |
| Save UI | Four native captures inspected: 1280×800 / 2560×1600, CRT off/on; three occupied game labels and seven empty slots fit |
| Reporting failure injection | Expected failure: script returned 1 although GameMaker returned 0; first group failed, all 13 downstream LN1 groups not_run |
| Reporting unit tests | 3 passed |
| Project structure | 9 passed, 1 source-dependent skip |

The first repaired run exposed the fixture's missing costume field; completing its explicit isolated context resolved it. The next run reached an ending-palette mismatch: the reference exporter used the original room bitmap, while the fixture drew a safe/curtain variant introduced later. Drawing the reference base resolved the mismatch without changing any expected pixels. Separate safe/curtain behavior remains covered by its existing checks.

There are no unexpected failed or not-run required groups in the final combined or independent LN1 run. The deliberate failure report is a reporting test, not a remaining gameplay regression.

## Scope and remaining gaps

- Automated room/navigation checks and short integration sequences are not a full ordinary manual playthrough. The existing handoff's 134-room LN1 coverage claim remains separate from manual completion; this session's navigation log explicitly records 54 original exit vectors and all 25 Wastelands rooms reachable.
- Live Windows capture was retried twice after refreshing the target, and both attempts returned `SetIsBorderRequired failed: No such interface supported (0x80004002)`.
- Consequently, ordinary Wastelands-to-final-scroll progression, live save-slot clicks, and subjective audio/gameplay evaluation were not performed. Native image captures are automated rendered evidence, not interactive playtesting.
- Save UI fixtures existed only in memory. No user save slot was created, restored, overwritten or deleted for that check.
- Once live window access works, continue NINJA-04 in the handoff's order: reproduce ordinary progression blockers, then other gameplay faults, then visual/audio issues. Record state, inputs, expected/actual result and reproduction evidence before changing gameplay.
- Whole-game parity, original input replays, full-system timing and the documented sound/ending limitations are not established by this suite.

## Changed implementation files

- [LNPreserve/scripts/ln2_enemy_checks/ln2_enemy_checks.gml](D:/POLYTRICITY/LNPreserve/LNPreserve/scripts/ln2_enemy_checks/ln2_enemy_checks.gml): Explicit isolated fixture context; 16 separate guard/Shogun revival contexts. Original vector fields, pose comparisons and random-consumption checks retained.
- [LNPreserve/scripts/ln2_ending/ln2_ending.gml](D:/POLYTRICITY/LNPreserve/LNPreserve/scripts/ln2_ending/ln2_ending.gml): Newly reached palette fixture now draws the original bitmap used by its exporter; all original expected pixels retained.
- [LNPreserve/scripts/ln_saves/ln_saves.gml](D:/POLYTRICITY/LNPreserve/LNPreserve/scripts/ln_saves/ln_saves.gml): Fit Click to load inside the slot; reuse serialization checks with optional LN1 scope.
- [LNPreserve/scripts/ln_checks/ln_checks.gml](D:/POLYTRICITY/LNPreserve/LNPreserve/scripts/ln_checks/ln_checks.gml): Reusable group start/pass/fail wrapper and independent LN1 component entry point.
- [LNPreserve/objects/obj_ln_preserve/Create_0.gml](D:/POLYTRICITY/LNPreserve/LNPreserve/objects/obj_ln_preserve/Create_0.gml): LN1-only and deliberate-failure flags, save test scope, disposable save UI fixtures.
- [LNPreserve/objects/obj_ln_preserve/Step_0.gml](D:/POLYTRICITY/LNPreserve/LNPreserve/objects/obj_ln_preserve/Step_0.gml): Explicit runtime outcomes and save UI capture sizing.
- [LNPreserve/objects/obj_ln_preserve/Draw_0.gml](D:/POLYTRICITY/LNPreserve/LNPreserve/objects/obj_ln_preserve/Draw_0.gml): Named graphics groups; LN1-only rendering checks omit LN2/LN3 graphics suites.
- [LNPreserve/objects/obj_ln_preserve/Draw_64.gml](D:/POLYTRICITY/LNPreserve/LNPreserve/objects/obj_ln_preserve/Draw_64.gml): Four save UI captures and client-size/text-width checks.
- [tools/run_checks.py](D:/POLYTRICITY/LNPreserve/tools/run_checks.py): --suite all/ln1, --inject-failure, explicit passed/failed/not_run groups, failure-aware exit status and separate logs/reports.
- [tools/check_manifest.json](D:/POLYTRICITY/LNPreserve/tools/check_manifest.json): Required groups and existing PASS marker inventory.
- [tools/run_focused_checks.py](D:/POLYTRICITY/LNPreserve/tools/run_focused_checks.py): Seven handoff regressions plus save UI check, requiring expected markers and no failure markers.
- [tools/test_check_reporting.py](D:/POLYTRICITY/LNPreserve/tools/test_check_reporting.py): Three reporting regressions: early failure, interrupted check and failure overriding a pass.

## Evidence and rerunning

- [evidence/runtime_checks.json](D:/POLYTRICITY/LNPreserve/evidence/runtime_checks.json)
- [evidence/ln1_runtime_checks.json](D:/POLYTRICITY/LNPreserve/evidence/ln1_runtime_checks.json)
- [evidence/ln1_runtime_checks_injected.json](D:/POLYTRICITY/LNPreserve/evidence/ln1_runtime_checks_injected.json)
- [evidence/focused_checks.json](D:/POLYTRICITY/LNPreserve/evidence/focused_checks.json)

From the repository root, use the installed Python and GameMaker Runner:

```powershell
& "C:/Users/Robert/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe" -X utf8 -B tools/run_checks.py --runner "C:/ProgramData/GameMakerStudio2-LTS2026/Cache/runtimes/runtime-2026.0.0.23/windows/x64/Runner.exe"
& "C:/Users/Robert/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe" -X utf8 -B tools/run_checks.py --suite ln1 --runner "C:/ProgramData/GameMakerStudio2-LTS2026/Cache/runtimes/runtime-2026.0.0.23/windows/x64/Runner.exe"
& "C:/Users/Robert/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe" -X utf8 -B tools/run_focused_checks.py --runner "C:/ProgramData/GameMakerStudio2-LTS2026/Cache/runtimes/runtime-2026.0.0.23/windows/x64/Runner.exe"
& "C:/Users/Robert/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe" -X utf8 -B tools/run_checks.py --suite ln1 --inject-failure --runner "C:/ProgramData/GameMakerStudio2-LTS2026/Cache/runtimes/runtime-2026.0.0.23/windows/x64/Runner.exe"
```

The final command intentionally returns a nonzero exit code. Test logs are retained under `build/`; the required-group and PASS-marker inventories are in `tools/check_manifest.json`.

- [Save panel 1280×800, CRT off](D:/POLYTRICITY/LNPreserve/evidence/ninja_handoff/lnpreserve-save-ui-1x-0.png)
- [Save panel 1280×800, CRT on](D:/POLYTRICITY/LNPreserve/evidence/ninja_handoff/lnpreserve-save-ui-1x-1.png)
- [Save panel 2560×1600, CRT off](D:/POLYTRICITY/LNPreserve/evidence/ninja_handoff/lnpreserve-save-ui-2x-0.png)
- [Save panel 2560×1600, CRT on](D:/POLYTRICITY/LNPreserve/evidence/ninja_handoff/lnpreserve-save-ui-2x-1.png)
