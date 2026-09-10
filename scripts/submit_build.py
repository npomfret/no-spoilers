#!/usr/bin/env python3
"""Put this commit in front of the TestFlight testers: archive, upload, wait, deliver.

The one Apple delivery path, for a person and for TeamCity's `Ship` alike, since
2026-09-10. It is FunMax's `submit_build.py` in shape, and task 38 is why: that
one has delivered unattended from the same agents for weeks, while
`release.sh` never once got a TeamCity run as far as an archive.

One run, in order:

1. **Refuse a tree that is not exactly a commit on `main`.** Dirty is refused
   because `xcodebuild archive` builds the tree, not the commit; a commit
   `origin/main` does not contain is refused because the `build/N` tag has to
   mark something everyone can reach.
2. **Refuse a closed train**, per platform. Once Apple has approved a version
   every further upload of it is refused after the archive, so the refusal
   comes first and names the commands that open the next one. **This never
   commits, rebases or pushes a branch.** A version is opened by a commit that
   is verified and shipped like any other, so the archive is always the
   commit that was verified — even when `main` has moved on while `Ship` sat in
   the queue, which is the ordinary case on TeamCity.
3. **Run `scripts/verify-core-tests.sh`**, unless `--tested` says the caller
   already verified this exact commit. `Ship` passes it: it has a snapshot
   dependency on `Verify` at the same revision. Never pass it by hand.
4. **Reserve the build number** by pushing `build/N` on the commit before
   anything is archived. N is `_version.sh: next_build_number` — the highest
   App Store Connect holds on either platform, expired builds and every page
   included, or the highest `build/` tag, plus one. The tag push is what makes
   the number this run's: a second run that chose the same N is refused by the
   remote and chooses again. A reserved number that never reaches Apple is
   harmless; an upload nothing records is not.
5. **For each platform, iOS first**: archive with `CURRENT_PROJECT_VERSION=N`,
   check every bundle in the archive reads that number and the project's
   version, then export and upload in one authenticated `-exportArchive`.
   `manageAppVersionAndBuildNumber` is false, or Xcode renumbers the build on
   the way out and the number chosen against Apple's record is thrown away.
6. **Wait for Apple to process it**, bounded, and then **deliver exactly that
   build**: `testflight_distribute.py --platform P --build N --apply`, which
   writes the note from the `build/N` tag, adds it to the internal group and
   reads both back. Never "the newest" — a build uploaded meanwhile from
   elsewhere must not receive this commit's note.

One platform failing does not stop the other. A two-platform run is one number
and two records, and the run is red if either did not reach its testers.

**A run leaves a record**, `no-spoilers-ship/build-N/record.json` under the
temporary directory — TeamCity's build temp directory on `Ship`, published as an
artifact — naming the commit, the number, and how far each platform got. When
an upload was accepted and the wait or the delivery then failed, the record and
the log both name the recovery command, which delivers that recorded build and
nothing else. Uploading again would only be refused as a duplicate.

`--archive-only` archives and exports locally with `destination=export`. It
reserves no number and contacts App Store Connect only to choose one, so it
proves signing — including the Mac installer identity, via `pkgutil
--check-signature` — without spending anything.

Signing is automatic and authenticated with the App Manager key
`asc_write.ADMIN_KEY_ID`; reads use the Developer key, like the report. Apple's
tools run with `/usr/bin` first on PATH: Homebrew's rsync answering first breaks
the export's copy step with an error that reads like a certificate fault.

Usage:
    scripts/submit_build.py --platform all                    # what would happen
    scripts/submit_build.py --platform all --apply            # a person, with the test gate
    scripts/submit_build.py --platform all --apply --tested   # what TeamCity's Ship runs
    scripts/submit_build.py --platform macos --apply --archive-only
    scripts/submit_build.py --selftest
"""

from __future__ import annotations

import argparse
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

import appstore_status as asc
import testflight_distribute as distribute
from asc_write import ADMIN_KEY_ID

REPO = Path(__file__).resolve().parent.parent
SCRIPTS = REPO / "scripts"
PROJECT = REPO / "NoSpoilers" / "NoSpoilers.xcodeproj"
CONFIGURATION = "Release"
TEAM = "6FZN56WC8G"

