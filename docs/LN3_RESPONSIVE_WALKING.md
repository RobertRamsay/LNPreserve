# LN3 responsive walking trial

Player walking now moves on every PAL tick rather than in one four-tick block. The recovered four-pixel movement is divided into one-pixel steps; fractional vertical movement is retained across ticks and cleared on release/direction changes. Normal speed over four ticks is unchanged. Idle/walk direction input is sampled on that faster clock, so releasing direction stops without queued travel.

Each small step uses the existing actor collision, solid boundary, drop contact and climbing checks. The normal four-tick update skips the already moved walking player, avoiding a double step. Enemy movement, combat, jumping, falling, weapon changes and animation sequence advancement retain their original clock. The held head/weapon artwork follows the torso between poses, and masking depth follows current feet. This is a gameplay-position change, not delayed visual interpolation. Drops still kill when deliberately crossed.

Changed: ln3_movement.gml (walking adapter and checks), ln3_collision.gml (optional actor filter, original default retained), ln3_play.gml (integration/reset), ln3_items.gml (test entry point).

Native checks cover all five levels: small-step speed, immediate stopping, movement between logic ticks, no doubled logic-tick movement, unchanged pose cursors, fire handling, walls and drop triggers. Original source comparison functions keep their original defaults. Whole-game manual playthrough and subjective feel remain playtesting tasks.
Validation: compilation and the 36-group full suite passed. After the final mask-position adjustment, LN3 walking/HUD/consumable/respawn/save checks passed again. Manual feel and a full playthrough remain unverified.
