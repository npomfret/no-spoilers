#!/usr/bin/env python3
"""Put this commit in front of the TestFlight testers: archive, upload, wait, deliver.

The one Apple delivery path, for a person and for TeamCity's `Ship iOS` and
`Ship macOS` alike, since 2026-09-10. It is FunMax's `submit_build.py` in shape,
and task 38 is why: that one has delivered unattended from the same agents for
weeks, while `release.sh` never once got a TeamCity run as far as an archive.

**One platform per run.** Each has its own TeamCity configuration, so a Mac
signing failure never turns the iPhone light red and either re-runs alone. Until
2026-09-10 an `all` run shipped both under one number; now one commit reaches
the two platforms under two numbers, which Apple, the notes and the approval
tags are all indifferent to.

One run, in order:

1. **Refuse a tree that is not exactly a commit on `main`.** Dirty is refused
   because `xcodebuild archive` builds the tree, not the commit; a commit
   `origin/main` does not contain is refused because the `build/N` tag has to
   mark something everyone can reach.
2. **Refuse a closed train.** Once Apple has approved a version
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
   remote and chooses again. Each tag carries a `Reservation:` line of its own
   and origin is read back, because identical tag objects both push — see
   `claim`. A reserved number that never reaches Apple is harmless; an upload
   nothing records is not.
5. **Archive** with `CURRENT_PROJECT_VERSION=N`,
   check every bundle in the archive reads that number and the project's
   version, then export and upload in one authenticated `-exportArchive`.
   `manageAppVersionAndBuildNumber` is false, or Xcode renumbers the build on
   the way out and the number chosen against Apple's record is thrown away.
6. **Wait for Apple to process it**, bounded, and then **deliver exactly that
   build**: `testflight_distribute.py --platform P --build N --apply`, which
   writes the note from the `build/N` tag, adds it to the internal group and
   reads both back. Never "the newest" — a build uploaded meanwhile from
   elsewhere must not receive this commit's note.

However the platform stops, the record says where: `ship_platform` records
anything short of an interrupt against the stage it happened in, and an App
Store Connect 429, 5xx or dropped connection during the wait is another poll
rather than a failure. The run is red unless the build reached its testers.

Every bound here — archive, export, Apple, delivery — sits inside each `Ship`
configuration's TeamCity timeout with room to record: `worst_case`, which the
selftest holds against `.teamcity/settings.kts`.

**A run leaves a record**, `no-spoilers-ship/build-N/record.json` under the
temporary directory — TeamCity's build temp directory on `Ship`, published as an
artifact — naming the commit, the platform, the number, and how far it got. When
an upload was accepted and the wait or the delivery then failed, the record and
the log both name the recovery command, which delivers that recorded build and
nothing else. Uploading again would only be refused as a duplicate.

`--archive-only` archives and exports locally with `destination=export`. It
reserves no number and contacts App Store Connect only to choose one, so it
proves signing — including the Mac package's installer signature, via `pkgutil
--check-signature` — without spending anything.

Signing is automatic and authenticated with the App Manager key
`asc_write.ADMIN_KEY_ID`; reads use the Developer key, like the report. Apple's
tools run with `/usr/bin` first on PATH: Homebrew's rsync answering first breaks
the export's copy step with an error that reads like a certificate fault.

Usage:
    scripts/submit_build.py --platform ios                    # what would happen
    scripts/submit_build.py --platform ios --apply            # a person, with the test gate
    scripts/submit_build.py --platform ios --apply --tested   # what TeamCity's Ship iOS runs
    scripts/submit_build.py --platform macos --apply --archive-only
    scripts/submit_build.py --selftest
"""

from __future__ import annotations

import argparse
import json
import os
import plistlib
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import traceback
import uuid
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

PLATFORMS = {
    "ios": {"scheme": "NoSpoilersApp", "destination": "generic/platform=iOS", "bundles": 2},
    "macos": {"scheme": "NoSpoilers", "destination": "generic/platform=macOS", "bundles": 1},
}

# **macOS is signed manually at export; iOS stays automatic.** An agent holds only the App Manager
# key, and Apple refuses that key cloud-managed certificates (Ship #8 and #9). Automatic signing then
# needs a Mac App Store profile listing the local Apple Distribution certificate, and none of the
# portal's 78 did, so Xcode tried to make one from a cloud certificate and was refused. Naming the
# profile and both certificates leaves it nothing to look up. iOS exports because its store profile
# on the agent machine does list the local certificate.
MAC_SIGNING = {
    "bundle": "pomocorp.NoSpoilers.NoSpoilersMac",
    "profile": "No Spoilers Mac App Store",
    "certificate": "Apple Distribution",
    "installer": "3rd Party Mac Developer Installer",
}

