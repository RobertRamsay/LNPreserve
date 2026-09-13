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

Alt-click a visible part on the canvas to select it and highlight its asset in the browser, or select a part in the list. Background pixels select nothing. Picking does not move a part. Up/Down changes its draw order; Remove/Delete removes
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

Draw order controls scenery composition. Each part separately has Inherited, Ground,
Depth or Always front mode. In Depth mode the +/- controls set its ground-contact
line; the ninja passes behind its opaque pixels while above that line and in
front below it. Depth line displays the selected line in the preview.

Imported parts inherit original masking. A per-part override replaces native
masking on that part's visible pixels in both preview and play. Ground clears
occlusion; Inherited restores the original behavior. LN3 native masks are
regenerated at the ninja position. Untouched rooms show the preserved bitmap;
edited rooms show their rebuilt composition. Original masks are not automatically
decomposed into separately movable part masks.

## Files and Modified mode

Save file writes a version-1 `LNPreserve-scenes` JSON pack containing keyed
game/level/room overrides, source asset IDs, positions, recolours and depth
settings. Load file validates a pack before replacing current edits. Invalid
files leave the current pack intact. Up to 30 changes in the current room can
be undone. Save before loading a different pack if you want to retain both.

Edits are also backed up to `modified-scenes.autosave.json` in GameMaker's save
directory (normally `%LOCALAPPDATA%/LNPreserve`). Recover loads that backup, replacing the current editor pack with the latest autosaved scenes. It does not undo Git changes or reset the original game. Use Save file first if you want to keep the current pack separately.
The original source files and PNG assets are never rewritten.

Test room enables the current edited room and starts it through normal F11 scene selection, closes the editor, and plays its level music (respecting mute). F6 returns to the retained edits. Rooms without a playable spawn remain in the editor with an explanation. Modified ON applies saved overrides when playing matching rooms; other rooms keep their original rendering. Merely browsing rooms in the editor does not teleport the live game. Modified defaults OFF at application startup;
load a custom pack and enable it to play it in a later session.

Modified backgrounds are built from source assets and cached in a surface.
The original PNG is still used for untouched room previews and to isolate changed pixels in
legacy full-room mechanism/animation frames. Those delta pixels are overlaid
at their original positions; the original full-room frame cannot overwrite
the custom background. Those mechanisms are not yet editable part-list items.

## Current limits

- Source colour/attribute merging is diagnostic and can differ from the original
  C64 result. Nested-panel mirroring and unresolved source records are not yet
  fully recovered. Native depth masks stay at their original coordinates; moving
  a source prop does not relocate those inherited masks automatically.
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


## Editor comfort controls

- Original depth is inherited per part and can be overridden. There is no global original-depth switch or status label.
- Added assets are selected and scrolled into view at the bottom of the parts list.
  New parts use an opaque-pixel overlay so native source priority cells cannot silently hide them;
  transparent pixels remain transparent. Their depth starts at their base, and is editable.
- Hold depth minus/plus to repeat; repetition accelerates after about a second.
  Click the depth number to type a whole number, Enter to apply, Escape to cancel (0–144).
- Music pauses on entering F6 and resumes on leaving; music already paused stays paused.
- JANSINA UI font is now 14 points, with its cached glyph atlas rebuilt from the installed font.


## Preview speed, CRT and fullscreen

Dragging caches decoded asset pixels and redraws only the affected destination cells.
The preview surface and camera are reused. Preview masks upload directly as textures;
they do not create sprite readbacks. Each completed drag produces one undo entry,
and autosave waits until the drag is finished.

Editor CRT has a separate ON/OFF button and F10 shortcut. It shares CRT tuning with
the game but saves its own state under `[Editor] crt_enabled` in LNPreserve.ini.
Only the scene preview is filtered: selection outlines, depth guides and editor
panels remain sharp. The gameplay CRT toggle is unchanged by entering or leaving.

F9 or the Fullscreen button toggles borderless fullscreen in the game or editor.
Toggling back restores the previous window size and position. Fullscreen now
continues across scene, intro/outro and editor changes until explicitly toggled off.

The drag regression compares full colour, visible-part ownership and depth arrays
for 18 partial/full rebuilds across all three games. Its timing is a synthetic
sample, not a guaranteed frame rate for every room or asset size.


## Widescreen tool and history

The project presents a 1920 × 1080 canvas using `spr_LNHDbkg` as the optional
background. The preserved tool content is centered without stretching its pixels.
1x is 1920 × 1080; 2x is 3840 × 2160. An exact-display preset uses borderless
fullscreen to avoid clipping by Windows borders. Fit chooses the largest whole
scale that fits, or reduces below 1x on a smaller desktop. F9 still toggles fullscreen.

U / UI toggles outer controls; the game retains its built-in HUD, and the editor
shows its centered scene preview. B / Background toggles the supplied artwork.
When gameplay UI is off, every button is hidden; press U to restore it. F6 always shows the full editor UI, and returning to play preserves its prior UI setting. Both visibility preferences
persist in the Tool section of LNPreserve.ini. Depth-number entry ignores U/B.

Ctrl+Z undoes and Ctrl+Y redoes in the editor; Undo and Redo buttons are also present.
Each drag is one action. A new edit discards the redo branch. History stays local
to the current room and is not stored in the custom scene pack.

`tools/check_tool_layout.py --runner <Runner.exe>` checks the widescreen presentation,
editor histories and Test room in all three games, CRT, presets, fullscreen and
save panel. Component fixtures keep legacy source coordinates; the dedicated
layout fixture exercises the actual centered compositor and visibility states.


### Per-part depth overrides
Imported parts inherit the exact native masking until their depth is edited. The original-depth status has been removed. Typing a depth (even the displayed value) or using + / - selects Depth automatically. The mode button cycles Inherited → Depth → Always front → Ground → Inherited. Ground explicitly clears native occlusion on the part's visible pixels; Depth replaces it with the chosen ground-contact line. Other pixels retain native masking. The displayed initial number is the part's base, not a claim that the original per-pixel mask is a single flat line.

Overrides are saved with the custom scene and participate in Undo/Redo. The editor and Test room use the same replacement rule for all three games. Original masks outside visible overridden part pixels are retained; this is not a reconstruction of the original masks as independently movable objects.


### Selected part pulse
`pulseSelected?` (on by default) highlights the selected placed part once per second: original colour → white → original colour over 0.1 seconds total. The pulse follows its visible pixel shape, preserving transparent holes and parts drawn over it. It is editor-only, works with editor CRT, and does not change saved room artwork or depth. Click the toggle below the preview to disable it.
