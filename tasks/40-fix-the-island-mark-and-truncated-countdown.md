# Fix the island mark and truncated countdown

Status: Source fix complete and verified; real iPhone rendering not verified. Commit authorised
by the user's standing instruction to commit when ready.

The user's iPhone photo shows a grey block where the app mark should appear and an ellipsis in
the compact countdown (`2:03:…`). The prior macOS offscreen render did not reproduce the iOS host.

The mark currently loads a 1024px asset declared at 1x into a 32pt view. Apple warns that images
larger than the Live Activity presentation may fail:
https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities

Use the existing 32px/64px app artwork in a correctly scaled asset for this slot. Keep the full app
icon unchanged elsewhere. Allow the compact timer to scale down within its current width rather
than widening the island. No timing behavior, release or device/simulator installation changes.

Verify asset dimensions and both widget/iPhone builds. Real iPhone rendering remains required to
confirm the grey block is gone; do not equate a build or macOS render with that check.

Verification executed:

- Asset JSON and linked PNGs checked: 32x32 at 1x and 64x64 at 2x, both RGBA, both 32pt.
- `scripts/verify-core-tests.sh`: 149 tests, zero failures (`tmp/island-photo-core.log`).
- `scripts/verify-widget-build.sh`: build succeeded (`tmp/island-photo-widget.log`).
- `scripts/verify-ios-build.sh`: build succeeded (`tmp/island-photo-ios.log`).
- `git diff --check`: passed.

The image uses original rendering and the timer uses minimum scale factor 0.6 inside the existing
48pt slot. The asset follows the existing shared-catalog symlink pattern to the small Mac artwork.
No device installation or release was performed. The oversized image is a documented failure risk
matching the photo, not a proven runtime diagnosis from the user's phone.
