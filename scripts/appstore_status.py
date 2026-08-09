#!/usr/bin/env python3
"""What App Store Connect currently holds for this app, and what needs a person.

One app record covers both platforms — macOS and iOS share
`pomocorp.NoSpoilers.NoSpoilersMac` under Universal Purchase — so the two live
almost separate lives in App Store Connect: separate versions, separate listing
text, separate screenshots, separate review submissions, and one shared set of
app-level answers. Nothing in the UI shows them side by side, and the state that
matters most is the easiest to miss: **on 2026-08-09 the macOS 1.0.21 was
READY_FOR_SALE while the iOS 1.0.21 of the same version number had been
REJECTED for three months.** This prints both.

It issues `GET`s and nothing else. `scripts/release.sh` remains the only thing
here that uploads or submits anything.

**Two required pages cannot be read at all, and are printed as unknown rather
than left out.** App Privacy — the data-collection questionnaire — has no App
Store Connect API endpoint anywhere; fastlane authenticates with an Apple ID web
session for that one action precisely because none exists. Price and
availability are in the API and refused to a Developer-level key. A checklist
that silently omits a required item reads as a finished checklist.

**Rejection reasons are not in this API either.** A version reads `REJECTED` and
its submission reads `UNRESOLVED_ISSUES`, and that is the whole of it — what App
Review actually said lives in Resolution Center, in the browser.

The exit code is the answer to "is anything waiting on me": 0 when nothing this
report can see needs a person, 1 when something does.

Stdlib only. The ES256 token is built from `openssl` and twenty lines of ASN.1
rather than a Ruby or Python dependency tree, so this runs on a clean machine
with nothing installed. It uses the same key, issuer and app as
`scripts/ship-ios.sh`.

Usage:
    scripts/appstore_status.py
    scripts/appstore_status.py --json
    scripts/appstore_status.py --selftest
"""

from __future__ import annotations

import argparse
import base64
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.appstoreconnect.apple.com"

# The same three values `scripts/ship-ios.sh` and `scripts/ship-appstore.sh`
# pass to `release.sh`. Constants rather than flags because a report that
# silently described a different app would be worse than one that fails.
BUNDLE_ID = "pomocorp.NoSpoilers.NoSpoilersMac"
KEY_ID = "S394C74APG"
ISSUER_ID = "69a6de6e-6d3e-47e3-e053-5b8c7c11a4d1"
KEY_PATH = Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{KEY_ID}.p8"

# App Store Connect rejects a token older than twenty minutes. A run is well
# inside that; this is not a session.
TOKEN_LIFETIME = 1200
TIMEOUT = 30

# Screenshot display types are one Apple enum covering every device Apple has
# shipped, and the smaller sizes are derived from the largest in each family, so
# what matters is whether a family has any images at all. Grouped by platform
# because an iPad set on a macOS version means nothing.
FAMILIES = {
    "IOS": (("iPhone", "APP_IPHONE"), ("iPad", "APP_IPAD")),
    "MAC_OS": (("desktop", "APP_DESKTOP"),),
}

# What each App Store state means for the only question worth asking: is
# somebody expected to do something. Apple's vocabulary mixes "you are editing
# this", "Apple is looking at it" and "it is out" into one field.
WORKING = {
    "PREPARE_FOR_SUBMISSION": "being written",
    "DEVELOPER_REJECTED": "you pulled it back",
    "REJECTED": "App Review said no",
    "METADATA_REJECTED": "App Review objected to the listing, not the binary",
    "INVALID_BINARY": "the build was refused",
    "PENDING_DEVELOPER_RELEASE": "approved, waiting for you to release it",
}
WAITING = {
    "WAITING_FOR_REVIEW": "queued at Apple",
    "IN_REVIEW": "Apple is looking at it",
    "PENDING_APPLE_RELEASE": "approved, Apple releases it",
    "PROCESSING_FOR_APP_STORE": "publishing",
}

