# Fix the Dynamic Island display

The user’s iPhone photo shows the No Spoilers Live Activity in the Dynamic Island with a grey
block where the app mark should appear and a truncated countdown reading `2:03:…`.

The display does not clearly identify the app, and the countdown cannot be read in full.
The user described it as not feeling right. Earlier, they also reported difficulty seeing the
phone’s clock while the activity was present; the supplied photo does not establish its cause.

Status: complete.

- `5b6eb73` replaced the 1024px mark with a 32pt 1x/2x asset and let the countdown shrink to
  0.6 within its 48pt slot. The user ran it on their iPhone and reported it looks better.
- Added `mark@3x.png` (96×96, downscaled with `sips` from the 1024px master icon; no 96px source
  artwork exists to symlink), so Dynamic Island devices (all 3x) no longer upscale the 64px image.

Verification: `scripts/verify-widget-build.sh` and `scripts/verify-ios-build.sh` succeeded
(`tmp/island-3x-*.log`); `git diff --check` passed.

Residual risk: the 3x asset has not been seen on the iPhone. The clock-visibility report was not
investigated; the user retired the task without reporting it again. The 3x PNG is a copy, not a
symlink, so it will not follow future changes to the icon artwork.
