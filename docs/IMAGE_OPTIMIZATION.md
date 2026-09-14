# Image optimisation — September 2026

22 reviewed character/effect sprite banks use the `CroppedActors` texture group. GameMaker removes fully transparent borders during texture packing, while editable PNG canvases, origins, collision bounds, frame numbering and animation data stay unchanged. This avoids changing drawing code or source graphics. About 70.8 million transparent frame pixels are excluded before atlas packing; this is not a measured GPU-memory saving, because packing, borders and page sizes also matter.

The Default group remains uncropped. Native depth masks and original scene bitmaps are sampled with full-bounds shader coordinates and must retain that setting. Do not globally enable cropping. The resource validator checks world depth-mask assignments.

Removed `spr_ln2_level2_room_08_state1` (resource and its composite/layer PNG pair): it was an obsolete Street bottle-room state, superseded by `spr_ln2_street_bottle_states`. Code and gameplay JSON no longer reference it. Other apparently unused status-icon and mechanism sprites are referenced through dynamically constructed names and are retained.

No unused included PNGs with an identical surviving sprite and no code/data filename reference were found. GameMaker composite/layer image pairs are required for editing and are not redundant. User artwork and font backup files remain intact. LN1 asset 41 remains untouched; malformed original data should not be silently substituted during storage cleanup.

The compiled `.win` changed from 757,105,300 to 757,086,452 bytes (18,848 bytes smaller). Transparent image regions compress well, so texture packing is the main benefit, not a large file-size reduction. See `evidence/image_optimization.json` for the exact sprite list and validation results.

GameMaker cropping documentation: https://manual.gamemaker.io/lts/en/Settings/Texture_Groups.htm