# The order is the delivery order: the iPhone app is the product priority, so it
# goes first and a Mac failure can never cost it the upload.
PLATFORMS = {
    "ios": {"scheme": "NoSpoilersApp", "destination": "generic/platform=iOS", "bundles": 2},
    "macos": {"scheme": "NoSpoilers", "destination": "generic/platform=macOS", "bundles": 1},
}

GATE_LIMIT = 1800.0
ARCHIVE_LIMIT = 2400.0
EXPORT_LIMIT = 2400.0

# Apple's step, and the only one whose length nothing here governs. A poll with
# no ceiling is worse than one that stops and names the command to run later.
PROCESSING_CEILING = 3600.0
POLL_SECONDS = 45.0
INGEST_DOUBT = 900.0
EXPECTED_WAIT = "FunMax measures six to fifteen minutes on the same team, and forty-five has happened"

RESERVE_ATTEMPTS = 3


def speak_in_order() -> None:
    """Line-buffer stdout, so this script's lines stay in order with xcodebuild's.

    A pipe makes Python block-buffer while every subprocess writes straight to
    the same descriptor, and a TeamCity log that says `uploading` after the
    upload's own output reads as a different run.
    """
    sys.stdout.reconfigure(line_buffering=True)


def tooling_environment() -> dict[str, str]:
    """The environment Apple's tools run in: `/usr/bin` ahead of everything.

    `-exportArchive` copies with `/usr/bin/rsync -8aPhhE`, which is openrsync,
    and openrsync starts its other side by looking `rsync` up on PATH.
    Homebrew's rsync 3.x answers, rejects `-E`, and the export dies as `Copy
    failed` after signing has succeeded. `release.sh` learned it; so did FunMax.
    """
    environment = dict(os.environ)
    environment["PATH"] = "/usr/bin:/bin:" + environment.get("PATH", "")
    return environment


def version_helper(name: str) -> str:
    """One `_version.sh` function's answer, or a hard stop.

    Called rather than reimplemented: the project's version and the next build
    number each have one owner, and a second copy is how two callers come to
    disagree about what ships.
    """
    done = subprocess.run(
        ["bash", "-c", 'source "$1" && "$2"', "_", str(SCRIPTS / "_version.sh"), name],
        cwd=REPO,
        capture_output=True,
        text=True,
        timeout=300,
    )
    if done.returncode != 0 or not done.stdout.strip():
        raise SystemExit(f"_version.sh {name} gave no answer:\n{done.stderr.strip()}")
    return done.stdout.strip()


def dirty_reason() -> str | None:
    """Why this tree cannot be shipped, or None when it is exactly `HEAD`."""
    changed = [line for line in distribute.git("status", "--porcelain").splitlines() if line.strip()]
    if not changed:
        return None
    shown = "\n  ".join(changed[:10])
    return (
        "the working tree is not clean, so the build would not be the commit its tag and "
        f"note name:\n  {shown}\nCommit or stash it first."
    )


def shipped_commit() -> str:
    """The commit being shipped, once it is established to be on `main`.

    `HEAD` need not be the tip: TeamCity pins a revision when a build is queued,
    and shipping that verified revision faithfully is the point. What it must be
    is *on* `main`, so the `build/N` tag marks something every clone can reach.
    """
    distribute.git("fetch", "--quiet", "origin", "+refs/heads/main:refs/remotes/origin/main")
    sha = distribute.git("rev-parse", "HEAD").strip()
    try:
        distribute.git("merge-base", "--is-ancestor", sha, "refs/remotes/origin/main")
    except subprocess.CalledProcessError:
        raise SystemExit(
            f"{sha[:12]} is not on origin/main, so a build/ tag on it would mark a commit "
            "nobody else can reach. Push it first; this never pushes a branch itself."
        ) from None
    return sha


def authentication() -> list[str]:
    key = asc.key_path(ADMIN_KEY_ID)
    return [
        "-authenticationKeyPath", str(key),
        "-authenticationKeyID", ADMIN_KEY_ID,
        "-authenticationKeyIssuerID", asc.ISSUER_ID,
    ]


