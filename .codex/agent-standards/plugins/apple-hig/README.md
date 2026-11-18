# apple-hig

Justin Wetch's apple-hig skill, copied from
[justinwetch/HIGAgentSkills](https://github.com/justinwetch/HIGAgentSkills) at
`2206ff935b4affa9ad249a5399a3e8e29f5f6edd` (release 2026-09-27, Apple source
snapshot 2026-09-12). MIT for the repository's own material; the HIG text it
distils belongs to Apple. See `LICENSE` and `NOTICE`.

It is the Apple Human Interface Guidelines as 157 short reference pages, with a
routing index that loads the pages a task needs, an opt-in enforce mode for an
independent review, and `/duo` for adapting an iOS app to iPhone Duo.

What was copied is the upstream runtime set, as its own
`scripts/package_runtime_zip.py` defines it, except its `README.md`: `SKILL.md`, `routing-index.md`,
`references/`, `scripts/hig_route.py`, `scripts/hig_enforce.py` and
`commands/duo.md`. The command sits in this plugin's `commands/`, so Claude Code
offers `/duo` wherever the plugin is enabled.

Two changes from upstream, both because upstream installs its command by
copying it into a user-level folder, which is machine-local config:

- `SKILL.md`: the paragraph telling the agent to copy `commands/duo.md` into the
  host's command directory now says the plugin provides `/duo`; its two
  pointers to the upstream README now point here, and "install it with the
  skill" reads "provided by the plugin".
- The upstream `README.md` was not copied. It is install instructions and
  release notes.

The marketplace entry sets `defaultEnabled: false`. Enable `apple-hig@npomfret`
in the committed `.claude/settings.json` of a project that has an Apple app.

To take a newer upstream version: read the upstream diff since the commit
above, copy the runtime set over this one, make the two changes again, update
the commit here and in `plugin.json`, then `python3 sync.py bump plugins/apple-hig`.
