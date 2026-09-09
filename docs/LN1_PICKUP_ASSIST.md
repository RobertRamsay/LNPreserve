# Testing controls and LN1 pickup assistance

Scene-test exits now use numpad 7 NW, 9 NE, 1 SW, 3 SE (Num Lock on), leaving the arrow keys free of room travel. Existing recovered exit selection and nearest-door behaviour remain.

F11 switching to a different level restores full health in all three games. Entering LN1 level 2 additionally grants the sack, sword, nunchakus, five shuriken, three smoke bombs and four lives. Selecting another room in the same level does not repeatedly refill the kit. Ordinary progression still carries inventory and restores health through its existing code.

LN1 fire alone (# with no movement keys) can assist an uncollected nearby item. It chooses the nearer of the source interaction rectangle's two facing positions, at most 20 source pixels horizontally and 16 vertically. A pixel-step boundary probe rejects crossed walls and special boundaries. The ninja faces the item and uses the existing unarmed crouch action; collection waits until the reaching pose has been held for four ticks. The weapon is restored afterwards. Damage interrupts the assistance. Existing sack requirements remain; scripted mechanisms and scroll progression retain their original controls.

These are requested conveniences, not claims of original input fidelity. No new artwork is used. Native checks were added for delayed sack collection, weapon/input restoration, distance rejection, blocked movement and the Wilderness kit. Structural checks pass; GameMaker compilation, native tests and visual hand-to-object alignment remain pending on the user's Windows runner. In particular, please test small/raised pickups and both facing sides with the edited ninja art.