GATE_LIMIT = 1800.0
ARCHIVE_LIMIT = 2400.0
EXPORT_LIMIT = 2400.0
DELIVERY_LIMIT = 600.0

# Apple's step, and the only one whose length nothing here governs. A poll with
# no ceiling is worse than one that stops and names the command to run later.
PROCESSING_CEILING = 3600.0
POLL_SECONDS = 45.0
INGEST_DOUBT = 900.0
EXPECTED_WAIT = "FunMax measures six to fifteen minutes on the same team, and forty-five has happened"

# Everything a delivering run does outside the bounded steps: `ci-publish.sh`'s
# preflight, the fetch, the train reads, up to three reservations at
# `version_helper`'s five minutes each, and each wait's last poll running past
# its ceiling. Not measured, and generous on purpose: being short here is how
# TeamCity, rather than this script, ends a run.
OUTSIDE_THE_STEPS = 1800.0

# What TeamCity must still allow once every bound has been reached, so the
# record is written and published.
RECORD_MARGIN = 900.0

RESERVE_ATTEMPTS = 3
RESERVED_BY = (
    "Reserved by scripts/submit_build.py before archiving this commit. The number is spent "
    "whether or not an upload follows; the run's record says what reached Apple."
)

# The stage a platform was in when it stopped, from the last stage it reached.
FAILING_STAGE = {"started": "archive", "archived": "export", "uploaded": "processing", "processed": "delivery"}


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


def export_options(platform: str, upload: bool) -> dict:
    """The export, stated in full rather than left to Xcode's defaults.

    `app-store-connect` rather than the deprecated `app-store` the old plist
    used. `manageAppVersionAndBuildNumber` false, because its default is YES and
    Xcode would renumber the build during the upload. macOS names its profile and
    both certificates; see `MAC_SIGNING` for why.
    """
    options = {
        "method": "app-store-connect",
        "destination": "upload" if upload else "export",
        "teamID": TEAM,
        "signingStyle": "automatic",
        "uploadSymbols": True,
        "manageAppVersionAndBuildNumber": False,
    }
    if platform == "macos":
        options.update({
            "signingStyle": "manual",
            "provisioningProfiles": {MAC_SIGNING["bundle"]: MAC_SIGNING["profile"]},
            "signingCertificate": MAC_SIGNING["certificate"],
            "installerSigningCertificate": MAC_SIGNING["installer"],
        })
    return options


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


def recovery_for(reached: str, platform: str, number: int, archive_only: bool) -> str | None:
    """What recovers a platform that stopped after reaching `reached`, if anything does.

    Nothing before the export, and nothing for `--archive-only`, which sends
    nothing. The recorded build once the upload was accepted. During the
    export, the same command on condition, since an upload can land after the
    tool has reported failing.
    """
    if archive_only or reached == "started":
        return None
    if reached == "archived":
        return f"if App Store Connect shows {platform} build {number} anyway, {recovery_command(platform, number)}"
    return recovery_command(platform, number)


def worst_case() -> float:
    """The longest a delivering run can take with every bound reached, in seconds.

    Each `Ship` configuration's `executionTimeoutMin` has to exceed this plus
    `RECORD_MARGIN`, or TeamCity rather than this script decides when a run
    ends — and a run TeamCity kills records no failure and names no recovery,
    possibly after the upload was accepted. The selftest reads the number out
    of `.teamcity/settings.kts` and holds it to this. The test gate is not
    counted: `Ship` passes `--tested`.
    """
    return OUTSIDE_THE_STEPS + ARCHIVE_LIMIT + EXPORT_LIMIT + PROCESSING_CEILING + DELIVERY_LIMIT


def transient(error: BaseException) -> bool:
    """Whether a failed App Store Connect read is worth asking again.

    A 429 or a 5xx is Apple briefly unable to answer, and so is a connection
    that dropped or timed out. A 401, 403 or 404 will answer the same way in
    forty-five seconds, and an hour of asking would only bury it.
    """
    if isinstance(error, asc.Refused):
        return error.status == 429 or error.status >= 500
    return isinstance(error, OSError)


def first_line(error: BaseException) -> str:
    return (str(error).strip().splitlines() or [type(error).__name__])[0]


