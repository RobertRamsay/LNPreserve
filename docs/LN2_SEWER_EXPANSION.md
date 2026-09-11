# Original Sewer routes and hazards

The experimental doorway links and additional gallery have been withdrawn. All 15 original scenes and the original 31-entry route table are retained. The existing progression, tool gate and level exit are unchanged.

Original false doors use boundary mode 24. The captured source dispatches this to $89bd, which calls $9b18 with A=2 and clears the boundary-crossing flag. Repeated contact drains health and leads into the ordinary death/life transition, rather than teleporting elsewhere. Scene 10 now requires contact deeper inside its openings; its early lip fallback is disabled. Other sensors retain their original contact handling. False doors: scene 7 left/right, scene 9 middle/right, scene 10 left/right, scene 12 right. Scene 6's narrow opening has original mode 22 (climbing), not mode 24, and is not turned into a lethal door.

Sewer flames still animate in scenes 0, 1, 3, 5, 10, 11 and 13.

Scene 10's rats use original action $b3c5 and frames 102-104. Their pixels sit 84-97 pixels above the actor origin, outside the previous 96-pixel canvas. A dedicated 256-pixel scenery canvas retains the complete shapes; masking uses their ground position (actor Y minus 72), matching the existing collision range. Original movement and damage remain.

Old shortcut saves keep their position and inventory but use the room's original respawn entrance. Saves inside the withdrawn gallery return to an original entrance in scene 10 or 12.

The focused --ln2-sewer-original-test covers all seven false doors, walking/death behaviour, visible rat animation/movement/damage and save migration. The complete suite retains original route comparisons. Automated room coverage is not a full manual playthrough.
