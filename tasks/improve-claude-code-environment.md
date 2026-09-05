# Improve the Claude Code environment

## The issue

The repository has a substantial Claude Code control plane, but its root memory, always-on rules,
prompt hooks, and workflow references repeat the same routing policy. Scoped operational detail is
loaded for unrelated work, read-only agents rely on prose rather than a read-only permission mode,
and task and bug-investigation workflows are not independently discoverable. This wastes context
and makes adherence less reliable as the project evolves.

## Brainstorming

- Keep the existing layout and polish wording only: rejected because duplication and unconditional
  context loading are structural problems.
- Put more guidance in `CLAUDE.md`: rejected because root memory is loaded into every conversation
  and Claude Code already provides native discovery for rules, skills, and agents.
- Replace the setup with external plugins: rejected because the repository already has strong,
  project-specific conventions and no missing capability justifies a new dependency.

## The plan

1. Reduce root memory to crucial repository-wide facts, invariants, approval boundaries, and exact
   verification commands.
2. Make rules, skills, agents, and references self-routing through precise metadata and ownership;
   remove duplicated prompt-injection hooks.
3. Add focused task-management and bug-investigation workflows, strengthen test-writing guidance,
   and make review agents mechanically read-only.
4. Move simulator and App Store operational detail to their scoped owners and reconcile stale
   references.
5. Validate settings, frontmatter, shell hooks, routing metadata, and the resulting diff with the
   installed Claude Code.

## Tracking

- Status: implementation complete and verified.
- Approved direction: the user explicitly requested a clinical, low-supervision Claude Code setup
  and authorized updating or removing configuration that does not meet the evidence threshold.
- Shipped in the working tree:
  - root memory reduced from 121 lines to 31 lines without a `.claude/` index
  - duplicated routing and no-op formatting hooks removed
  - task and bug workflows made independently discoverable
  - feature, test, release, and configuration-maintenance routing tightened
  - review agents restricted to `Read`, `Grep`, and `Glob` under plan mode
  - shared settings reduced to destructive-command and credential-path denies; personal convenience
    permissions moved to the local example
  - stale simulator names and first-launch registration guidance moved to the owning rule, guide,
    release workflow, and script docstring
  - App Store Connect documentation reconciled with the current three `--apply` writers
  - redundant general and workflow routing guides removed
- Verification passed:
  - `claude doctor` — project settings accepted with no schema warning; one unrelated local keychain
    warning recorded in `tasks/restore-claude-code-keychain-access.md`
  - `claude -p "/skill-doctor"` — all project skills discovered; the two new skills account for
    about 200 tokens of description context combined
  - JSON parsing for both settings files
  - YAML frontmatter parsing for every project skill, agent, rule, and command
  - reference, root-size, agent-tool, executable-bit, Python syntax, and `git diff --check` checks
  - `scripts/verify-python-selftests.sh` — 175 cases across five scripts, 0 failures
- Residual risk: a model-backed `claude -p` subagent smoke test could not run because this machine is
  not logged in. Frontmatter and discovery were validated statically; the local authentication issue
  has its own task. No application build was run because no product code or executable behavior
  changed.
