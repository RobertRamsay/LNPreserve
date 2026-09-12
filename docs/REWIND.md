# Rewind prototype

Hold Left Arrow during gameplay to rewind; release to continue from that point.
Movement stays on WASD / controller. The display shows REWIND while held.

- Available in LN1, LN2 and LN3.
- Retains up to 100 snapshots, sampled about every 100 ms of running game time
  (roughly 10 seconds). Rewinds one snapshot per 50 ms, approximately double speed.
- Memory only: no save files are written. Compressed history is capped at 32 MiB.
- Restores player pose, enemy state, health, lives, inventory, scores, puzzle flags,
  native random state, animation timers and mutable room/collision data together.
- Releasing discards future input events and continues a new branch. Existing
  disk saves remain independent.
- Clears on scene entry (including respawn), game/level changes and save loads.
  Menus suspend it; title screens and intro/outro movies do not record history.
- Pauses music during rewind and resumes it according to the restored mute state.
  This version does not rewind the audio recording itself.

## Implementation and verification

ln_rewind.gml snapshots native mutable state in-place, without running the disk
save migrations or reloading a level on each rewind step. Fixed source animation,
sprite and mechanism tables remain shared. Mutable data.initial and boundaries,
world/scene records, and gameplay state are captured. The LN1 player back-reference
is detached only for synchronous JSON encoding and immediately restored, including
on failure. Render surfaces are regenerated and native aliases are reconnected.

Run --rewind-checks with the built Runner for whole-state roundtrip and deterministic
forward replay checks across all 18 levels, plus history/input boundary checks.
Results: evidence/rewind_checks.json. These automated checks are not a manual
playthrough or exhaustive puzzle coverage. Snapshot recording and reverse playback
still need the user's playtest, particularly during combat, pickups and deaths.
