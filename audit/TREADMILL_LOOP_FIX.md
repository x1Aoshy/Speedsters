# Treadmill farming / speed popup regression

Compared the actual `output/+1 Speedster Escape OGGG.rbxl` with all three root Update3 places. Their TreadmillTraining and SpeedsterClient sources matched the canonical sources before editing.

## Cause and change

- `onTreadmillPartTouched` referenced `addSpeed` before its local declaration. Luau resolved that reference as a global (nil). The handler advanced `lastSpeedGrantAt` before throwing, so repeated foot contacts could keep postponing the occupancy loop without crediting speed.
- Forward-declared the local grant function and made touch and polling share one grant helper. Only successful grants consume the 0.5-second cooldown (the OG cadence); concurrent callbacks cannot double-grant. An unloaded profile can retry at the next sample. Touch grants require a living character inside the belt zone.
- The client reduced every treadmill burst to 6 desktop / 4 mobile popups. Restored the configured desktop tier counts, allowing the newer 28-popup profiles, and OG's 8-popup mobile ceiling. Existing color, shoe icon, flight to the progress bar, impact and HidePopups behavior are retained.

## Validation

- `audit/test_treadmill_loop_regression.luau`: reproduced the original nil-function error and consumed cooldown from extracted saved-place code, then passed immediate entry, stationary farming, repeated touches plus polling at 0.5-second cadence, profile retry, reentrant calls, locks, dead characters, belt footprint, desktop bursts 1–28 and mobile budget 8.
- `audit/test_popup.luau` with the canonical SpeedsterClient path: simulated shoe creation, tween target, progress-bar impact and HidePopups passed. Updated its mocks to support the current client dependencies.
- `audit/build_treadmill_loop_regression.luau`: compiled both changed scripts, serialized and deserialized all three worlds, checked unchanged instance counts and exactly two changed scripts per world. Root .rbxl files and separate fixed copies saved; originals backed up. Paths are recorded in `audit/treadmill_loop_fix_report.json`.

No Roblox Studio playtest or live publication was performed. Reopen the corrected files in Studio to load the on-disk changes; an already open Studio session retains its previous in-memory scripts.
