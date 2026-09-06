# Add TeamCity diagnostics

## The issue

Claude can see that this repository builds on TeamCity, but it has no safe project-owned command
for answering whether a revision passed, which leg failed, why a build is queued, or what the
structured failure and relevant log evidence say. Reconstructing REST calls ad hoc risks selecting
the wrong build and exposing the full-admin access token in process arguments.

## The plan

1. Adopt the shared read-only TeamCity plugin and its repository shim rather than copying its
   implementation.
2. Describe this project's actual chain in `.teamcity/cli.json`, keeping verification health
   separate from manually triggered delivery configurations.
3. Add the CLI's offline self-test to the canonical Python verification wrapper and document the
   new control-plane owner.
4. Verify configuration discovery, credential isolation, live status access, and Claude skill
   discovery.

Success means `scripts/teamcity.py --selftest` passes without network access and its read-only
commands can identify the current No Spoilers builds without printing or persisting a credential.

## Tracking

- Status: implementation complete and verified.
- The shared implementation and skill are owned by `npomfret/agent-standards`; this repository
  owns only its plugin enablement, locator shim, and project configuration.
- `.teamcity/cli.json` names the live `NoSpoilers` project, `Verdict` composite, verification
  configurations, and test-producing legs. Manually triggered delivery configurations are excluded
  from the health summary but remain queryable by name through `builds`.
- `claude plugin list` reports `teamcity@npomfret` 1.0.0 installed and enabled.
- `python3 scripts/teamcity.py --selftest` passed, including the assertions that credentials never
  enter request arguments and hostile URLs remain shell-quoted.
- `scripts/verify-python-selftests.sh` passed all seven script self-tests.
- Live read-only verification passed: `status` returned green build 72 for `Build`, `Checks`,
  `Tests`, and `Verdict`; `chain` resolved build 3238 to its three green legs; `queue` reported no
  running or waiting builds. No TeamCity state was changed.
- Residual risk: live build 72 tested `3661ce7e`, not the newer local or `origin/main` revision. The
  helper reported that gap explicitly; it does not imply those newer revisions are green.
