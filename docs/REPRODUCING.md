# Reproducing the current conversion

Run commands from the repository root. Opening the existing GameMaker project requires none of these extraction steps.

## Inputs

```powershell
python -m pip install -r tools/requirements.txt
python tools/extract_disks.py 'C:/Users/me/Downloads/last_ninja_the.zip' 'C:/Users/me/Downloads/last_ninja_2_the.zip' 'C:/Users/me/Downloads/last_ninja_3_the.zip'
python tools/fetch_references.py
```

The extractor uses directory sector chains, not guessed fixed offsets. Original disk copies and extracted files go to ignored `source/local/`. Reference archives are hash checked and unpacked to ignored `tools/vendor/`; the downloader does not run them.

## LN1 unpacked capture

```powershell
python tools/prepare_ln1_capture.py
python tools/capture_reference.py source/local/last_ninja_the_side_a_ccs/disk.d64 --cycles 100000000 --name ln1_injected --commands source/local/captures/ln1-bootstrap.mon
python tools/capture_reference.py source/local/last_ninja_the_side_a_ccs/disk.d64 --cycles 150000000 --name ln1_game --commands source/local/captures/ln1-start.mon
```

This launches the portable VICE executable externally. It creates an unpacked RAM image and snapshot from the supplied CCS edition. It bypasses the crack-title wait for extraction; it is not an acceptance replay. Exact paths are generated locally rather than storing user-machine paths in source code.

## Export and register

The LN3 opening-scene correction additionally needs the supplied LN3 capture:

```powershell
python tools/prepare_ln3_capture.py
python tools/apply_ln3_opening_correction.py
```

The preparation substitutes the crack-title space input and declines all six trainers, then loads the original level. It does not modify gameplay code. The single-scene script verifies the supplied dataset and expected original pixel hash before replacing only the three existing PNG files for that scene. Future full exports retain this approved correction; other colour candidates remain unapplied.

```powershell
python tools/decode_graphics.py
python tools/extract_ln1_actors.py
python tools/make_ln1_control_vectors.py
python tools/export_ln1_navigation.py
python tools/build_project.py
python tools/validate_project.py
./tools/compile.ps1
python tools/run_checks.py --runner 'C:/ProgramData/GameMakerStudio2-LTS2026/Cache/runtimes/runtime-2026.0.0.23/windows/x64/Runner.exe'
python tools/update_status.py
```

Use `build_project.py --refresh-graphics` only to deliberately replace already imported sprite edits. Replacement sound files are preserved. Runtime test reports are written only after executing the compiled project; structural tests alone do not stand in for a build or a gameplay comparison.

The current source format research utilities `inspect_reference.py`, `sprite_probe.py` and `unpack_probe.py` are exploratory tools. The first requires optional pefile/capstone packages and downloaded Integrator debug symbols; the latter two are local probes with hard-coded LN1 capture assumptions. They are not part of the export/build chain or the GameMaker runtime.

The optional wider colour audit uses `audit_scenery_colours.py capture`, `stage`, and `verify-staged`. Staging writes only to ignored `build/`; it never updates GameMaker assets. Its LN2 reference-renderer comparison requires pefile, capstone and Unicorn 2.1.4. Only selected renderer functions execute inside an isolated offline CPU sandbox, with model data supplied by Python. This is reference-renderer evidence, not proof of the supplied LN2 disk's pixels. `inspect_ln1_river_entry.py` records the original river approach and sinking evidence without editing project assets.
