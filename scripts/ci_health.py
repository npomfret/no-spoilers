#!/usr/bin/env python3
"""Is Xcode Cloud wired to the right projects, and is anything mid-hijack.

Run this **immediately after Integrate > Create Workflow**, and before trusting
any Xcode Cloud state. It exists because of the fault in
`tasks/15-xcode-cloud-product-hijack.md`: Create Workflow does not reliably
create. When the product list is unlistable it seizes an existing product,
renames it to the project you ran it from, repoints that product's repository
at your repo, and aborts. The sibling project then builds nothing, silently,
while its workflow still reads as valid — the trigger follows the *product's*
repository attachment, not the workflow's.

Two projects share this team, `no-spoilers` and `super-funmax-music`, and the
fault has now run three times in both directions: 2026-08-08 it took
FunMaxMusic's product for this repo, 2026-08-12 11:xx it took this repo's for
FunMaxMusic, and 2026-08-12 14:53 it took FunMaxMusic's replacement — that last
one while this script reported PASS on a listable, healthy, single-product list
minutes earlier. Four days of that project's builds were lost to the first
before anyone noticed. Note what this means: a PASS here says nothing is
*currently* crossed, never that the wizard is safe to run. So the question this
answers is not "is my CI fine" but **"is my CI standing on someone else's
project"**, and it is asked in both directions:

- no product of ours may point at anyone else's repository
- no product of theirs may point at ours

The second is the one that matters and the one nothing else checks. A hijack is
invisible from the victim's side until their builds stop.

`GET`s only. It cannot repair anything — `ciProducts` has no `PATCH`, and the
only lever is `DELETE`, which takes the workflow and run history with it. Doing
that is a person's decision, taken with task 15 open.

Exit code answers "does this need a person": 0 clean, 1 not.

Usage:
    scripts/ci_health.py
    scripts/ci_health.py --selftest
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.request

import appstore_status as asc


def repository() -> str:
    """This repo's GitHub name, from its own remote.

    Read rather than recorded. The whole point of this script is that a written
    -down identity drifts from the server's, and a checker holding a stale idea
    of which repository is "ours" would confirm a hijack as healthy.
    """
    url = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    return url.rstrip("/").removesuffix(".git").rsplit("/", 1)[-1]


def assess(products: list[dict], app_id: str, repo: str) -> list[str]:
    """Everything wrong, in plain words. Empty means safe to proceed.

    Pure, so the cases below can be replayed offline in `_selftest` from the
    states this team has actually been in.
    """
    problems: list[str] = []

    # A listed product that no longer resolves by id is a ghost, and must not
    # count. The list is a cache that has now been caught lying in *both*
    # directions: reporting zero on 2026-08-12 while two products still
    # resolved, and on the same afternoon still naming a product for minutes
    # after a DELETE that answered 204. Counting a ghost is how this script
    # reported "2 products" for a team holding one, which in turn produced the
    # conclusion that two can coexist — from a team that has never held two.
    live = [p for p in products if not p["ghost"]]

    if not live:
        problems.append(
            "no product resolves by id. That is the state the wizard has always "
            "created from rather than seized — but it cannot be proven from here: "
            "an unlistable product is invisible to a list and can only be found by "
            "an id you already know. Read tasks/15-xcode-cloud-product-hijack.md "
            "before the wizard."
        )

    for product in live:
        name, pid = product["name"], product["id"]
        mine = product["appId"] == app_id
        repos = product["repositories"]
        touches_us = repo in repos

        if product["appId"] is None:
            problems.append(
                f"{name} ({pid}) has no app relationship — this is the orphan "
                "signature. It makes the whole product list unlistable, which is "
                "what causes the next Create Workflow to seize a sibling's product. "
                "DELETE is the only repair."
            )
        if product["error"]:
            problems.append(f"{name} ({pid}) could not be read fully: {product['error']}")

        if mine and repos and not touches_us:
            problems.append(
                f"{name} ({pid}) builds this app but is attached to "
                f"{', '.join(repos)} rather than {repo}. Our product is pointed at "
                "someone else's repository."
            )
        if not mine and touches_us:
            problems.append(
                f"{name} ({pid}) does NOT build this app yet is attached to {repo}. "
                "Another project's product has been pointed at this repository — "
                "that project is the one now building nothing. Do not push."
            )

        for workflow in product["workflows"]:
            if mine and not workflow["container"].startswith("NoSpoilers/"):
                problems.append(
                    f"{name} ({pid}) workflow {workflow['name']!r} builds "
                    f"{workflow['container']}, which is not this repo's project."
                )
            if not mine and workflow["container"].startswith("NoSpoilers/"):
                problems.append(
                    f"{name} ({pid}) workflow {workflow['name']!r} builds this repo's "
                    f"{workflow['container']} from another project's product."
                )
    return problems


def gather(client: asc.Client, app_id: str) -> list[dict]:
    """Every product with the app, repositories and workflows hanging off it."""

    def sub(path: str) -> tuple[list[dict], str | None]:
        try:
            return client.get(path)["data"], None
        except SystemExit as stop:
            return [], str(stop).split("\n")[0]

    detailed = []
    for product in asc.ci_products(client.get):
        # Re-fetch every listed id. Being in the list is not evidence of
        # existing — see the note in `assess`.
        _, gone = sub(f"/v1/ciProducts/{product['id']}")
        repos, repo_error = sub(f"/v1/ciProducts/{product['id']}/primaryRepositories")
        flows, flow_error = sub(f"/v1/ciProducts/{product['id']}/workflows")
        detailed.append(
            {
                **product,
                "ghost": bool(gone),
                "mine": product["appId"] == app_id,
                "repositories": [r["attributes"]["repositoryName"] for r in repos],
                "workflows": [
                    {
                        "name": w["attributes"]["name"],
                        "container": w["attributes"]["containerFilePath"],
                        "enabled": w["attributes"]["isEnabled"],
                    }
                    for w in flows
                ],
                "error": repo_error or flow_error,
            }
        )
    return detailed


def render(products: list[dict], problems: list[str], repo: str) -> str:
    live = [p for p in products if not p["ghost"]]
    ghosts = [p for p in products if p["ghost"]]
    lines = [f"{len(live)} Xcode Cloud product(s); this repo is {repo}", ""]
    for product in ghosts:
        lines.append(
            f"{product['name']}  {product['id']}  (GHOST — listed but 404 by id; "
            "deleted, and the list has not caught up. Not counted.)"
        )
    if ghosts:
        lines.append("")
    for product in live:
        owner = "ours" if product["mine"] else "another project"
        lines.append(f"{product['name']}  {product['id']}  ({owner})")
        lines.append(f"    app          {product['appId'] or 'NONE — orphaned'}")
        lines.append(f"    repository   {', '.join(product['repositories']) or '(none)'}")
        for workflow in product["workflows"]:
            state = "enabled" if workflow["enabled"] else "DISABLED"
            lines.append(f"    workflow     {workflow['name']} -> {workflow['container']} ({state})")
        lines.append("")

    if not problems:
        lines.append("PASS  every product resolves its app, and no project is")
        lines.append("      attached to another's repository.")
        return "\n".join(lines)

    lines.append(f"STOP  {len(problems)} problem(s):")
    lines.extend(f"  - {p}" for p in problems)
    lines.append("")
    lines.append("Do NOT retry Create Workflow. Retrying is what seizes the next product.")
    return "\n".join(lines)


def main() -> int:
    argparse.ArgumentParser(description=__doc__.split("\n")[0]).parse_args(
        [a for a in sys.argv[1:] if a != "--selftest"]
    )
    client = asc.Client()
    app_id = asc.find_app(client.get)["id"]
    repo = repository()
    products = gather(client, app_id)
    problems = assess(products, app_id, repo)
    print(render(products, problems, repo))
    return 1 if problems else 0


def _product(**overrides) -> dict:
    product = {
        "id": "NEW",
        "name": "NoSpoilersApp",
        "created": "2026-08-12T12:00:00.000Z",
        "appId": "6761343835",
        "repositories": ["no-spoilers"],
        "workflows": [{"name": "Default", "container": "NoSpoilers/NoSpoilers.xcodeproj", "enabled": True}],
        "error": None,
        "ghost": False,
    }
    product.update(overrides)
    return product


def _selftest() -> int:
    """Offline. The states this team has actually been in, replayed."""
    OURS, THEIRS, REPO = "6761343835", "6770023782", "no-spoilers"
    failures: list[str] = []

    def expect(name: str, products: list[dict], fragment: str | None) -> None:
        found = assess(products, OURS, REPO)
        if fragment is None:
            if found:
                failures.append(f"{name}: expected clean, got {found}")
        elif not any(fragment in problem for problem in found):
            failures.append(f"{name}: nothing mentioning {fragment!r}, got {found}")

    theirs = _product(
        id="CADFB659",
        name="FunMaxMusic",
        appId=THEIRS,
        repositories=["super-funmax-music"],
        workflows=[
            {"name": "Default", "container": "apple/FunMaxMusic/FunMaxMusic.xcodeproj", "enabled": True}
        ],
    )

    # The state to be in: our product and theirs, each minding its own repo.
    expect("healthy pair", [theirs, _product()], None)

    # Nothing resolving is the state every successful creation has started from,
    # but it is still reported: it cannot be *proven* from here, since an
    # unlistable product is invisible to a list and findable only by an id you
    # already hold. Saying so is the whole job — the reversed version of this
    # rule is what cost the third product.
    expect("nothing resolves", [], "no product resolves by id")

    # 2026-08-12, exactly: both records orphaned, wearing each other's names,
    # each attached to one repo and building the other's project.
    seized_from_them = _product(
        id="EDF20772", name="NoSpoilersApp", appId=None, repositories=["no-spoilers"],
        workflows=[
            {"name": "Default", "container": "apple/FunMaxMusic/FunMaxMusic.xcodeproj", "enabled": True}
        ],
    )
    seized_from_us = _product(
        id="1F3A0BBD", name="FunMaxMusic", appId=None, repositories=["super-funmax-music"],
        workflows=[{"name": "Default", "container": "NoSpoilers/NoSpoilers.xcodeproj", "enabled": True}],
    )
    expect("orphan is named", [seized_from_them], "no app relationship")
    both = assess([seized_from_them, seized_from_us], OURS, REPO)
    if len(both) < 4:
        failures.append(f"the real 2026-08-12 state produced only {len(both)} problem(s): {both}")

    # The one that protects the other project, and the reason this script
    # exists: a healthy sibling product that has been repointed at our repo.
    # Our own product is untouched and looks perfect, so nothing else notices.
    expect(
        "sibling dragged onto our repo",
        [_product(), dict(theirs, repositories=["no-spoilers"])],
        "Do not push",
    )

    # And the mirror: ours dragged onto theirs.
    expect(
        "ours dragged onto their repo",
        [dict(_product(), repositories=["super-funmax-music"])],
        "someone else's repository",
    )

    # A sibling product building our .xcodeproj, whatever its repository says.
    expect(
        "sibling building our project",
        [dict(theirs, workflows=[
            {"name": "Default", "container": "NoSpoilers/NoSpoilers.xcodeproj", "enabled": True}
        ])],
        "from another project's product",
    )

    # A read that 500s is a finding, not a crash — the orphan's `app` endpoint
    # does exactly this, and a checker that died on it would report nothing.
    expect("unreadable product", [_product(error="GET /v1/... -> HTTP 500")], "could not be read")

    # 2026-08-12 17:0x: our product was deleted at 15:30 and the list still named
    # it at 17:12, app relationship and all. A ghost must not be counted, or the
    # team reads as occupied when it is empty — which is the difference between
    # the wizard creating and the wizard seizing.
    ghost = _product(id="F6A2F0EB", ghost=True)
    expect("a ghost alone is an empty team", [ghost], "no product resolves by id")
    expect("a ghost does not mask a real product", [ghost, theirs], None)

    # And the mirror: a ghost must not be *checked* either. Its sub-resources all
    # 404, and reporting those as faults would bury the one line that matters.
    expect(
        "ghost sub-resource errors are not reported",
        [dict(ghost, error="GET /v1/.../primaryRepositories -> HTTP 404"), theirs],
        None,
    )

    # `repository()` must agree with the server's spelling of this repo, or
    # every direction check above is comparing against a name that never matches.
    if repository() != REPO:
        failures.append(f"repository() reads {repository()!r}, expected {REPO!r}")

    cases = 12
    print(f"ci_health selftest: {cases} cases, {len(failures)} failure(s)")
    for failure in failures:
        print(f"  - {failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    sys.exit(main())
