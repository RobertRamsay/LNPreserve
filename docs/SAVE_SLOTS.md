# Local save slots

Ctrl+S adds a snapshot while playing. The right-hand panel holds ten entries, newest first; adding an eleventh removes the oldest from the list. Identical display names remain separate snapshots. Click a filled row to load, including switching to its game when needed. Saving and loading are disabled while F11 previews or F12 workbench are open. Holding Ctrl suppresses the S movement input.

Names combine game, level, lives and room: LN1_SAVE_1410 means LN1, level 1, four lives, room 10. There are ten slots shared across the three games. Files persist under GameMaker's local save directory in save_slots, not in the repository.

Snapshots retain native gameplay records, inventories, controls, health, positions, projectiles, active animations, encounter/progression state and simulation cycle. They exclude callable methods and GPU surface handles; a fresh game constructor provides a working clock and surfaces are recreated by drawing. Scene/mask sprites use names rather than build-specific numeric IDs. The LN1 player-to-world back-reference is excluded from JSON and restored on load, preventing recursive serialization and preserving pickup callbacks.

A new state file is written and parsed before the index changes. The index retains a backup and can recover from an unreadable primary file. Ten visible snapshots plus one previous-index recovery snapshot are retained. If both index copies are unreadable, saving is disabled rather than silently overwriting the list. The format is versioned but arbitrary future gameplay-schema compatibility is not guaranteed.

Structural checks pass in the cloud. Native selftest checks were added for JSON round trips in all three games, weapon/health/lives restoration, active LN1 animation, clock recreation, discarded surface handles and restored pickup linkage. These have not been executed here: GameMaker compilation and runner testing remain unavailable.

Windows checks: save while carrying a weapon, take damage/move, click the slot and check restoration; repeat in LN2 and LN3; restart the application and load again; create eleven saves and confirm newest ten; test repeated identical names, an active climb/projectile, and the right-side mouse hit boxes. Ctrl+S must not move the ninja down.
