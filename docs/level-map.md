# Level map

Open the room editor (F6), then **Level map**. Choose a game and level. The full overview occupies a 4:1 area; connection lines identify routes, and the connection list shows their direction. Selecting a line pulses its two endpoint rooms without labels over the thumbnails. Click a connection lane (or its list entry) to highlight its room sequence. Rooms use a staggered diamond arrangement inside the 4:1 overview. Double-click an original room to open its editor.

Choose **Insert blank on connection** to place a blank room before that connection's destination. Repeating this adds another room to the chain. Existing reverse exits traverse the same chain backwards; one-way exits remain one-way. Level exits and self-connections cannot have rooms inserted.

Select a blank thumbnail and use **Test Room (T/F5)** to walk through it. T/F5 returns to the editor. Blank rooms currently provide basic walking between their two ends; artwork, enemies, collision editing and full native actions inside these new rooms are future work. Original rooms retain their existing editor.

Double-right-click an inserted room, or use **Remove selected blank**, to reconnect its neighbours. Original rooms are protected from removal. Map edits have their own Undo/Redo history (Ctrl+Z/Ctrl+Y). Changes enable Modified mode. Switch Modified off to use the original connections.

Save/load uses the existing editor JSON file, with optional `maps` data alongside `scenes`. Older editor files remain supported. This is editor-file persistence; saving gameplay while inside an inserted room is not supported yet.

Map thumbnails currently show original room artwork. Connections come from the extracted room-exit records; separate scripted events are not general-purpose editable connections.

Right-click a lane involving an inserted room to remove that insertion and reconnect its neighbours. Between two inserted rooms, the endpoint nearest the click is removed. Original connections are protected. This operation supports undo/redo.

Inserted-room entry and exit sides now resolve from the adjacent original rooms' entrance/spawn records. Ninja spawns are inset safely, retain the neighbour's alignment, and face into the room. Test Room uses the same resolver. Chains preserve intermediate entry/exit continuity; one-way routes still prevent returning. Portal data is derived from the saved topology, so existing editor saves also receive this behaviour without migration.

Mouse wheel over the map zooms from the full overview (1x minimum) up to 8x, anchored under the pointer. Right-drag pans. Middle-click or both mouse buttons resets to the centered full overview. The map is clipped to its panel. Wheel over the connection list scrolls that list only. Right-click removal is processed on release, and is cancelled by panning. Thumbnail positions remain in map coordinates when zooming.
