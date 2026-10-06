# Scenery artwork editor

In the room editor, select an asset in the asset list and choose **Edit scenery artwork**.

- Pencil, eraser, flood fill and colour picker (also Alt-click).
- Ctrl+Z / Ctrl+Y undo and redo artwork changes, including palette conversions.
- Edit an existing asset to update all its placements in that game/level.
- Duplicate for an independent copy, or New asset for a transparent canvas. Apply, return to the room, then use Add selected asset.
- Original asset dimensions remain fixed. New/duplicated canvases resize in 8-pixel steps, up to 240 by 144.
- Apply to project installs the artwork and enables Modified. Back to room discards changes since the last Apply. Save file embeds all applied artwork alongside rooms, enemies, collisions and maps.

## Restrictions

| Mode | Pixels | Colours |
| --- | --- | --- |
| C64 Strict | HR 1x1 or MC 2x1 | C64 palette; bitmap HR two colours per 8x8 cell, MC shared background plus three colours per cell |
| C64 Loose | HR 1x1 or MC 2x1 | Any of the 16 C64 colours per cell |
| C64 HiRes | 1x1 | Full RGB |
| 16bit AMIGA | 1x1 | 4096 colours, 16 levels per channel |
| 32bit AMIGA AGA | 1x1 | Full 24-bit RGB |

Strict mode counts transparent pixels as the asset's inherited background colour. Switching modes converts the image; Undo reverses the conversion. The Amiga options constrain artwork colour precision, not emulated display hardware.

Artwork is scenery only. It does not edit character animations or game code. Original bundled assets remain unchanged. Optional `artworks` records in the existing version-1 scene JSON hold flat RGB pixels (-1 for transparent), dimensions and mode. Older scene files still load. New scenery IDs start at 10000. Project limits: 512 artwork records, one million pixels, 32 MiB file.

Native regression entry point: `--scenery-art-test`. Covers restriction enforcement, RGB composition, transparent underlay, original decoder isolation, all three games and project roundtrips.
