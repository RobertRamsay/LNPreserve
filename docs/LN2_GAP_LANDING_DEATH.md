# Scene 12 chasm landing death

The seven-step drop now leads into the existing LN2 death poses (44, 45, 46), with the original facing. Health is depleted on landing, and the HUD spiral drains while the death animation plays. The body remains at ground depth and at the landing position until the ordinary one-life-loss respawn. Water splash and other falling sequences retain their prior behaviour.

Changed files: LNPreserve/scripts/ln2_levels/ln2_levels.gml, obj_ln_preserve Create/Draw test hooks, and tools/run_focused_checks.py. No new artwork was needed.

Validation: build passed; all 12 focused checks passed. The new regression covers four facings at 1, 22 and 44 health, complete death poses, visible body throughout health drain and respawn delay, and exactly one life lost. The rendered result is in evidence/ln2_gap_landing. The full suite was not rerun for this targeted change; no full manual playthrough is claimed. No commit or push was performed by the assistant.
