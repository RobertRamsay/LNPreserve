# LN1 Dungeons correction pass

The old special-actor resource contained stale images after its frame map expanded. The dungeon's 88 special poses are now regenerated with the supplied game's $7655 drawing routine, including the skeletons and spider. Ordinary guards use the original $777e uniform selection; this changes the first enemy sprite's colour independently of the other pieces. Identical uniform images share one PNG frame.

The spider's pursuit previously called the ordinary guard stance and replaced its animation. The original $be75 handler instead steers the current action through $6c89. The native dungeon handler now follows that behaviour, with 1,024 source-code comparison cases.

The original maze connections are retained. Several exits return to the same scene, and scene 15 has two exits facing SE. The numpad shortcut chooses the one nearest the player; move towards the desired doorway before pressing it.

For focused testing, F11 can select these dungeon scenes:

- 1: entrance, no guard.
- 2: first above-ground guard, source uniform selection 4 (C64 colour 3).
- 3: first underground guard, source uniform selection 5 (C64 colour 12, grey).
- 8, 11, 18, 21, 24: skeleton encounters.
- 20: giant spider.
- 23: level exit.

A route through the stored exits to the spider is:

1 → 2 → 3 → 4 → 5 → 6 → 11 → 10 → 13 → 9 → 12 → 14 → 17 → 18 → 15 → 16 → 20.

From scene 16, SW reaches 19; SW again reaches 23. Numpad travel is a testing shortcut and bypasses normal puzzle requirements. Reachability checks and isolated source comparisons do not establish a complete original-input playthrough or cycle accuracy.
