# Sources and provenance

## Supplied originals

The user supplied `last_ninja_the.zip`, `last_ninja_2_the.zip` and `last_ninja_3_the.zip`. Their hashes, eight disk images, directory entries, file-byte hashes and exact sector chains are recorded in [disk_inventory.json](../evidence/disk_inventory.json). Original archives, disk copies, program payloads and emulator snapshots remain in ignored local storage.

No instructions embedded in game files, crack screens or reference documents are treated as user instructions.

## Scenery references

[Luigi Di Fraia's Integrator 2012](https://www.luigidifraia.com/software/) provides reference scenery datasets for the three games. Version 1.5.2 inputs are pinned in `tools/fetch_references.py`; each exported dataset records its input filename, hash and source URL.

The original conversion tool was used for format research. This repository's decoder is Python written for the conversion. No Integrator executable or tool runtime is shipped with the GameMaker project.

- LN1 levels 2–6: the complete reference payload after the two-byte PRG header matches `6B`–`6F` in the supplied CCS disks. Disk load headers differ from the actual in-memory placement.
- LN1 level 1: 19,456 bytes at `$0800–$53ff` match the original memory captured after booting the supplied CCS program. The reference's earlier `$0600–$07ff` prefix is not covered by this comparison.
- LN2/LN3: reference datasets only; exact matches to the supplied disk editions remain unverified.

## Original-code extraction and verification

[VICE 3.10 x64sc](https://vice-emu.sourceforge.io/) is used externally as the original-machine reference. The [official Windows release](https://github.com/VICE-Team/svn-mirror/releases/tag/3.10.0) is pinned by hash. It is not a dependency of the GameMaker runtime.

The LN1 extraction capture loads the supplied CCS PRG at its original address, runs its unpacker and bypasses the crack-title fire wait by setting the PC to the instruction immediately after that wait (`$c89b`). This is an extraction aid, **not** a valid unchanged-input gameplay replay. The gameplay bytes being examined are retained unchanged. The capture uses the VICE PAL defaults, including MOS8565/MOS8580; a final reference model still needs an explicit acceptance specification.

The recovered sprite decoder lives at `$7e36–$7e77`, with pointer-byte tables at `$8000` and `$80c0`. Its 192 entries expand into 63 displayed bytes each. `$a0` escapes a literal; `$a1–$af` encode zero runs. Entries 189 and 190 write zero padding beyond the displayed bytes before returning. The native translation preserves the loop's instruction count, including this detail.

The recovered selection routine is `$6eac–$6f6c`. [py65](https://github.com/mnaberez/py65) executes the original bytes offline to generate reference results. Calls to `$63cb` and `$69e4` are intercepted at the boundary for this isolated test. Neither py65 nor a CPU interpreter is included in the native game.

The [VICE PAL constants](https://github.com/VICE-Team/svn-mirror/blob/main/vice/src/c64/c64.h) supply the clock transport's machine constants. The [GameMaker file-system documentation](https://manual.gamemaker.io/lts/en/Additional_Information/The_File_System.htm) describes the sandbox used for native test screenshots.

## Music

Known SID subtune labels were checked against the HVSC metadata displayed by SLAY Radio: [LN1](https://www.slayradio.org/sidinfo/MUSICIANS/D/Daglish_Ben/Last_Ninja.sid), [LN2](https://www.slayradio.org/sidinfo/MUSICIANS/G/Gray_Matt/Last_Ninja_2.sid), and [LN3](https://www.slayradio.org/songinfo/6350). Unknown mappings remain unset rather than guessed. The original compositions are not synthesized or replaced here: the user-authorized sound assets are silent placeholders.

The original games and reference materials retain their respective authorship. No claim of authorship over original game graphics, music or 6502 program bytes is made. Downloaded reference tools are kept outside version control.