# The listing fields App Store Connect will not accept a submission without,
# under the names this report prints. Everything else is reported and never
# chased: a marketing URL is a decision, not an omission.
REQUIRED_TEXT = (
    ("description", "description"),
    ("keywords", "keywords"),
    ("supportUrl", "support URL"),
)

CONTACT = (
    ("contactFirstName", "first name"),
    ("contactLastName", "last name"),
    ("contactEmail", "email"),
    ("contactPhone", "phone"),
)

# Read from App Review details, and deliberately not all of them: the response
# carries `demoAccountPassword` in the clear, and a status report — especially
# one with a `--json` mode whose output ends up pasted somewhere — has no reason
# to hold a password at all. Whether one is set is the only part worth knowing.
REVIEW_FIELDS = tuple(key for key, _ in CONTACT) + ("demoAccountName", "demoAccountRequired", "notes")


def _b64(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """An ECDSA DER signature as the 64-byte `r || s` that JOSE requires.

    `openssl dgst -sign` emits `SEQUENCE { INTEGER r, INTEGER s }`; ES256 wants
    the two values bare, each left-padded to 32 bytes. DER stores them signed,
    so a value whose top bit is set carries a leading zero that must come off
    and a short value needs padding back on — get either wrong and the signature
    verifies locally and Apple returns 401.
    """
    if not der or der[0] != 0x30:
        raise ValueError("not a DER SEQUENCE")
    index = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        if der[index] != 0x02:
            raise ValueError("expected a DER INTEGER")
        length = der[index + 1]
        value = der[index + 2 : index + 2 + length].lstrip(b"\x00")
        if len(value) > 32:
            raise ValueError("integer wider than P-256")
        out += value.rjust(32, b"\x00")
        index += 2 + length
    return out


def token(issuer: str, key_id: str, key_file: Path, now: int | None = None) -> str:
    """A signed ES256 bearer token. The key is read by openssl, never by us."""
    issued = int(time.time()) if now is None else now
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {
        "iss": issuer,
        "iat": issued,
        "exp": issued + TOKEN_LIFETIME,
        "aud": "appstoreconnect-v1",
    }
    signing_input = f"{_b64(json.dumps(header).encode())}.{_b64(json.dumps(claims).encode())}"
    signed = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key_file)],
        input=signing_input.encode(),
        capture_output=True,
        check=True,
    )
    return f"{signing_input}.{_b64(der_to_raw(signed.stdout))}"


class Client:
    """GET-only. There is no post, put or patch here, by design."""

    def __init__(self) -> None:
        if not KEY_PATH.exists():
            raise SystemExit(
                f"no private key at {KEY_PATH}\n"
                "It is the one scripts/ship-ios.sh already uses, downloadable once from "
                "App Store Connect > Users and Access > Integrations."
            )
        self.bearer = token(ISSUER_ID, KEY_ID, KEY_PATH)

    def get(self, path: str) -> dict:
        request = urllib.request.Request(
            API + path, headers={"Authorization": f"Bearer {self.bearer}"}
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:400]
            raise SystemExit(f"GET {path} -> HTTP {error.code}\n{detail}")


def _text(value: object) -> str:
    """Blank, null and whitespace are the same answer: nothing is filled in."""
    return str(value).strip() if value is not None else ""


def screenshot_families(platform: str, sets: list[dict]) -> dict[str, int | None]:
    """How many screenshots each device family has, for this platform's families.

    Counts images rather than sets. An empty set is exactly what App Store
    Connect leaves behind when an upload fails, and a declared-but-empty slot is
    refused at the end of a submission rather than the start.

    `None` means a set exists whose images could not be counted, which is not the
    same as none and must never be chased: `meta.paging` is only populated when
    the request asks to include the screenshots, so a caller that forgets would
    otherwise manufacture a problem that is not there.
    """
    counts: dict[str, int | None] = {name: 0 for name, _ in FAMILIES.get(platform, ())}
    for entry in sets:
        display = entry["display"] or ""
        for name, prefix in FAMILIES.get(platform, ()):
            if not display.startswith(prefix):
                continue
            if entry["count"] is None:
                counts[name] = None
            elif counts[name] is not None:
                counts[name] += entry["count"]
    return counts