def processing_state(platform: str, version: str, number: int) -> tuple[str | None, str | None]:
    """One look: App Store Connect's id for this build once it shows it, and its internal state.

    A fresh client every look: a token lives twenty minutes and the wait can
    last an hour.
    """
    client = asc.Client()
    app_id = asc.find_app(client.get)["id"]
    build = uploaded_build(client.get, app_id, platform, version, number)
    if build is None:
        return None, None
    return build["id"], client.get(f"/v1/builds/{build['id']}/buildBetaDetail")["data"]["attributes"]["internalBuildState"]


def await_processing(platform: str, version: str, number: int) -> tuple[bool, str, str | None]:
    """Poll until Apple has an answer for this exact build, or the ceiling passes.

    Returns whether it is ready, its state or why not, and App Store Connect's
    id for the build if it was ever seen.

    **A read that fails transiently is one more poll, not the end of the run.**
    The wait begins after the upload was accepted, and until 2026-09-10 a 503
    here escaped as a `SystemExit` and took the rest of the run with it — the
    other platform included — leaving a record that said `uploaded` and
    nothing more. The first fix caught `asc.Refused` while `asc.Client.get`
    still raised a plain `SystemExit`, so a real 503 was asked only once; the
    selftest now goes through that client. What `transient` refuses still
    escapes, and `ship_platform` records it with the recovery command.
    """
    started = time.monotonic()
    doubted = False
    build_id, state = None, None
    while True:
        try:
            build_id, state = processing_state(platform, version, number)
            verdict, reason = wait_verdict(state)
        except (asc.Refused, OSError) as error:
            if not transient(error):
                raise
            verdict, reason = "wait", f"App Store Connect did not answer ({first_line(error)}); asking again"
        elapsed = time.monotonic() - started
        print(f"  [{elapsed / 60:5.1f}m / {PROCESSING_CEILING / 60:.0f}m] {platform} {number}: {reason}")
        if verdict == "ready":
            print(f"  Apple took {elapsed / 60:.1f} minutes ({EXPECTED_WAIT})")
            return True, state, build_id
        if verdict == "stop":
            return False, f"{state}: {reason}", build_id
        if not doubted and (doubt := ingest_doubt(elapsed, build_id is not None)):
            print(f"  {doubt}")
            doubted = True
        if elapsed >= PROCESSING_CEILING:
            return False, f"still {state or 'not visible'} after {PROCESSING_CEILING / 60:.0f} minutes", build_id
        time.sleep(POLL_SECONDS)


def distribution_logs(temp: Path, scheme: str, since: float) -> list[Path]:
    """This export's log bundles in `temp`: named for its scheme, and written since it began.

    Xcode names a bundle `<scheme>_<local time>.xcdistributionlogs`, so `NoSpoilers_` is the Mac
    export's and `NoSpoilersApp_` the iOS one's; the underscore keeps the first from matching the
    second. The directory holds every export this user has run, FunMax's included.
    """
    return sorted(
        path
        for path in temp.glob(f"{scheme}_*.xcdistributionlogs")
        if path.is_dir() and path.stat().st_mtime >= since
    )


def keep_distribution_logs(scheme: str, since: float, work: Path) -> None:
    """Copy this export's log bundles beside the record, where `Ship` publishes them.

    **Xcode writes them to the per-user temp directory and ignores `TMPDIR`**, so a rule on the
    build's temp directory published nothing on Ship #8, the run whose one useful output was Apple's
    refusal inside such a bundle. Losing them costs a diagnosis rather than a delivery, so a failure
    to copy is said and the run goes on.
    """
    try:
        temp = Path(
            subprocess.run(
                ["getconf", "DARWIN_USER_TEMP_DIR"], capture_output=True, text=True, check=True
            ).stdout.strip()
        )
        for bundle in distribution_logs(temp, scheme, since):
            shutil.copytree(bundle, work / bundle.name, dirs_exist_ok=True)
            print(f"  kept {bundle.name} for the run's artifacts")
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"  could not keep the export's distribution logs: {first_line(error)}", file=sys.stderr)


def step(command: list[str], limit: float) -> int:
    """Run one Apple tool with its output streaming into the log, bounded."""
    try:
        return subprocess.run(command, cwd=REPO, env=tooling_environment(), timeout=limit).returncode
    except subprocess.TimeoutExpired:
        print(f"{command[0]} {command[1]} ran past {limit / 60:.0f} minutes and was stopped", file=sys.stderr)
        return 124


