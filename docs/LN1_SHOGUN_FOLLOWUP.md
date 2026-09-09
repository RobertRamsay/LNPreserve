# Shogun hurt pose and scroll-room progression

The reported LN1 Inner Sanctum faults shared a missing special combat branch.
Generic guard reaction tables were used for actor 136. The original level-six
$4cdf handler instead chooses $50c7 on a surviving hit and $507e on defeat,
with action mirror set to facing & 4. Defeat sets enemy mode 7 and preserves
its existing separation value, unlike the ordinary guard branch.

The native branch now follows those decisions. Two omitted $50c7 action records
are recovered from the supplied original: pose 158 for 24 ticks, then pose 150
with event 33. Existing original art covers both; no images were changed.

The already recovered $507e sequence uses poses 158–160 and events 39/40.
Event 40 sets player position (1,128); original $7478 then selects entry 60
from room 14, reaching room 15 (the scroll room) in the same level. Restoring
the defeat sequence connects this existing travel path without changing exits.

`python tools/check_ln1_encounters.py` passes 32 original hurt/defeat states
across eight facings, verifies the recovered records and confirms that exit.
Updated native integration checks exercise hurt pose and sequence-to-room-15
travel. They have not run here: GameMaker compilation, GPU testing and full
encounter replay still require the user's Windows runner. The user will test
and relay results; no remote PC-control connection is currently available.