def archive_command(platform: str, number: int, archive: Path, derived: Path) -> list[str]:
    """Release, the device slice, and the build number from the command line.

    The number reaches every target through `CURRENT_PROJECT_VERSION` and
    nothing is written to the project. The marketing version is deliberately
    not passed: the committed project is what was verified, and overriding it
    here would archive a version no commit holds.
    """
    shape = PLATFORMS[platform]
    return [
        "xcodebuild", "archive",
        "-project", str(PROJECT),
        "-scheme", shape["scheme"],
        "-configuration", CONFIGURATION,
        "-destination", shape["destination"],
        "-archivePath", str(archive),
        "-derivedDataPath", str(derived),
        "-allowProvisioningUpdates",
        *authentication(),
        f"CURRENT_PROJECT_VERSION={number}",
    ]


def export_options(upload: bool) -> dict:
    """The export, stated in full rather than left to Xcode's defaults.

    `app-store-connect` rather than the deprecated `app-store` the old plist
    used. `manageAppVersionAndBuildNumber` false, because its default is YES and
    Xcode would renumber the build during the upload.
    """
    return {
        "method": "app-store-connect",
        "destination": "upload" if upload else "export",
        "teamID": TEAM,
        "signingStyle": "automatic",
        "uploadSymbols": True,
        "manageAppVersionAndBuildNumber": False,
    }


def export_command(archive: Path, options: Path, output: Path) -> list[str]:
    return [
        "xcodebuild", "-exportArchive",
        "-archivePath", str(archive),
        "-exportOptionsPlist", str(options),
        "-exportPath", str(output),
        "-allowProvisioningUpdates",
        *authentication(),
    ]


def bundle_problems(archive: Path, platform: str, version: str, number: int) -> list[str]:
    """Every way the archive disagrees with what this run asked it to be.

    **Every bundle, the widget extension included.** An app whose embedded
    extension carries a different build number is refused at upload, after the
    export and the wait, so the archive is asked before any of that. The export
    re-signs what is here and rewrites nothing, so what the archive says is what
    Apple receives. iOS carries the app and its widget; macOS the app alone.
    """
    applications = archive / "Products" / "Applications"
    bundles = sorted(
        path for path in applications.rglob("*") if path.is_dir() and path.suffix in (".app", ".appex")
    )
    problems = []
    for bundle in bundles:
        plist = bundle / "Contents" / "Info.plist"
        if not plist.is_file():
            plist = bundle / "Info.plist"
        info = plistlib.loads(plist.read_bytes())
        name = bundle.relative_to(applications)
        if info.get("CFBundleVersion") != str(number):
            problems.append(f"{name} reads CFBundleVersion {info.get('CFBundleVersion')}, not {number}")
        if info.get("CFBundleShortVersionString") != version:
            problems.append(
                f"{name} reads CFBundleShortVersionString {info.get('CFBundleShortVersionString')}, not {version}"
            )
    expected = PLATFORMS[platform]["bundles"]
    if len(bundles) < expected:
        problems.append(f"the {platform} archive holds {len(bundles)} bundle(s), not the {expected} it should")
    return problems


def wait_verdict(state: str | None) -> tuple[str, str]:
    """Whether a build's internal state means wait, deliver, or stop.

    Only PROCESSING is worth another poll. Every other state is an answer, and
    `testflight_distribute` owns the sentence for each of them.
    """
    if state is None:
        return "wait", "not visible on App Store Connect yet"
    reason, ready = distribute.INTERNAL_STATES.get(
        state, (f"in state {state}, which this script has not seen", False)
    )
    if state == "PROCESSING":
        return "wait", "processing at Apple"
    return ("ready" if ready else "stop"), reason


def ingest_doubt(elapsed: float, visible: bool) -> str | None:
    """The line that separates a slow ingest from a binary refused on arrival.

    A refused upload never becomes a build, so it polls exactly like one still
    being unpacked, and Apple says why by email. Silence past `INGEST_DOUBT`
    earns one sentence pointing there, rather than an hour of identical polls.
    """
    if visible or elapsed < INGEST_DOUBT:
        return None
    return (
        f"still not visible after {elapsed / 60:.0f} minutes. An upload Apple refuses on arrival "
        "never appears here and is explained by email instead; worth checking before waiting out the rest."
    )


def uploaded_build(get, app_id: str, platform: str, version: str, number: int) -> dict | None:
    """The one build App Store Connect holds for this platform, version and number."""
    flag = asc.PLATFORM_FLAGS[platform]
    path = asc.builds_path(app_id, flag) + f"&filter[version]={number}&filter[preReleaseVersion.version]={version}"
    matching = [row for row in asc.all_pages(get, path)["data"] if row["attributes"]["version"] == str(number)]
    if len(matching) > 1:
        raise SystemExit(f"App Store Connect holds {len(matching)} {platform} builds numbered {number} in {version}")
    return matching[0] if matching else None