def claim(tag: str, sha: str, subject: str, repo: Path = REPO) -> bool:
    """Tag `sha` and push it; True only when origin now holds this run's own tag object.

    **Every reservation carries its own identifier.** A tag object is its
    content: two runs tagging one commit with one message, as one person, in
    one second, write byte-identical objects, and a push that sets a ref to the
    object it already holds succeeds — so both runs believed the number theirs.
    The `Reservation:` line makes each object unique, which makes the second
    push a refusal, and origin is read back rather than the push's exit status
    believed. False means another run holds the tag; failing to reach origin at
    all is a hard stop, since then nothing is reserved. A lost claim deletes the
    local tag, because an agent's checkout outlives the run and a stale
    `build/N` would clobber the next `fetch --tags`.
    """
    distribute.git(
        "tag", "-a", tag, sha,
        "-m", subject,
        "-m", RESERVED_BY,
        "-m", f"Reservation: {uuid.uuid4()} on {socket.gethostname()}",
        repo=repo,
    )
    mine = distribute.git("rev-parse", f"refs/tags/{tag}", repo=repo).strip()
    refusal = ""
    try:
        distribute.git("push", "--quiet", "origin", f"refs/tags/{tag}", repo=repo)
    except subprocess.CalledProcessError as error:
        refusal = error.stderr.strip()
    try:
        listed = distribute.git("ls-remote", "origin", f"refs/tags/{tag}", repo=repo)
    except subprocess.CalledProcessError as error:
        distribute.git("tag", "-d", tag, repo=repo)
        raise SystemExit(
            f"could not read {tag} back from origin, so it is not known to be reserved and nothing "
            f"was built:\n{refusal or error.stderr.strip()}"
        ) from None
    held = [line.split()[0] for line in listed.splitlines() if line.split()[1:] == [f"refs/tags/{tag}"]]
    if held == [mine]:
        return True
    distribute.git("tag", "-d", tag, repo=repo)
    if held:
        return False
    raise SystemExit(
        f"could not push {tag}, so it is not reserved and nothing was built:\n"
        f"{refusal or 'the push reported success, and origin does not hold the tag'}"
    )


def reserve_number(sha: str, platform: str, version: str) -> int:
    """Choose the next build number and make it this run's by claiming its tag.

    The claim is the lock. Two runs that chose the same N — a laptop and an agent
    a minute apart, or `Ship iOS` and `Ship macOS` on one commit — cannot both
    hold `build/N`, so the loser learns it here, in seconds, and chooses again,
    rather than at upload after an archive. `next_build_number` fetches tags
    first, so the winner's tag moves it on.
    """
    for attempt in range(1, RESERVE_ATTEMPTS + 1):
        number = int(version_helper("next_build_number"))
        tag = f"build/{number}"
        if claim(tag, sha, f"build {number}: {platform} v{version}"):
            return number
        print(f"  {tag} was taken by another run (attempt {attempt} of {RESERVE_ATTEMPTS}); choosing again")
    raise SystemExit(f"lost the build-number race {RESERVE_ATTEMPTS} times running; something else is shipping")


def write_record(path: Path, record: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, indent=2) + "\n")