def _screenshot_sets(client: Client, localization_id: str) -> list[dict]:
    # `include=appScreenshots` is load-bearing: without it every set comes back
    # with no `meta.paging` and every count reads as unknown.
    response = client.get(
        f"/v1/appStoreVersionLocalizations/{localization_id}"
        "/appScreenshotSets?limit=50&include=appScreenshots"
    )
    sets = []
    for entry in response["data"]:
        paging = (
            ((entry.get("relationships") or {}).get("appScreenshots") or {}).get("meta") or {}
        ).get("paging") or {}
        sets.append(
            {
                "display": entry["attributes"].get("screenshotDisplayType"),
                "count": paging.get("total"),
            }
        )
    return sets


def gather(client: Client) -> dict:
    """Everything the report needs, as plain data. No password ever enters it."""
    apps = client.get("/v1/apps?limit=200")["data"]
    app = next((a for a in apps if a["attributes"].get("bundleId") == BUNDLE_ID), None)
    if not app:
        raise SystemExit(f"no App Store Connect record for {BUNDLE_ID}")

    attributes = app["attributes"]
    report: dict = {
        "app": {
            "id": app["id"],
            "name": attributes.get("name"),
            "bundleId": attributes.get("bundleId"),
            "primaryLocale": attributes.get("primaryLocale"),
            "contentRights": attributes.get("contentRightsDeclaration"),
        },
        "categories": {"primary": None, "secondary": None},
        "ageRating": None,
        "versions": [],
        "submissions": [],
    }

    info = client.get(
        f"/v1/apps/{app['id']}/appInfos?include=primaryCategory,secondaryCategory,appInfoLocalizations"
    )
    # More than one `appInfo` exists while a version is in flight — one live, one
    # being edited. The live one is what the store shows, so it is the one worth
    # reporting; a rejected edit is reported through its version instead.
    live = next(
        (i for i in info["data"] if i["attributes"].get("state") == "READY_FOR_DISTRIBUTION"),
        None,
    ) or (info["data"][0] if info["data"] else None)
    app_locales: dict[str, dict] = {}
    if live:
        included = {(i["type"], i["id"]): i for i in info.get("included") or []}
        relationships = live.get("relationships") or {}
        for key in ("primaryCategory", "secondaryCategory"):
            # A category's id is its name — "SPORTS", "GAMES" — so the link is
            # the whole answer.
            linked = (relationships.get(key) or {}).get("data")
            report["categories"][key.replace("Category", "")] = linked["id"] if linked else None
        report["ageRating"] = live["attributes"].get("appStoreAgeRating")
        for linked in (relationships.get("appInfoLocalizations") or {}).get("data") or []:
            entry = included.get(("appInfoLocalizations", linked["id"]))
            if entry:
                app_locales[entry["attributes"]["locale"]] = entry["attributes"]

    versions = client.get(
        f"/v1/apps/{app['id']}/appStoreVersions?limit=20"
        "&include=appStoreVersionLocalizations,build"
    )
    included = {(i["type"], i["id"]): i for i in versions.get("included") or []}
    seen_platforms: set[str] = set()
    for version in versions["data"]:
        platform = version["attributes"].get("platform")
        # The list arrives newest first, so the first version seen for a
        # platform is its current one; older ones are history and reporting them
        # would bury the two lines that matter under a changelog.
        if platform in seen_platforms:
            continue
        seen_platforms.add(platform)

        relationships = version.get("relationships") or {}
        build = (relationships.get("build") or {}).get("data")
        entry = {
            "id": version["id"],
            "platform": platform,
            "string": version["attributes"].get("versionString"),
            "state": version["attributes"].get("appStoreState"),
            "releaseType": version["attributes"].get("releaseType"),
            "created": version["attributes"].get("createdDate"),
            "build": (included.get(("builds", build["id"])) or {}).get("attributes", {}).get("version")
            if build
            else None,
            "listing": [],
            "review": None,
        }
        for linked in (relationships.get("appStoreVersionLocalizations") or {}).get("data") or []:
            localization = included.get(("appStoreVersionLocalizations", linked["id"]))
            if not localization:
                continue
            fields = dict(localization["attributes"])
            # Name, subtitle and privacy policy belong to the app rather than
            # the version and are edited on a different page. Merged here
            # because nobody thinks of them as separate when asking whether a
            # locale is finished.
            fields.update(
                {k: v for k, v in (app_locales.get(fields["locale"]) or {}).items() if k != "locale"}
            )
            fields["screenshots"] = screenshot_families(
                platform, _screenshot_sets(client, localization["id"])
            )
            entry["listing"].append(fields)

        # 200 with a null body, not a 404, when nobody has filled the page in.
        detail = client.get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")["data"]
        if detail:
            entry["review"] = {k: detail["attributes"].get(k) for k in REVIEW_FIELDS}
            entry["review"]["demoAccountPasswordSet"] = bool(
                _text(detail["attributes"].get("demoAccountPassword"))
            )
        report["versions"].append(entry)

    report["submissions"] = [
        {
            "platform": s["attributes"].get("platform"),
            "state": s["attributes"].get("state"),
            "submitted": (s["attributes"].get("submittedDate") or "")[:10] or None,
        }
        for s in client.get(f"/v1/apps/{app['id']}/reviewSubmissions?limit=20")["data"]
    ]
    return report