def recovery_command(platform: str, number: int) -> str:
    return f"scripts/testflight_distribute.py --platform {platform} --build {number} --apply"


def await_processing(platform: str, version: str, number: int) -> tuple[bool, str]:
    """Poll until Apple has an answer for this exact build, or the ceiling passes.

    A fresh client every poll: a token lives twenty minutes and this can wait an
    hour.
    """
    started = time.monotonic()
    doubted = False
    while True:
        client = asc.Client()
        app_id = asc.find_app(client.get)["id"]
        build = uploaded_build(client.get, app_id, platform, version, number)
        state = None
        if build is not None:
            state = client.get(f"/v1/builds/{build['id']}/buildBetaDetail")["data"]["attributes"]["internalBuildState"]
        verdict, reason = wait_verdict(state)
        elapsed = time.monotonic() - started
        print(f"  [{elapsed / 60:5.1f}m / {PROCESSING_CEILING / 60:.0f}m] {platform} {number}: {reason}")
        if verdict == "ready":
            print(f"  Apple took {elapsed / 60:.1f} minutes ({EXPECTED_WAIT})")
            return True, state
        if verdict == "stop":
            return False, f"{state}: {reason}"
        if not doubted and (doubt := ingest_doubt(elapsed, build is not None)):
            print(f"  {doubt}")
            doubted = True
        if elapsed >= PROCESSING_CEILING:
            return False, f"still {state or 'not visible'} after {PROCESSING_CEILING / 60:.0f} minutes"
        time.sleep(POLL_SECONDS)


def step(command: list[str], limit: float) -> int:
    """Run one Apple tool with its output streaming into the log, bounded."""
    try:
        return subprocess.run(command, cwd=REPO, env=tooling_environment(), timeout=limit).returncode
    except subprocess.TimeoutExpired:
        print(f"{command[0]} {command[1]} ran past {limit / 60:.0f} minutes and was stopped", file=sys.stderr)
        return 124


def reserve_number(sha: str, versions: dict[str, str]) -> int:
    """Choose the next build number and make it this run's by pushing its tag.

    The push is the lock. Two runs that chose the same N — a laptop and an agent
    a minute apart — cannot both push `build/N`, so the loser learns it here, in
    seconds, and chooses again, rather than at upload after an archive.
    """
    shipping = ", ".join(f"{platform} v{version}" for platform, version in versions.items())
    for attempt in range(1, RESERVE_ATTEMPTS + 1):
        number = int(version_helper("next_build_number"))
        tag = f"build/{number}"
        distribute.git(
            "tag", "-a", tag, sha,
            "-m", f"build {number}: {shipping}",
            "-m", "Reserved by scripts/submit_build.py before archiving this commit. The number is "
            "spent whether or not an upload follows; the run's record says what reached Apple.",
        )
        try:
            distribute.git("push", "--quiet", "origin", f"refs/tags/{tag}")
            return number
        except subprocess.CalledProcessError as refusal:
            distribute.git("tag", "-d", tag)
            if distribute.git("ls-remote", "--tags", "origin", f"refs/tags/{tag}").strip():
                print(f"  {tag} was taken by another run (attempt {attempt} of {RESERVE_ATTEMPTS}); choosing again")
                continue
            raise SystemExit(
                f"could not push {tag}, so build {number} is not reserved and nothing was built:\n"
                f"{refusal.stderr.strip()}"
            ) from None
    raise SystemExit(f"lost the build-number race {RESERVE_ATTEMPTS} times running; something else is shipping")


def write_record(path: Path, record: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, indent=2) + "\n")


