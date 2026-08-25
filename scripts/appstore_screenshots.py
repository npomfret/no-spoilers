#!/usr/bin/env python3
"""Put screenshots on an App Store version, and refuse the ones Apple would.

**The last listing surface that only existed in a browser.** `listing/*.txt` and
`appstore_listing.py` ended that for the words on 2026-08-22; the images stayed
a drag-and-drop into a web form, which is the same condition — nothing could
check them, diff them, or say which build they were taken from. This is that
step for the pictures.

## What it refuses, and why each one has happened

**A size the version's slots do not hold.** App Store Connect keeps one set per
`screenshotDisplayType`, and an image of the wrong shape is refused at upload
after the reserve has already been made — leaving an empty `appScreenshot`
behind that counts as a screenshot and blocks a submission without appearing in
the web form. The display type is therefore derived from the PNG's own IHDR
rather than trusted from a filename, and an unmapped size stops the run before
anything is reserved.

**A file that is not a PNG**, for the same reason: the checksum and the reserve
both succeed on a JPEG and the commit is what fails.

## What it does not do

**It never submits, and it never touches the words.** `appstore_listing.py`
owns those, and a tool that wrote both would make "fix a typo" and "replace
every image" the same command.

**It does not reorder.** Apple shows screenshots in the order they were
uploaded, so order is argument order and there is no second way to express it.

Usage:
    scripts/appstore_screenshots.py --platform ios tmp/screenshots/*.png
    scripts/appstore_screenshots.py --platform ios --replace --apply tmp/…/*.png
    scripts/appstore_screenshots.py --selftest
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
import urllib.error
import urllib.request
from pathlib import Path

import appstore_status as asc
from asc_write import Session

LOCALE = "en-GB"

# Pixel size to the display type that holds it. **Read off the app record on
# 2026-08-25 rather than from Apple's documentation**, because the doc comment
# in `screenshots.py` had a year-old list and sent two capture runs at a slot
# this app does not have. Add a row only after checking the record holds it:
# a wrong guess here is an upload that is refused after the reserve.
DISPLAY_TYPES = {
    (1242, 2688): "APP_IPHONE_65",
    (1284, 2778): "APP_IPHONE_65",
    (1290, 2796): "APP_IPHONE_67",
    (1320, 2868): "APP_IPHONE_69",
    (2048, 2732): "APP_IPAD_PRO_3GEN_129",
    (2064, 2752): "APP_IPAD_13",
}

# The states whose screenshots App Store Connect will still accept. Same list as
# `appstore_listing.py` keeps for the words, and for the same reason: a
# READY_FOR_SALE version's images shipped and cannot be edited.
EDITABLE = (
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
)


def png_size(data: bytes) -> tuple[int, int]:
    """Width and height from a PNG's IHDR, or a refusal.

    The first chunk of a PNG is always IHDR and always at the same offset, so
    this is eight bytes at 16 rather than a parser. Anything else is not a PNG,
    which is worth catching here: the reserve and the checksum both succeed on a
    JPEG and only the commit fails, by which point there is an empty screenshot
    on the listing.
    """
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    if data[12:16] != b"IHDR":
        raise ValueError("PNG has no IHDR where one must be")
    width, height = struct.unpack(">II", data[16:24])
    return width, height


def display_type(size: tuple[int, int]) -> str:
    """Which set an image of this size belongs in.

    Fails loudly rather than guessing a nearest match. A screenshot half a slot
    out is not a screenshot for that slot, and the API's refusal names neither
    the file nor the size.
    """
    try:
        return DISPLAY_TYPES[size]
    except KeyError:
        known = ", ".join(f"{w}x{h}" for w, h in sorted(DISPLAY_TYPES))
        raise SystemExit(
            f"no display type for {size[0]}x{size[1]}.\n"
            f"Sizes this knows: {known}\n"
            "If App Store Connect really holds a slot this shape, add it to DISPLAY_TYPES "
            "after reading the display type off the app record — not from the documentation."
        )


def plan(paths: list[Path]) -> dict[str, list[tuple[Path, bytes]]]:
    """Group the files by the set they belong in, keeping argument order.

    Every file is read and measured before anything is uploaded, so a bad file
    at the end of the list stops the run instead of stranding a half-replaced
    set — which, with `--replace`, would mean a version whose old screenshots
    are deleted and whose new ones are not there.
    """
    grouped: dict[str, list[tuple[Path, bytes]]] = {}
    for path in paths:
        if not path.is_file():
            raise SystemExit(f"not a file: {path}")
        data = path.read_bytes()
        try:
            size = png_size(data)
        except ValueError as error:
            raise SystemExit(f"{path}: {error}")
        grouped.setdefault(display_type(size), []).append((path, data))
    return grouped


def _upload(operation: dict, data: bytes) -> None:
    """Run one of the upload operations the reserve handed back.

    Not through `Session`: these go to a different host, carry their own headers,
    take bytes rather than JSON, and must not carry our bearer token.
    """
    chunk = data[operation["offset"]:operation["offset"] + operation["length"]]
    request = urllib.request.Request(
        operation["url"],
        data=chunk,
        method=operation["method"],
        headers={h["name"]: h["value"] for h in operation.get("requestHeaders") or []},
    )
    try:
        with urllib.request.urlopen(request, timeout=asc.TIMEOUT) as response:
            response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")[:300]
        raise SystemExit(f"upload operation failed: HTTP {error.code}\n{detail}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("files", nargs="*", type=Path, help="PNG screenshots, in the order to show")
    parser.add_argument("--platform", choices=("ios", "macos"))
    parser.add_argument("--apply", action="store_true", help="actually write; otherwise a dry run")
    parser.add_argument("--replace", action="store_true",
                        help="delete what each touched set already holds first")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        return _selftest()
    if not args.platform or not args.files:
        parser.error("--platform and at least one file are required")

    grouped = plan(args.files)

    session = Session()
    app = asc.find_app(session.get)
    platform = asc.PLATFORM_FLAGS[args.platform]
    versions = session.get(
        f"/v1/apps/{app['id']}/appStoreVersions?filter[platform]={platform}&limit=5"
    )["data"]
    editable = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE]
    if not editable:
        raise SystemExit(
            f"no editable {args.platform} version. Screenshots can only be changed on a version "
            "that has not shipped."
        )
    version = editable[0]
    print(f"{args.platform} {version['attributes']['versionString']} "
          f"({version['attributes']['appStoreState']})")

    locs = session.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    loc = next((l for l in locs if l["attributes"]["locale"] == LOCALE), None)
    if loc is None:
        raise SystemExit(f"no {LOCALE} localization on this version")

    sets = session.get(
        f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets?limit=50"
    )["data"]
    by_type = {s["attributes"]["screenshotDisplayType"]: s for s in sets}

    for kind, files in grouped.items():
        existing = by_type.get(kind)
        held = []
        if existing:
            held = session.get(f"/v1/appScreenshotSets/{existing['id']}/appScreenshots?limit=50")["data"]
        print(f"  {kind}: {len(files)} to upload, {len(held)} already there")
        for path, _ in files:
            print(f"    + {path.name}")

        if not args.apply:
            if args.replace and held:
                print(f"    - would delete {len(held)} existing")
            print("    (dry run — nothing written)")
            continue

        if existing is None:
            existing = session.post("/v1/appScreenshotSets", {
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": kind},
                    "relationships": {"appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}
                    }},
                }
            })["data"]
            print(f"    created the {kind} set")

        if args.replace:
            for shot in held:
                session.delete(f"/v1/appScreenshots/{shot['id']}")
            if held:
                print(f"    deleted {len(held)} existing")

        for path, data in files:
            reserved = session.post("/v1/appScreenshots", {
                "data": {
                    "type": "appScreenshots",
                    "attributes": {"fileSize": len(data), "fileName": path.name},
                    "relationships": {"appScreenshotSet": {
                        "data": {"type": "appScreenshotSets", "id": existing["id"]}
                    }},
                }
            })["data"]
            for operation in reserved["attributes"]["uploadOperations"]:
                _upload(operation, data)
            session.patch(f"/v1/appScreenshots/{reserved['id']}", {
                "data": {
                    "type": "appScreenshots",
                    "id": reserved["id"],
                    "attributes": {
                        "uploaded": True,
                        "sourceFileChecksum": hashlib.md5(data).hexdigest(),
                    },
                }
            })
            print(f"    uploaded {path.name}")

    print("\nNothing was submitted for review. That is a person pressing Submit.")
    return 0


def _selftest() -> int:
    """Offline. The parts that can be wrong without the API saying so."""
    failures: list[str] = []

    # A real PNG header, built rather than fetched: 1242x2688 is the iPhone slot
    # this app actually holds, and getting the byte offsets wrong is the whole
    # risk in `png_size`.
    header = b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 1242, 2688)
    if png_size(header) != (1242, 2688):
        failures.append(f"png_size misread its own header: {png_size(header)}")

    for bad, why in ((b"\xff\xd8\xff", "a JPEG"), (b"", "nothing"), (b"\x89PNG\r\n\x1a\n" + b"\x00" * 16, "a PNG with no IHDR")):
        try:
            png_size(bad)
            failures.append(f"png_size accepted {why}")
        except ValueError:
            pass

    if display_type((1242, 2688)) != "APP_IPHONE_65":
        failures.append("the iPhone slot this app holds does not map")
    if display_type((2048, 2732)) != "APP_IPAD_PRO_3GEN_129":
        failures.append("the iPad slot this app holds does not map")

    # An unmapped size must stop the run. Silently skipping it would upload a
    # subset and report success, which is the failure mode this whole file is
    # built around.
    try:
        display_type((999, 999))
        failures.append("display_type invented a slot for an unknown size")
    except SystemExit:
        pass

    # Grouping keeps argument order, because that is the only way order is
    # expressed and Apple shows them in upload order.
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        paths = []
        for name in ("c.png", "a.png", "b.png"):
            p = Path(tmp) / name
            p.write_bytes(header)
            paths.append(p)
        grouped = plan(paths)
        got = [p.name for p, _ in grouped["APP_IPHONE_65"]]
        if got != ["c.png", "a.png", "b.png"]:
            failures.append(f"plan did not keep argument order: {got}")

        notpng = Path(tmp) / "x.png"
        notpng.write_bytes(b"\xff\xd8\xff")
        try:
            plan([notpng])
            failures.append("plan accepted a file that is not a PNG")
        except SystemExit:
            pass

    print(f"appstore_screenshots selftest: 8 cases, {len(failures)} failure(s)")
    for failure in failures:
        print(f"  {failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