def attention(report: dict) -> list[str]:
    """What is waiting on a person, most urgent first.

    Only what this report can see. App Privacy and price/availability are absent
    because they are unreadable, not because they are done, and a rejection's
    reasons are absent because Apple does not put them in the API.
    """
    found: list[str] = []

    for version in report["versions"]:
        platform, name, state = version["platform"], version["string"], version["state"]
        if state not in WORKING:
            continue
        if state == "PENDING_DEVELOPER_RELEASE":
            found.append(f"{platform} {name} is approved and waiting for you to release it")
            continue
        if state in ("REJECTED", "METADATA_REJECTED", "INVALID_BINARY"):
            found.append(
                f"{platform} {name} is {state}: what App Review said is in Resolution Center, "
                "not in this API"
            )
        if not version["build"]:
            found.append(f"{platform} {name} has no build attached")

        for fields in version["listing"]:
            locale = fields["locale"]
            empty = [label for key, label in REQUIRED_TEXT if not _text(fields.get(key))]
            if not _text(fields.get("privacyPolicyUrl")):
                empty.append("privacy policy URL")
            # Every version of this app is an update — it has been on sale since
            # 1.0.13 — so a blank "What's New" is a blank release note, not an
            # inapplicable field.
            if not _text(fields.get("whatsNew")):
                empty.append("what's new")
            if empty:
                found.append(f"{platform} {name} {locale}: {', '.join(empty)} empty")
            bare = [n for n, count in (fields.get("screenshots") or {}).items() if count == 0]
            if bare:
                found.append(f"{platform} {name} {locale}: no {' or '.join(bare)} screenshots")

        review = version["review"]
        if review is None:
            found.append(f"{platform} {name} has no App Review contact details")
        else:
            missing = [label for key, label in CONTACT if not _text(review.get(key))]
            if missing:
                found.append(f"{platform} {name} App Review contact is missing {', '.join(missing)}")
            if review.get("demoAccountRequired") and not review.get("demoAccountPasswordSet"):
                found.append(
                    f"{platform} {name} says a demo account is required and has no password set"
                )

    for submission in report["submissions"]:
        if submission["state"] == "UNRESOLVED_ISSUES":
            found.append(
                f"the {submission['platform']} submission of {submission['submitted']} is still "
                "UNRESOLVED_ISSUES: answer it in Resolution Center or withdraw it"
            )
    return found


def _row(label: str, value: object, note: str = "") -> str:
    shown = _text(value) or "—"
    shown = " ".join(shown.split())
    if len(shown) > 52:
        shown = shown[:49] + "..."
    return f"  {label:<19} {shown}{f'   {note}' if note else ''}"


