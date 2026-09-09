# Shared graphics and character replacement

The original pixels, colours, animation records, logical frame order and mirror
selections are preserved. This is asset consolidation, not new artwork.

## Editing characters

`LNPreserve/datafiles/graphics/characters.json` is the central character map.
Its `types` section groups LN1 ninja/guards, LN2 ninja/enemy costume types,
LN1 special actors and LN3's already-shared parts. Numeric LN2 costume names
come from original data; they are not newly invented enemy classifications.

GameMaker's **Graphics / Characters** folder contains the consolidated pools.
`banks` retains old bank names as logical identifiers, with the same number
and order of frame references. These names are no longer separate sprites.
Each bank's `poses` indexes the top-level `poses` list, whose entries identify
the physical sprite and frame to edit. Identical poses can be shared by more
than one weapon, level or character type.

For example, resolve `banks.spr_ln1_player_weapon_0.poses[0]` into `poses` to
find the ninja's first physical frame. LN2's type/level groups identify its
normal, weapon and extra-pose banks. Enemy types use the original costume ID.

Editing a shared physical frame changes every character using it. To replace
one type independently, add an entry under that type's `overrides`, keyed by
the logical bank name. Supply `sprite` (your registered replacement sprite)
and `frames` (one replacement frame index for every original logical frame).
Populate all relevant weapon/extra banks for a complete replacement. The
renderer checks the requested type's override before resolving shared art.
An empty override table keeps original shared graphics.

LN1's guard colour bank and special-actor banks remain intact and are listed
under `ln1_specials`. LN3 already uses one deduplicated part bank; its part,
palette and costume mappings remain in each level's world data. Projectile
body-part banks and special effects also retain their existing mappings.
Those part-based render paths do not use the new assembled-character override
hook: a complete redesign must update their parts as well. They are not
silently replaced by an assembled walking/fighting sprite.

## Cleanup and validation

`evidence/graphics_cleanup.json` lists resource aliases and removed included
PNG copies. Only exact pixel matches were shared. Whole-resource sharing also
compares metadata, frame ordering/timing and editable layer images. Character
pooling refuses nonstandard layered/timed banks instead of flattening them.

73 character banks become 11 pools. All 7,376 logical character frames were
compared with their new physical pixels; 4,358 unique poses remain, removing
3,018 repeated frames. Thirty other identical sprite resources are replaced
by references. GameMaker's required composite/layer PNG pairs remain.

Unused PNG copies under `datafiles/play` are removed only when an identical
editable sprite survives. Referenced graphics-manifest images remain available
to the workbench and validation tools.

Run `python tools/validate_project.py` for resource, image and character-map
checks. Original GameMaker GPU tests still need running locally after this
refactor. No new GameMaker compilation or GPU result is claimed here.

`cleanup_graphics.py` is the one-time migration and refuses to run over an
existing map. Older original-data exporters may recreate legacy banks; review
their output and update the logical mappings when regenerating art. Do not
treat a full re-export as a safe way to preserve later hand-edited characters.
