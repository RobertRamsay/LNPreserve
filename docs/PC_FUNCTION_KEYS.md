# PC function keys and quick game starts

PC F1/F3/F5/F7 now drive the matching Commodore function keys: music, item cycling and pause. The number row no longer drives these functions. Top-row 1/2/3 starts a fresh LN1/LN2/LN3 opening scene, clears queued input and scene-preview/workbench state, preserves the running timing transport and selects the opening music. Home uses the same restart path. Controller mappings remain unchanged.

Changed: scripts/ln_input/ln_input.gml, obj_ln_preserve Step/Create events, the three game HUD hints, and tools/run_focused_checks.py. Existing replacement MP3 files were preserved; sound resource references pointing to missing WAV files were updated to their available MP3 replacements to unblock compilation.

Build passed. All 13 focused cases passed, including matching PC/C64 bindings, number-row separation and opening-scene starts for all three games. The full gameplay suite was not rerun for this targeted input change. No manual playthrough is claimed. No commit or push was performed by the assistant.