def render(report: dict) -> str:
    app = report["app"]
    lines = [
        f"App        {app['name']} ({app['id']})",
        f"           {app['bundleId']} — one record, both platforms",
        "",
        "APP INFORMATION",
        _row("primary category", report["categories"]["primary"]),
        _row("secondary", report["categories"]["secondary"], "optional"),
        _row("content rights", report["app"]["contentRights"]),
        _row("age rating", report["ageRating"]),
    ]

    for version in report["versions"]:
        state = version["state"]
        meaning = WORKING.get(state) or WAITING.get(state) or ("on sale" if state == "READY_FOR_SALE" else "")
        held = f"build {version['build']}" if version["build"] else "no build attached"
        lines.append("")
        lines.append(f"{version['platform']}  {version['string']}  {state}  ({meaning})  {held}")
        for fields in version["listing"]:
            lines.append(f"  listing {fields['locale']}")
            for key, label, note in (
                ("name", "name", ""),
                ("subtitle", "subtitle", "optional"),
                ("privacyPolicyUrl", "privacy policy", ""),
                ("description", "description", ""),
                ("keywords", "keywords", ""),
                ("supportUrl", "support URL", ""),
                ("promotionalText", "promotional text", "optional"),
                ("whatsNew", "what's new", ""),
            ):
                lines.append(_row(label, fields.get(key), note))
            for name, count in (fields.get("screenshots") or {}).items():
                shown = "?" if count is None else ("none" if count == 0 else str(count))
                lines.append(_row(f"{name} screenshots", shown))
        review = version["review"] or {}
        for key, label in CONTACT:
            lines.append(_row(f"contact {label}", review.get(key)))
        if version["review"]:
            demo = (
                f"{review.get('demoAccountName') or 'no account'}, "
                f"password {'set' if review.get('demoAccountPasswordSet') else 'NOT set'}"
                if review.get("demoAccountRequired")
                else "not required"
            )
        else:
            demo = None
        lines.append(_row("demo account", demo))
        lines.append(_row("review notes", review.get("notes"), "optional"))

    lines.append("")
    lines.append("SUBMISSIONS")
    if report["submissions"]:
        for submission in report["submissions"]:
            lines.append(
                f"  {submission['platform']:<8} {submission['state']:<20} {submission['submitted'] or '—'}"
            )
    else:
        lines.append("  none")

    lines.append("")
    lines.append("NOT VISIBLE HERE")
    lines.append(_row("app privacy", "unknown", "no API endpoint exists; use the browser"))
    lines.append(_row("price, territories", "unknown", "App Manager key only"))
    lines.append(_row("rejection reasons", "unknown", "Resolution Center only"))

    found = attention(report)
    lines.append("")
    if found:
        lines.append("NEEDS YOU")
        for item in found:
            lines.append(f"  ! {item}")
    else:
        lines.append("Nothing this report can see is waiting on you.")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--json", action="store_true", help="emit the report as JSON")
    parser.parse_args([a for a in sys.argv[1:] if a != "--selftest"])

    report = gather(Client())
    if "--json" in sys.argv:
        print(json.dumps({**report, "needsYou": attention(report)}, indent=2))
    else:
        print(render(report))
    return 1 if attention(report) else 0


def _version(**overrides) -> dict:
    version = {
        "id": "v",
        "platform": "IOS",
        "string": "1.0.22",
        "state": "PREPARE_FOR_SUBMISSION",
        "releaseType": "AFTER_APPROVAL",
        "created": "2026-08-01T00:00:00Z",
        "build": "1022",
        "listing": [
            {
                "locale": "en-GB",
                "name": "No Spoilers - Grand Prix",
                "subtitle": None,
                "privacyPolicyUrl": "https://example.invalid/privacy",
                "description": "Race week without the result.",
                "keywords": "f1,grand prix",
                "supportUrl": "https://example.invalid/support",
                "promotionalText": None,
                "whatsNew": "Fixes.",
                "screenshots": {"iPhone": 3, "iPad": 2},
            }
        ],
        "review": {
            "contactFirstName": "Nick",
            "contactLastName": "Pomfret",
            "contactEmail": "n@example.invalid",
            "contactPhone": "+44 7000 000000",
            "demoAccountName": "demo@example.invalid",
            "demoAccountRequired": True,
            "notes": None,
            "demoAccountPasswordSet": True,
        },
    }
    version.update(overrides)
    return version