def ship_platform(platform: str, version: str, number: int, work: Path, entry: dict, save, archive_only: bool) -> bool:
    """One platform from archive to confirmed delivery, recording every stage."""
    scheme = PLATFORMS[platform]["scheme"]

    def failed(stage: str, detail: str, recovery: str | None = None) -> bool:
        entry.update({"failed": stage, "detail": detail, "recovery": recovery})
        save()
        print(f"\n{platform}: {stage} failed — {detail}", file=sys.stderr)
        if recovery:
            print(f"{platform}: recover with\n  {recovery}", file=sys.stderr)
        return False

    def reached(stage: str, **extra) -> None:
        entry.update({"stage": stage, **extra})
        save()

    archive = work / f"{scheme}.xcarchive"
    derived = REPO / "tmp" / "DerivedData" / f"Ship-{platform}"
    print(f"\n==> {platform}: archiving {scheme} {version} ({number}) — limit {ARCHIVE_LIMIT / 60:.0f}m")
    if step(archive_command(platform, number, archive, derived), ARCHIVE_LIMIT):
        return failed("archive", "xcodebuild archive failed; its own output above says why")

    problems = bundle_problems(archive, platform, version, number)
    if problems:
        return failed("archive", "; ".join(problems))
    reached("archived")

    options = work / f"{platform}.exportOptions.plist"
    options.write_bytes(plistlib.dumps(export_options(upload=not archive_only)))
    output = work / f"{platform}-export"
    verb = "exporting" if archive_only else "exporting and uploading"
    print(f"\n==> {platform}: {verb} — limit {EXPORT_LIMIT / 60:.0f}m")
    if step(export_command(archive, options, output), EXPORT_LIMIT):
        return failed(
            "export",
            "xcodebuild -exportArchive failed. It prints a digest; Apple's verbatim answer is in "
            "IDEDistributionProvisioning.log inside the .xcdistributionlogs bundle its first lines name",
            None if archive_only else
            f"if App Store Connect shows {platform} build {number} anyway, {recovery_command(platform, number)}",
        )

    if archive_only:
        packages = sorted(str(path.relative_to(output)) for path in output.iterdir())
        print(f"  exported to {output}: {', '.join(packages)}")
        for package in output.glob("*.pkg"):
            if step(["pkgutil", "--check-signature", str(package)], 60.0):
                return failed("export", f"{package.name} carries no valid installer signature")
        reached("exported")
        return True

    reached("uploaded")
    print(f"\n==> {platform}: waiting for Apple to process build {number} — {EXPECTED_WAIT}")
    ready, state = await_processing(platform, version, number)
    if not ready:
        return failed("processing", state, recovery_command(platform, number))
    reached("processed", processing=state)

    print(f"\n==> {platform}: delivering build {number} to the internal testers")
    handed = subprocess.run(
        [sys.executable, str(SCRIPTS / "testflight_distribute.py"), "--platform", platform, "--build", str(number), "--apply"],
        cwd=REPO,
    )
    if handed.returncode:
        return failed("delivery", "testflight_distribute.py did not confirm the delivery", recovery_command(platform, number))
    reached("delivered")
    return True


