#!/usr/bin/env python3
"""Run the shared TeamCity CLI, wherever this machine keeps it.

Copy this to `scripts/teamcity.py` in a project. The implementation lives in the
`teamcity` plugin of npomfret/agent-standards; this file only finds it, so that
`npm run tc:*` behaves the same for a person at a shell and for an agent inside
a session. Everything project-specific is `.teamcity/cli.json`.

Set TEAMCITY_CLI to override the search.
"""

from __future__ import annotations

import os
import runpy
import sys
from pathlib import Path

PLUGINS = Path.home() / ".claude" / "plugins"


def candidates():
    override = os.environ.get("TEAMCITY_CLI")
    if override:
        yield Path(override).expanduser()
    root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if root:
        yield Path(root) / "scripts" / "teamcity.py"
    # Installed copies, newest version first, then the marketplace checkout.
    yield from sorted(PLUGINS.glob("cache/*/teamcity/*/scripts/teamcity.py"), reverse=True)
    yield from sorted(PLUGINS.glob("marketplaces/*/plugins/teamcity/scripts/teamcity.py"))


def main() -> int:
    for candidate in candidates():
        if candidate.is_file():
            sys.argv[0] = str(candidate)
            runpy.run_path(str(candidate), run_name="__main__")
            return 0
    sys.exit(
        "The shared TeamCity CLI is not on this machine. Install it with:\n"
        "  claude plugin marketplace add npomfret/agent-standards\n"
        "  claude plugin install teamcity@npomfret\n"
        "or point TEAMCITY_CLI at a checkout of agent-standards."
    )


if __name__ == "__main__":
    raise SystemExit(main())