def _fixture(**overrides) -> dict:
    report = {
        "app": {
            "id": "1",
            "name": "No Spoilers - Grand Prix",
            "bundleId": BUNDLE_ID,
            "primaryLocale": "en-GB",
            "contentRights": "DOES_NOT_USE_THIRD_PARTY_CONTENT",
        },
        "categories": {"primary": "SPORTS", "secondary": None},
        "ageRating": "FOUR_PLUS",
        "versions": [_version()],
        "submissions": [{"platform": "MAC_OS", "state": "COMPLETE", "submitted": "2026-04-25"}],
    }
    report.update(overrides)
    return report


def _selftest() -> int:
    """Offline. No key, no network — signing uses a throwaway key."""
    import tempfile

    failures: list[str] = []

    def expect(name: str, report: dict, fragment: str | None) -> None:
        found = attention(report)
        if fragment is None:
            if found:
                failures.append(f"{name}: expected nothing waiting, got {found}")
        elif not any(fragment in item for item in found):
            failures.append(f"{name}: nothing mentioning {fragment!r}, got {found}")

    # DER integers are signed, so both the leading-zero strip and the pad back to
    # 32 bytes have to happen. These are the two cases that break a token.
    raw = der_to_raw(bytes([0x30, 0x08, 0x02, 0x02, 0x00, 0xFF, 0x02, 0x02, 0x00, 0x01]))
    if len(raw) != 64:
        failures.append(f"der_to_raw length: {len(raw)}")
    if raw[:32] != b"\x00" * 31 + b"\xff" or raw[32:] != b"\x00" * 31 + b"\x01":
        failures.append("der_to_raw mangled r or s")
    for bad in (b"", b"\x02\x01\x00", bytes([0x30, 0x03, 0x05, 0x01, 0x00])):
        try:
            der_to_raw(bad)
            failures.append(f"der_to_raw accepted {bad!r}")
        except ValueError:
            pass
    if _b64(b"\xfb\xff") != "-_8":
        failures.append("base64url is not url-safe")

    with tempfile.TemporaryDirectory() as tmp:
        key = Path(tmp) / "t.p8"
        subprocess.run(
            ["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", str(key)],
            check=True,
            capture_output=True,
        )
        header, claims, signature = token("issuer", "KID", key, now=1_700_000_000).split(".")
        pad = lambda s: s + "=" * (-len(s) % 4)  # noqa: E731
        if json.loads(base64.urlsafe_b64decode(pad(header)))["kid"] != "KID":
            failures.append("kid missing from header")
        decoded = json.loads(base64.urlsafe_b64decode(pad(claims)))
        if decoded["aud"] != "appstoreconnect-v1" or decoded["exp"] - decoded["iat"] != TOKEN_LIFETIME:
            failures.append("token claims are wrong")
        if len(base64.urlsafe_b64decode(pad(signature))) != 64:
            failures.append("signature is not 64 bytes")

    expect("everything ready", _fixture(), None)

    # A shipping app spends most of its life with nothing in preparation. That is
    # the ordinary state, and treating it as a problem would make the report
    # permanently red and therefore worthless.
    expect("on sale, nothing in flight", _fixture(versions=[_version(state="READY_FOR_SALE")]), None)
    for state in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
        expect(f"{state} is Apple's turn", _fixture(versions=[_version(state=state)]), None)

    # A live version's fields are frozen and complete by definition; chasing
    # blanks in one would invent work nobody can do.
    frozen = _version(state="READY_FOR_SALE", listing=[{**_version()["listing"][0], "whatsNew": None}])
    expect("blank field on a live version", _fixture(versions=[frozen]), None)

    expect("rejected", _fixture(versions=[_version(state="REJECTED")]), "Resolution Center")
    expect(
        "approved and unreleased",
        _fixture(versions=[_version(state="PENDING_DEVELOPER_RELEASE")]),
        "waiting for you to release",
    )
    if len(attention(_fixture(versions=[_version(state="PENDING_DEVELOPER_RELEASE", build=None)]))) != 1:
        failures.append("an approved version needs no listing audit; that is one line, not five")

    expect("no build", _fixture(versions=[_version(build=None)]), "no build attached")
    for blank in (None, "", "   "):
        listing = [{**_version()["listing"][0], "description": blank}]
        expect(f"description {blank!r}", _fixture(versions=[_version(listing=listing)]), "description")
    listing = [{**_version()["listing"][0], "whatsNew": None}]
    expect("no release note", _fixture(versions=[_version(listing=listing)]), "what's new")
    listing = [{**_version()["listing"][0], "screenshots": {"iPhone": 3, "iPad": 0}}]
    expect("no iPad shots", _fixture(versions=[_version(listing=listing)]), "no iPad screenshots")

    expect("no review detail", _fixture(versions=[_version(review=None)]), "no App Review contact")
    expect(
        "no phone",
        _fixture(versions=[_version(review={**_version()["review"], "contactPhone": None})]),
        "missing phone",
    )
    expect(
        "demo account with no password",
        _fixture(versions=[_version(review={**_version()["review"], "demoAccountPasswordSet": False})]),
        "no password set",
    )
    expect(
        "unresolved submission",
        _fixture(submissions=[{"platform": "IOS", "state": "UNRESOLVED_ISSUES", "submitted": "2026-05-15"}]),
        "UNRESOLVED_ISSUES",
    )

    # Screenshot families are per platform: a macOS version has desktop shots and
    # no iPhone ones, and asking it for iPhone screenshots would report a gap
    # that cannot exist.
    mac = screenshot_families("MAC_OS", [{"display": "APP_DESKTOP", "count": 4}])
    if mac != {"desktop": 4}:
        failures.append(f"macOS families: {mac}")
    ios = screenshot_families(
        "IOS",
        [
            {"display": "APP_IPHONE_65", "count": 1},
            {"display": "APP_IPAD_PRO_3GEN_129", "count": 0},
            {"display": "APP_DESKTOP", "count": 9},
        ],
    )
    if ios != {"iPhone": 1, "iPad": 0}:
        failures.append(f"iOS families: {ios}")

    # An uncountable set is unknown, never zero. `meta.paging` appears only when
    # the request includes the screenshots, so this is one forgotten query
    # parameter away from inventing a blocker.
    unknown = screenshot_families("IOS", [{"display": "APP_IPHONE_69", "count": None}])
    if unknown != {"iPhone": None, "iPad": 0}:
        failures.append(f"uncountable set: {unknown}")
    listing = [{**_version()["listing"][0], "screenshots": {"iPhone": None, "iPad": 2}}]
    expect("uncountable screenshots", _fixture(versions=[_version(listing=listing)]), None)

    # The response carries a demo account password in the clear. It must not
    # survive into the report, and least of all into `--json`.
    if "demoAccountPassword" in REVIEW_FIELDS:
        failures.append("the demo account password is being copied into the report")
    if "ap19" in json.dumps(_fixture()):
        failures.append("a password reached a fixture")

    rendered = render(_fixture())
    for fragment in ("APP INFORMATION", "IOS  1.0.22", "NOT VISIBLE HERE", "Resolution Center only"):
        if fragment not in rendered:
            failures.append(f"render dropped {fragment!r}")
    if "!" in rendered:
        failures.append("a ready fixture should render nothing under NEEDS YOU")
    if "password set" not in rendered or "ap19" in rendered:
        failures.append("the demo account should render as set, never as a value")

    for failure in failures:
        print(f"  FAIL {failure}", file=sys.stderr)
    print(f"appstore_status selftest: 32 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    sys.exit(main())