def ship_platform(platform: str, version: str, number: int, work: Path, entry: dict, save, archive_only: bool) -> bool:
    """The platform from archive to confirmed delivery, recording every stage in `entry`.

    **Nothing but an interrupt escapes it.** A run that stops for a reason no
    stage anticipated — an App Store Connect error the wait could not ride out,
    an archive with no Info.plist — is recorded as failing in the stage it was
    in, with the recovery that applies from there. Until 2026-09-10 such an
    error escaped, and a record that said `uploaded` named no recovery.
    """
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

    def stages() -> bool:
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
        options.write_bytes(plistlib.dumps(export_options(platform, upload=not archive_only)))
        output = work / f"{platform}-export"
        verb = "exporting" if archive_only else "exporting and uploading"
        print(f"\n==> {platform}: {verb} — limit {EXPORT_LIMIT / 60:.0f}m")
        # A second early, so a bundle Xcode creates in the second the export starts still counts.
        export_started = time.time() - 1
        export_failed = step(export_command(archive, options, output), EXPORT_LIMIT)
        keep_distribution_logs(scheme, export_started, work)
        if export_failed:
            return failed(
                "export",
                "xcodebuild -exportArchive failed. It prints a digest; Apple's verbatim answer is in "
                "IDEDistributionProvisioning.log inside the .xcdistributionlogs bundle kept beside this "
                "record (the ship/distribution-logs artifact on Ship)",
                recovery_for("archived", platform, number, archive_only),
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
        ready, state, build_id = await_processing(platform, version, number)
        # Kept whether or not it is ready: it is the name App Store Connect's own API and pages use.
        if build_id is not None:
            entry["asc_build_id"] = build_id
        if not ready:
            return failed("processing", state, recovery_command(platform, number))
        reached("processed", processing=state)

        print(f"\n==> {platform}: delivering build {number} to the internal testers — limit {DELIVERY_LIMIT / 60:.0f}m")
        delivery = [
            sys.executable, str(SCRIPTS / "testflight_distribute.py"),
            "--platform", platform, "--build", str(number), "--apply",
        ]
        try:
            handed = subprocess.run(delivery, cwd=REPO, timeout=DELIVERY_LIMIT).returncode
        except subprocess.TimeoutExpired:
            return failed(
                "delivery",
                f"testflight_distribute.py ran past {DELIVERY_LIMIT / 60:.0f} minutes and was stopped",
                recovery_command(platform, number),
            )
        if handed:
            return failed("delivery", "testflight_distribute.py did not confirm the delivery", recovery_command(platform, number))
        reached("delivered")
        return True

    try:
        return stages()
    except (SystemExit, Exception) as error:
        if not isinstance(error, SystemExit):
            traceback.print_exc()
        reached_so_far = entry["stage"]
        return failed(
            FAILING_STAGE.get(reached_so_far, reached_so_far),
            str(error).strip() or type(error).__name__,
            recovery_for(reached_so_far, platform, number, archive_only),
        )


def dry_run_plan(platform: str, number: str, tested: bool, archive_only: bool) -> str:
    """What `--apply` with the same flags would do, said before doing any of it.

    **Built from the flags the real run gets.** `ci-publish.sh --check` exists to
    show what a press would do, and until 2026-09-10 it dropped `--tested` on the
    way here, so `Ship #6` described a test gate its real run would skip.
    """
    gate = "" if tested else "run scripts/verify-core-tests.sh, "
    if archive_only:
        return (
            f"would {gate}stamp {platform} build {number} without reserving it, archive and export "
            "locally, uploading nothing.\nRe-run with --apply."
        )
    return (
        f"would {gate}reserve build {number} as a build/ tag on this commit, archive {platform}, "
        "upload, wait for processing, and deliver that exact build to the internal testers.\n"
        "Re-run with --apply."
    )


def run(platform: str, apply: bool, tested: bool, archive_only: bool) -> int:
    blocked = dirty_reason()
    if blocked:
        print(blocked, file=sys.stderr)
        return 1
    sha = shipped_commit()
    version = version_helper("current_marketing_version")

    client = asc.Client()
    app_id = asc.find_app(client.get)["id"]
    subject = distribute.git("log", "-1", "--format=%s", sha).strip()
    print(f"{platform} {version} from {sha[:12]} {subject}")

    state = asc.closed_train(client.get, app_id, asc.PLATFORM_FLAGS[platform], version)
    if state is not None:
        print(
            f"{platform} {version} is closed to new builds: it is {state}. Nothing was built.\n"
            "  Record the approval and open the next version; that commit then ships like any other:\n"
            f"    scripts/tag_approved.py {platform} {version} --apply\n"
            f"    scripts/open-version.sh {version_helper('suggest_next_version')}",
            file=sys.stderr,
        )
        return 1

    if not apply:
        print(dry_run_plan(platform, version_helper("next_build_number"), tested, archive_only))
        return 0

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
        number = reserve_number(sha, platform, version)
        print(f"==> reserved build/{number} on {sha[:12]}")

    work = Path(tempfile.gettempdir()) / "no-spoilers-ship" / f"build-{number}"
    work.mkdir(parents=True, exist_ok=True)
    record_path = work / "record.json"
    record = {
        "commit": sha,
        "platform": platform,
        "version": version,
        "build": number,
        "reserved": None if archive_only else f"build/{number}",
        "mode": "archive-only" if archive_only else "deliver",
        "tested": tested,
        "started": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "stage": "started",
    }
    save = lambda: write_record(record_path, record)  # noqa: E731
    save()
    shipped = ship_platform(platform, version, number, work, record, save, archive_only)

    outcome = f"failed at {record['failed']}" if record.get("failed") else record["stage"]
    print(f"\nrecord: {record_path}\n  {platform} {version} ({number}): {outcome}")
    return 0 if shipped else 1


def arguments() -> argparse.ArgumentParser:
    # No abbreviations: `--app` would otherwise be `--apply`, past `ci-publish.sh`'s refusal of it.
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0], allow_abbrev=False)
    parser.add_argument(
        "--platform",
        required=True,
        choices=list(PLATFORMS),
        help="one platform per run, as TeamCity's Ship iOS and Ship macOS are. Required, with no "
        "default: a default would ship one platform silently.",
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

    uploading = export_options("ios", upload=True)
    if uploading["method"] != "app-store-connect" or uploading["destination"] != "upload":
        failures.append(f"the export does not upload to App Store Connect: {uploading}")
    if uploading["manageAppVersionAndBuildNumber"] is not False:
        failures.append("Xcode is left free to renumber the build during the upload")
    if export_options("macos", upload=False)["destination"] != "export":
        failures.append("--archive-only would still upload")
    if plistlib.loads(plistlib.dumps(uploading)) != uploading:
        failures.append("the export options do not survive being written as a plist")

    # iOS ships on automatic signing; macOS names what it signs with, because with only the App
    # Manager key automatic signing reached for a cloud-managed certificate and was refused.
    if uploading["signingStyle"] != "automatic" or "provisioningProfiles" in uploading:
        failures.append(f"the iOS export no longer signs automatically, which is what ships it: {uploading}")
    mac = export_options("macos", upload=True)
    wanted = {
        "signingStyle": "manual",
        "provisioningProfiles": {"pomocorp.NoSpoilers.NoSpoilersMac": "No Spoilers Mac App Store"},
        "signingCertificate": "Apple Distribution",
        "installerSigningCertificate": "3rd Party Mac Developer Installer",
    }
    if {key: mac.get(key) for key in wanted} != wanted or plistlib.loads(plistlib.dumps(mac)) != mac:
        failures.append(f"the macOS export does not name its profile and both certificates: {mac}")

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
    if parser.parse_args(["--platform", "ios"]).tested:
        failures.append("the test gate is skipped by default")
    for asked, wrong in (([], "--platform has a default, so asking for nothing ships something"),
                         (["--platform", "all"], "--platform all is accepted, so one run ships two platforms")):
        try:
            with open(os.devnull, "w") as quiet:
                stderr, sys.stderr = sys.stderr, quiet
                try:
                    parser.parse_args(asked)
                finally:
                    sys.stderr = stderr
            failures.append(wrong)
        except SystemExit:
            pass

    import contextlib
    import io
    import urllib.error
    import urllib.request

    def muted(call):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return call()

    for error, wanted in (
        (asc.Refused("GET", "/v1/builds", 503, "Service Unavailable"), True),
        (asc.Refused("GET", "/v1/builds", 429, "Too Many Requests"), True),
        (asc.Refused("GET", "/v1/builds", 403, ""), False),
        (urllib.error.URLError("connection reset by peer"), True),
        (SystemExit("no private key at ~/.appstoreconnect"), False),
    ):
        if transient(error) is not wanted:
            failures.append(f"{first_line(error)!r} was not judged {'transient' if wanted else 'final'}")

    # The export's log bundles, from a directory that holds every export this user ever ran: this
    # scheme's, from this export, and nobody else's. Ship #8's were published by no rule at all.
    with tempfile.TemporaryDirectory() as scratch:
        temp = Path(scratch)
        for name, age in (
            ("NoSpoilers_now", 0),
            ("NoSpoilers_last_week", 7 * 86400),
            ("NoSpoilersApp_now", 0),
            ("SuperFunMaxMusic_now", 0),
        ):
            bundle = temp / f"{name}.xcdistributionlogs"
            bundle.mkdir()
            stamp = time.time() - age
            os.utime(bundle, (stamp, stamp))
        mac = [path.name for path in distribution_logs(temp, "NoSpoilers", time.time() - 60)]
        if mac != ["NoSpoilers_now.xcdistributionlogs"]:
            failures.append(f"the Mac export kept another export's log bundles, or lost its own: {mac}")
        ios = [path.name for path in distribution_logs(temp, "NoSpoilersApp", time.time() - 60)]
        if ios != ["NoSpoilersApp_now.xcdistributionlogs"]:
            failures.append(f"the iOS export kept another export's log bundles, or lost its own: {ios}")

    # **Through the real `asc.Client`, with only the network and the key
    # replaced.** The second review, 2026-09-10: the wait caught `asc.Refused`
    # while the client still raised a plain `SystemExit`, and this selftest
    # scripted `processing_state` itself, so it passed a retry no real 503 got.
    # The review's case, 2026-09-10: an upload accepted, then an App Store
    # Connect error. A 503 is ridden out; a 403 is recorded against processing
    # with the recovery, and returned rather than raised.
    def apple(*refusals: int, state: str = "READY_FOR_BETA_TESTING"):
        pending = list(refusals)
        asked: list[str] = []

        def urlopen(request, timeout):
            url = request.full_url
            asked.append(url)
            if pending:
                raise urllib.error.HTTPError(url, pending.pop(0), "refused", None, io.BytesIO(b"{}"))
            if url.endswith("/buildBetaDetail"):
                body = {"data": {"attributes": {"internalBuildState": state}}}
            elif "/v1/apps?" in url:
                body = {"data": [{"id": "app", "attributes": {"bundleId": asc.BUNDLE_ID}}]}
            else:
                body = {"data": [{"id": "asc-10025", "attributes": {"version": "10025"}}]}
            return io.BytesIO(json.dumps(body).encode())

        return urlopen, asked

    patched = {name: globals()[name] for name in ("step", "bundle_problems", "keep_distribution_logs", "POLL_SECONDS")}
    network = (urllib.request.urlopen, asc.require_key, asc.token)
    try:
        globals()["POLL_SECONDS"] = 0.0
        globals()["keep_distribution_logs"] = lambda *_: None
        asc.require_key = lambda *_: None
        asc.token = lambda *_: "selftest"

        urllib.request.urlopen, asked = apple(503)
        try:
            waited = muted(lambda: await_processing("ios", "1.1.4", 10025))
        except SystemExit as error:
            waited = (False, first_line(error), None)
        if waited[0] is not True or len(asked) < 2:
            failures.append(f"a 503 from App Store Connect while waiting ended the wait instead of asking again: {waited}")
        if waited[2] != "asc-10025":
            failures.append(f"the wait did not return App Store Connect's id for the build: {waited}")

        urllib.request.urlopen, asked = apple(403)
        try:
            muted(lambda: await_processing("ios", "1.1.4", 10025))
            failures.append("a 403 from App Store Connect while waiting was asked again instead of ending the wait")
        except SystemExit as error:
            if not isinstance(error, asc.Refused) or error.status != 403 or len(asked) != 1:
                failures.append(f"a 403 while waiting did not end the wait as a Refused 403 on the first ask: {error!r}")

        globals()["step"] = lambda command, limit: 0
        globals()["bundle_problems"] = lambda *_: []
        with tempfile.TemporaryDirectory() as scratch:
            urllib.request.urlopen, _ = apple(403)
            entry = {"version": "1.1.4", "stage": "started"}
            shipped = muted(lambda: ship_platform("ios", "1.1.4", 10025, Path(scratch), entry, lambda: None, False))
            if shipped is not False or entry.get("failed") != "processing":
                failures.append(f"an App Store Connect error after the upload escaped or was misplaced: {entry}")
            if entry.get("recovery") != recovery_command("ios", 10025):
                failures.append("an upload stranded by an App Store Connect error names no recovery")

            # A build Apple shows and then stops on: the record names it as App Store Connect does.
            urllib.request.urlopen, _ = apple(state="SELFTEST_UNSEEN_STATE")
            entry = {"version": "1.1.4", "stage": "started"}
            muted(lambda: ship_platform("ios", "1.1.4", 10025, Path(scratch), entry, lambda: None, False))
            if entry.get("failed") != "processing" or entry.get("asc_build_id") != "asc-10025":
                failures.append(f"the record does not carry App Store Connect's id for a build it saw: {entry}")

            def unreadable(*_):
                raise FileNotFoundError("Info.plist")

            globals()["bundle_problems"] = unreadable
            entry = {"version": "1.1.4", "stage": "started"}
            shipped = muted(lambda: ship_platform("macos", "1.1.4", 10025, Path(scratch), entry, lambda: None, False))
            if shipped is not False or entry.get("failed") != "archive" or entry.get("recovery") is not None:
                failures.append(f"a crash before anything was uploaded was not recorded as one: {entry}")
    finally:
        globals().update(patched)
        urllib.request.urlopen, asc.require_key, asc.token = network

    # The reservation, against a throwaway origin and two clones of it, as one
    # person in one second — the race the review reproduced. The premise is
    # checked too: identical tag objects both push, so a claim without a line of
    # its own would hand both runs the number.
    pinned = {
        "GIT_AUTHOR_NAME": "selftest", "GIT_AUTHOR_EMAIL": "selftest@example.invalid",
        "GIT_COMMITTER_NAME": "selftest", "GIT_COMMITTER_EMAIL": "selftest@example.invalid",
        "GIT_AUTHOR_DATE": "2026-09-10T12:00:00Z", "GIT_COMMITTER_DATE": "2026-09-10T12:00:00Z",
        "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
    }
    before = {name: os.environ.get(name) for name in pinned}
    os.environ.update(pinned)
    try:
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            origin = root / "origin.git"
            clones = [root / "laptop", root / "agent"]
            subprocess.run(["git", "init", "--quiet", "--bare", str(origin)], check=True, capture_output=True)
            for clone in clones:
                subprocess.run(["git", "clone", "--quiet", str(origin), str(clone)], check=True, capture_output=True)
            distribute.git("commit", "--quiet", "--allow-empty", "-m", "the work", repo=clones[0])
            distribute.git("push", "--quiet", "origin", "HEAD:refs/heads/main", repo=clones[0])
            distribute.git("fetch", "--quiet", "origin", repo=clones[1])
            sha = distribute.git("rev-parse", "HEAD", repo=clones[0]).strip()

            try:
                for clone in clones:
                    distribute.git("tag", "-a", "build/10024", sha, "-m", "build 10024: ios v1.1.4", repo=clone)
                    distribute.git("push", "--quiet", "origin", "refs/tags/build/10024", repo=clone)
            except subprocess.CalledProcessError:
                failures.append("identical tags no longer both push, so this no longer reproduces the race")

            won = claim("build/10025", sha, "build 10025: ios v1.1.4", repo=clones[0])
            lost = claim("build/10025", sha, "build 10025: ios v1.1.4", repo=clones[1])
            if won is not True:
                failures.append("an uncontested build number was not reserved")
            if lost is not False:
                failures.append("two runs reserved one build number in the same second")
            held = distribute.git("ls-remote", "origin", "refs/tags/build/10025", repo=clones[1]).split()
            winner = distribute.git("rev-parse", "refs/tags/build/10025", repo=clones[0]).strip()
            if held[:1] != [winner] or distribute.git("tag", "-l", "build/10025", repo=clones[1]).strip():
                failures.append("origin does not hold the winner's tag, or the loser kept its own")
    finally:
        for name, value in before.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value

    # One `ship(...)` function makes every Ship configuration, so its timeout is theirs, and a
    # platform this script can ship that no configuration names would never ship unattended.
    settings = (REPO / ".teamcity" / "settings.kts").read_text()
    shipping = settings[settings.index("fun ship("):]
    timeout = re.search(r"executionTimeoutMin = (\d+)", shipping)
    needed = worst_case() + RECORD_MARGIN
    if timeout is None or int(timeout.group(1)) * 60 < needed:
        failures.append(
            f"Ship's TeamCity timeout is under this script's worst case of {needed / 60:.0f} minutes, "
            "so TeamCity could end a run before it records why"
        )
    configured = re.findall(r'= ship\("(\w+)"', settings)
    if sorted(configured) != sorted(PLATFORMS):
        failures.append(f"the Ship configurations are {configured}, not one for each of {list(PLATFORMS)}")

    # The dry run describes the run the same flags would start: Ship #6's plan
    # named a test gate that `--tested` skips.
    if "verify-core-tests" in dry_run_plan("ios", "10025", tested=True, archive_only=False):
        failures.append("a dry run given --tested still describes the test gate")
    if "verify-core-tests" not in dry_run_plan("ios", "10025", tested=False, archive_only=False):
        failures.append("a dry run without --tested does not describe the test gate")
    archive_plan = dry_run_plan("macos", "10025", tested=True, archive_only=True)
    if "reserve build" in archive_plan or "uploading nothing" not in archive_plan:
        failures.append(f"an --archive-only dry run describes a reservation or an upload: {archive_plan!r}")

    # `--apply` belongs to the wrapper, and `--check --apply` was a release under a banner saying
    # it changed nothing (the second review). Run from a lone copy with no keys under its HOME,
    # so a regression finds no `submit_build.py` beside it rather than shipping anything.
    with tempfile.TemporaryDirectory() as scratch:
        lone = Path(scratch) / "scripts" / "ci-publish.sh"
        lone.parent.mkdir()
        shutil.copy2(SCRIPTS / "ci-publish.sh", lone)
        for flags in (["--check", "--apply"], ["--apply"]):
            said = subprocess.run(
                [str(lone), "--platform", "ios", *flags],
                capture_output=True, text=True, timeout=60, env={**os.environ, "HOME": scratch},
            )
            if said.returncode != 1 or "--apply is not an argument" not in said.stderr or "==> Asserting" in said.stdout:
                failures.append(f"ci-publish.sh {' '.join(flags)} was not refused before its preflight")
    try:
        muted(lambda: arguments().parse_args(["--platform", "ios", "--app"]))
        failures.append("submit_build.py read --app as --apply")
    except SystemExit:
        pass

    for failure in failures:
        print(f"  FAIL {failure}", file=sys.stderr)
    print(f"submit_build selftest: 56 cases, {len(failures)} failure(s)")
    return 1 if failures else 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    speak_in_order()
    asked = arguments().parse_args()
    return run(asked.platform, asked.apply, asked.tested, asked.archive_only)


if __name__ == "__main__":
    sys.exit(main())