def run(requested: list[str], apply: bool, tested: bool, archive_only: bool) -> int:
    blocked = dirty_reason()
    if blocked:
        print(blocked, file=sys.stderr)
        return 1
    sha = shipped_commit()
    version = version_helper("current_marketing_version")

    client = asc.Client()
    app_id = asc.find_app(client.get)["id"]
    open_platforms = []
    for platform in requested:
        state = asc.closed_train(client.get, app_id, asc.PLATFORM_FLAGS[platform], version)
        if state is None:
            open_platforms.append(platform)
            continue
        print(
            f"{platform} {version} is closed to new builds: it is {state}. Nothing will be built for {platform}.\n"
            "  Record the approval and open the next version; that commit then ships like any other:\n"
            f"    scripts/tag_approved.py {platform} {version} --apply\n"
            f"    scripts/open_version.sh {version_helper('suggest_next_version')}",
            file=sys.stderr,
        )
    refused = [platform for platform in requested if platform not in open_platforms]

    subject = distribute.git("log", "-1", "--format=%s", sha).strip()
    print(f"{version} from {sha[:12]} {subject}")
    if not open_platforms:
        return 1

    if not apply:
        print(
            f"would {'' if tested else 'run scripts/verify-core-tests.sh, '}reserve build "
            f"{version_helper('next_build_number')} as a build/ tag on this commit, and for "
            f"{' then '.join(open_platforms)}: archive, upload, wait for processing, and deliver "
            "that exact build to the internal testers.\nRe-run with --apply."
        )
        return 1 if refused else 0

    asc.require_key(
        asc.key_path(ADMIN_KEY_ID),
        f"{ADMIN_KEY_ID} is the App Manager key signing and delivery authenticate with.",
    )

    if tested:
        print("the caller verified this commit, so the test gate is not run again here")
    else:
        print("==> running the test gate: scripts/verify-core-tests.sh")
        try:
            gate = subprocess.run([str(SCRIPTS / "verify-core-tests.sh")], cwd=REPO, timeout=GATE_LIMIT)
        except subprocess.TimeoutExpired:
            print("the test gate ran past its limit, so nothing was reserved or built", file=sys.stderr)
            return 1
        if gate.returncode:
            print("the test gate is red, so nothing was reserved or built", file=sys.stderr)
            return gate.returncode

    if archive_only:
        number = int(version_helper("next_build_number"))
        print(f"archive only: stamping {number}, which is not reserved because nothing will be uploaded")
    else:
        number = reserve_number(sha, {platform: version for platform in open_platforms})
        print(f"==> reserved build/{number} on {sha[:12]}")

    work = Path(tempfile.gettempdir()) / "no-spoilers-ship" / f"build-{number}"
    work.mkdir(parents=True, exist_ok=True)
    record_path = work / "record.json"
    record = {
        "commit": sha,
        "build": number,
        "reserved": None if archive_only else f"build/{number}",
        "mode": "archive-only" if archive_only else "deliver",
        "tested": tested,
        "started": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "platforms": {platform: {"version": version, "stage": "refused: train closed"} for platform in refused},
    }
    save = lambda: write_record(record_path, record)  # noqa: E731

    results = {}
    for platform in open_platforms:
        record["platforms"][platform] = {"version": version, "stage": "started"}
        save()
        results[platform] = ship_platform(
            platform, version, number, work, record["platforms"][platform], save, archive_only
        )

    print(f"\nrecord: {record_path}")
    for platform in requested:
        entry = record["platforms"][platform]
        outcome = f"failed at {entry['failed']}" if entry.get("failed") else entry["stage"]
        print(f"  {platform:6} {version} ({number}): {outcome}")
    return 0 if all(results.values()) and not refused else 1


def arguments() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--platform",
        required=True,
        choices=["all", *PLATFORMS],
        help="all is iOS then macOS under one build number. Required, with no default: the "
        "only default would be one platform, silently.",
    )
    parser.add_argument("--apply", action="store_true", help="actually reserve, build, upload and deliver")
    parser.add_argument(
        "--tested",
        action="store_true",
        help="skip the test gate: the caller verified this exact commit. What Ship passes; never by hand.",
    )
    parser.add_argument(
        "--archive-only",
        action="store_true",
        help="with --apply, archive and export locally and stop. Reserves nothing and uploads nothing.",
    )
    return parser


