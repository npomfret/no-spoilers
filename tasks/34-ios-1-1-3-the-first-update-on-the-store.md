# Task 34: iOS 1.1.3, the first update to the iPhone app on the store

**Status: IN PROGRESS. Raised 2026-09-06.**

iOS 1.1.2 (build 10012, commit `ed1951b`) was approved on 2026-09-02, the first iPhone version to
reach the store. Everything since is on `main` and nothing of it has been submitted. The macOS
1.1.3 record went to review earlier today (task 26) from Xcode Cloud build 104; the iOS record
ships the same way from the same train.

## What the release is, measured

Since `ios/v1.1.2` the iPhone app, the widget extension and Core have taken 18 commits across 20
files. Four of them are what a user sees:

- Dark mode: every palette role has a dark value and the four light pins came off
  (`26a8656`, `116977a`). The app, the widgets and the Live Activity follow the system.
- The Live Activity was rebuilt (`e158a6f`, `bc04289`, task 33): wordmark and round, flag and
  Grand Prix, the session, and a `Text(timerInterval:)` clock; the system's material rather than
  a tinted card that hid the name in the other appearance.
- A stale Live Activity draws the next phase (`ab165b0`): live gone stale is *Finished*,
  upcoming gone stale is *In Progress*, instead of the phase the app last pushed.
- The widget reloads once on the first launch of a new build (`7575a5c`).

Nothing else the user sees changed. Entitlements are unchanged. The `1.1.3` train already holds
the local build 10023 from before task 32; the Xcode Cloud runs since are 101–112.

## The record

**Build 112**, Xcode Cloud run 112, `sourceCommit bc04289` = the pushed `HEAD`, `VALID`, 1.1.3.
Chosen over a `Publish iOS` press for the reason 104 shipped on macOS: it is the tree as
committed, already uploaded and processed, and the note names its commit.

`listing/ios/whats-new.txt` exists from this version, as `listing/README.md` said it would from
1.1.3 onwards. `review-notes.txt` no longer describes a 4.2.2 return or corrects earlier notes;
the app has been approved since.

The six listing screenshots on 1.1.2 were taken on 2026-08-25. The medium widget went to three
sessions on 2026-09-02 (`ed1951b`), so the two medium images show a layout that no longer ships.
All six are retaken from this checkout's build.

## Verification

- [x] `appstore_listing.py --platform ios --version 1.1.3 --create --build 112 --apply`, 2026-09-06:
      record created `PREPARE_FOR_SUBMISSION`, promotional text, what's new and the notes written,
      keywords and description already correct, build 112 attached, no trademark hits
- [x] Six screenshots retaken with `screenshots.py` from this checkout's simulator build into
      `tmp/screenshots/1.1.3/`, each looked at (fixture data, widget present, medium at three
      sessions), then uploaded with `appstore_screenshots.py --platform ios --replace --apply`,
      2026-09-06
- [x] Build 112 in the Internal group (`testflight_distribute.py --platform ios --build 112 --apply`,
      2026-09-06; the *What to Test* note names `bc04289`)
- [x] `scripts/verify-python-selftests.sh` green, 2026-09-06 (206 cases across six scripts)
- [x] Submitted, approved, and `READY_FOR_SALE` on both platforms 2026-09-07
- [x] `tag_approved.py ios 1.1.3 --apply` and `macos 1.1.3 --apply`, 2026-09-09:
      `ios/v1.1.3` on `bc0428933c11` (build 112) and `macos/v1.1.3` on `dc2f283919d3`
      (build 104). Neither had a `build/N` tag — both were Xcode Cloud builds — so the commit
      came from each build's own TestFlight note, which is what `note_commit` was added for
