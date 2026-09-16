# Level map

Open the room editor (F6), then **Level map**. Choose a game and level. The full overview occupies a 4:1 area; matching letter labels identify connections, and the connection list shows their direction. Click a connection lane (or its list entry) to highlight its room sequence. Rooms use a staggered diamond arrangement inside the 4:1 overview. Double-click an original room to open its editor.

Choose **Insert blank on connection** to place a blank room before that connection's destination. Repeating this adds another room to the chain. Existing reverse exits traverse the same chain backwards; one-way exits remain one-way. Level exits and self-connections cannot have rooms inserted.

Select a blank thumbnail and use **Test Room (T/F5)** to walk through it. T/F5 returns to the editor. Blank rooms currently provide basic walking between their two ends; artwork, enemies, collision editing and full native actions inside these new rooms are future work. Original rooms retain their existing editor.

Double-right-click an inserted room, or use **Remove selected blank**, to reconnect its neighbours. Original rooms are protected from removal. Map edits have their own Undo/Redo history (Ctrl+Z/Ctrl+Y). Changes enable Modified mode. Switch Modified off to use the original connections.

Save/load uses the existing editor JSON file, with optional `maps` data alongside `scenes`. Older editor files remain supported. This is editor-file persistence; saving gameplay while inside an inserted room is not supported yet.

Map thumbnails currently show original room artwork. Connections come from the extracted room-exit records; separate scripted events are not general-purpose editable connections.
