# The App Store listing

The copy App Review reads. `scripts/appstore_listing.py` writes it to App Store Connect; nothing
else should, and least of all the web form — a change made there is a silent divergence from this
directory, and the next `--apply` will overwrite it.

One directory per platform, matching `--platform`. Plain text, one file per field, because a
description change should read as a prose diff:

| file | App Store Connect field | limit |
| --- | --- | --- |
| `keywords.txt` | keywords | 100 |
| `description.txt` | description | 4000 |
| `promotional-text.txt` | promotional text | 170 |
| `whats-new.txt` | what's new | 4000 |
| `review-notes.txt` | App Review notes | 4000 |

**A missing file means the field is not managed here** and is left as App Store Connect holds it.
An empty file is an error, because it reads as both "leave it alone" and "clear it".

`whats-new.txt` describes the release being prepared. Git history keeps the previous ones; App
Store Connect keeps them per version.

en-GB only — it is the app's only locale, and a second one would be a directory level rather than a
rewrite.

## The one rule

**No `F1`, `Formula 1` or `Formula One`.** `CLAUDE.md` makes this a non-negotiable and this
directory is the surface 4.1(a) is judged on: three Copycats rejections came off this app record.
`appstore_listing.py` refuses to write copy that trips the check, its selftest fails on copy already
committed here, and `appstore_status.py` reports any that reaches the store under NEEDS YOU.

The macOS keywords read `F1,Formula 1,schedule,spoiler free,menu bar,calendar,widget` until
2026-08-22 — nine days after the sweep that was supposed to have removed them, live on the store the
whole time. The sweep edited four surfaces by hand and there was no fifth place to look. This
directory is that place.
