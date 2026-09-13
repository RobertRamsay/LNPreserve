# Scene build-up editor — experimental first version

Press **F6** to open or close the editor. The live game pauses while it is open.
The F11 menu also shows this shortcut. Existing local project changes are preserved.

## Working with a room

Choose Ninja 1, 2 or 3, then a level and source room ID. IDs are explicitly labelled;
they can differ from the numbered scenes in F11, especially in LN2 and LN3.
The import expands nested source panels into their original leaf-part order.
The browser includes 293 existing room records across all 18 levels. An empty
source panel opens as an empty canvas; this is not proof that every original
runtime room has been faithfully reconstructed.

Select a part in the list. Up/Down changes its draw order; Remove/Delete removes
it. Choose an asset from the thumbnail list and click Add selected asset.
Left-drag the selected part, or use arrows (two bitmap pixels horizontally,
one vertically). Shift makes larger steps. Right-drag positions the actual
game's ninja pose in the preview. Flip X mirrors a part.

Build preview starts with the room's background colour, then draws the list.
The speed buttons use the same saved 0.1x–4x setting as F11 scene painting.
Modified builds use 80 ms per leaf part at 1x; this is an editor preview cadence,
not a claim about the Commodore's instruction timing. Original mode retains the
existing source-recorded construction timing.

## Depth

Draw order controls scenery composition. Each part separately has Ground,
Depth or Always front mode. In Depth mode the +/- controls set its ground-contact
line; the ninja passes behind its opaque pixels while above that line and in
front below it. Depth line displays the selected line in the preview.

Imported parts initially use Ground. Original depth masks are not automatically
decomposed into part masks. Assign depth to props in the editor and use the ninja
preview to check them. The runtime uses the edited mask for LN1/LN2 actors and
LN3 character fragments. This is manual authoring support, not an automatic
scene-depth solver.

## Files and Modified mode

Save file writes a version-1 `LNPreserve-scenes` JSON pack containing keyed
game/level/room overrides, source asset IDs, positions, recolours and depth
settings. Load file validates a pack before replacing current edits. Invalid
files leave the current pack intact. Up to 30 changes in the current room can
be undone. Save before loading a different pack if you want to retain both.

Edits are also backed up to `modified-scenes.autosave.json` in GameMaker's save
directory (normally `%LOCALAPPDATA%/LNPreserve`). Recover loads that backup.
The original source files and PNG assets are never rewritten.

Use room enables the current room override. Modified ON applies saved overrides
when playing those matching rooms; other rooms use their original rendering.
Selecting a room in the editor does not teleport the live game. Use F11 to enter
another room for a gameplay test. Modified defaults OFF at application startup;
load a custom pack and enable it to play it in a later session.

Modified backgrounds are built from source assets and cached in a surface.
The original PNG is still used by Reference and to isolate changed pixels in
legacy full-room mechanism/animation frames. Those delta pixels are overlaid
at their original positions; the original full-room frame cannot overwrite
the custom background. Those mechanisms are not yet editable part-list items.

## Current limits

- Source colour/attribute merging is diagnostic and can differ from the original
  C64 result. Nested-panel mirroring and unresolved source records are not yet
  fully recovered. Reference shows the preserved room for comparison.
- This is a visual editor. Collision boundaries, routes, hazards, item positions,
  enemy placement and interactions retain their original coordinates. Moving a
  wall or floor visually does not move its gameplay boundary.
- Ninja depth is editable; not every projectile-specific mask is covered yet.
- A legacy mechanism left at its original location can conflict with substantially
  rearranged scenery. Mechanism editing and collision editing need their own stage.
- In-between rooms, map wiring, external graphic imports and unrestricted reskins
  remain future work, as requested.

## Verification

Build with `tools/compile.ps1`. Run `tools/check_scene_editor.py --runner <Runner.exe>`
for the independent editor checks. It writes `evidence/scene_editor_checks.json`.
Run the existing `tools/run_checks.py --runner <Runner.exe>` for gameplay regressions.
Automated room import coverage is separate from a full manual playthrough and
does not establish pixel-for-pixel source parity or correct depth in every room.
