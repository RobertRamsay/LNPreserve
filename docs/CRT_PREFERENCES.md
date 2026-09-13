# CRT preferences

LNPreserve.ini in the GameMaker user save directory stores the [CRT] section.
The enabled state, pixel blur, honeycomb strength, scanline strength, width,
alignment, softness and selected preset are restored at launch.
Changes save after mouse release, and pending changes flush on exit.
Missing keys use the existing defaults; numeric values are clamped to UI ranges.
Automated command-line checks do not load or overwrite personal preferences.
The INI is independent of saved games and rewind history.