def selftest() -> int:
    """Offline. The decisions and the commands, not the tools they start."""
    failures: list[str] = []

    uploading = export_options(upload=True)
    if uploading["method"] != "app-store-connect" or uploading["destination"] != "upload":
        failures.append(f"the export does not upload to App Store Connect: {uploading}")
    if uploading["manageAppVersionAndBuildNumber"] is not False:
        failures.append("Xcode is left free to renumber the build during the upload")
    if export_options(upload=False)["destination"] != "export":
        failures.append("--archive-only would still upload")
    if plistlib.loads(plistlib.dumps(uploading)) != uploading:
        failures.append("the export options do not survive being written as a plist")

    archive = Path("/archives/x.xcarchive")
    command = archive_command("ios", 10025, archive, Path("/derived"))
    if "CURRENT_PROJECT_VERSION=10025" not in command:
        failures.append("the build number does not reach xcodebuild")
    if command[command.index("-configuration") + 1] != "Release":
        failures.append("the archive is not a Release build")
    if any(part.startswith("MARKETING_VERSION") for part in command):
        failures.append("the archive overrides the version the verified commit holds")
    if "-allowProvisioningUpdates" not in command or str(asc.key_path(ADMIN_KEY_ID)) not in command:
        failures.append("the archive cannot authenticate its signing with the App Manager key")
    if command[command.index("-destination") + 1] != "generic/platform=iOS":
        failures.append("the iOS archive is not confined to the device slice")
    if archive_command("macos", 1, archive, Path("/d"))[command.index("-scheme") + 1] != "NoSpoilers":
        failures.append("the macOS archive does not build the NoSpoilers scheme")

    if not tooling_environment()["PATH"].startswith("/usr/bin:"):
        failures.append("Homebrew's rsync would answer the export's copy step")

    if list(PLATFORMS) != ["ios", "macos"]:
        failures.append("iOS no longer ships before macOS")

    for state, wanted in (
        ("PROCESSING", "wait"),
        (None, "wait"),
        ("READY_FOR_BETA_TESTING", "ready"),
        ("IN_BETA_TESTING", "ready"),
        ("PROCESSING_EXCEPTION", "stop"),
        ("MISSING_EXPORT_COMPLIANCE", "stop"),
    ):
        if wait_verdict(state)[0] != wanted:
            failures.append(f"a build {state} was not treated as {wanted}")
    unknown = wait_verdict("SOMETHING_NEW")
    if unknown[0] != "stop" or "SOMETHING_NEW" not in unknown[1]:
        failures.append("an unknown processing state was not reported as unknown")

    if ingest_doubt(INGEST_DOUBT - 1, False) is not None or ingest_doubt(INGEST_DOUBT + 1, True) is not None:
        failures.append("an upload was doubted too early, or while plainly there")
    if "email" not in (ingest_doubt(INGEST_DOUBT + 1, False) or ""):
        failures.append("an upload that never arrived does not send anyone to the email")

    if recovery_command("macos", 10025) != "scripts/testflight_distribute.py --platform macos --build 10025 --apply":
        failures.append("the recovery command does not name the exact recorded build")

    with tempfile.TemporaryDirectory() as scratch:
        def bundle(path: Path, number: str, version: str, mac: bool = False) -> None:
            plist = path / ("Contents/Info.plist" if mac else "Info.plist")
            plist.parent.mkdir(parents=True, exist_ok=True)
            plist.write_bytes(plistlib.dumps({"CFBundleVersion": number, "CFBundleShortVersionString": version}))

        ios = Path(scratch) / "ios.xcarchive"
        app = ios / "Products/Applications/NoSpoilersApp.app"
        bundle(app, "10025", "1.1.4")
        bundle(app / "PlugIns/NoSpoilersWidgetExtension.appex", "10025", "1.1.4")
        if bundle_problems(ios, "ios", "1.1.4", 10025):
            failures.append(f"a correct iOS archive was refused: {bundle_problems(ios, 'ios', '1.1.4', 10025)}")
        bundle(app / "PlugIns/NoSpoilersWidgetExtension.appex", "10022", "1.1.4")
        if not any("NoSpoilersWidgetExtension.appex" in p for p in bundle_problems(ios, "ios", "1.1.4", 10025)):
            failures.append("a widget extension carrying another build number was not named")
        if not any("CFBundleShortVersionString" in p for p in bundle_problems(ios, "ios", "1.1.5", 10025)):
            failures.append("an archive of another version was not refused")

        lonely = Path(scratch) / "lonely.xcarchive"
        bundle(lonely / "Products/Applications/NoSpoilersApp.app", "10025", "1.1.4")
        if not any("holds 1 bundle" in p for p in bundle_problems(lonely, "ios", "1.1.4", 10025)):
            failures.append("an iOS archive without its widget extension was accepted")

        mac = Path(scratch) / "mac.xcarchive"
        bundle(mac / "Products/Applications/NoSpoilersMac.app", "10025", "1.1.4", mac=True)
        if bundle_problems(mac, "macos", "1.1.4", 10025):
            failures.append("a correct macOS archive was refused, so Contents/Info.plist is not being read")

    parser = arguments()
    if parser.parse_args(["--platform", "all"]).tested:
        failures.append("the test gate is skipped by default")
    try:
        with open(os.devnull, "w") as quiet:
            stderr, sys.stderr = sys.stderr, quiet
            try:
                parser.parse_args([])
            finally:
                sys.stderr = stderr
        failures.append("--platform has a default, so asking for nothing ships something")
    except SystemExit:
        pass

    for failure in failures:
        print(f"  FAIL {failure}", file=sys.stderr)
    print(f"submit_build selftest: 29 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    speak_in_order()
    asked = arguments().parse_args()
    requested = list(PLATFORMS) if asked.platform == "all" else [asked.platform]
    if asked.archive_only and not asked.apply:
        raise SystemExit("--archive-only does something only with --apply")
    return run(requested, asked.apply, asked.tested, asked.archive_only)


if __name__ == "__main__":
    sys.exit(main())
