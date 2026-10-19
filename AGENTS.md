# No Spoilers

Native iPhone, macOS, and WidgetKit race-weekend timelines. The macOS app is live; iPhone App Store
acceptance is the current product priority.

- The spoiler-free guarantee is architectural. Product data may contain schedule identity,
  location, kind, and timing only; outcome-bearing data must never enter models, storage, fixtures,
  UI, logs, tests, or screenshots.
- Do not add series-owned names, marks, logos, or imagery to product or listing surfaces. Preserve
  the existing legally required trademark disclaimer.
- For non-trivial work, audit upstream callers, downstream effects, lateral precedent, and nearby
  tests before editing. Refactor the current area into a clean host for the requirement, then
  implement and verify.
- Reuse the established pattern. Ask before introducing a dependency, abstraction family, file
  layout, naming convention, or second implementation style.
- Fail loudly when required data is absent. Do not conceal impossible states with defaults,
  sentinels, or optionality.
- Preserve unrelated changes. Do not take destructive actions without approval, and do not claim
  completion without executed command evidence.
- Work on `main`; do not create branches unless explicitly asked.
- Planned work and complex unplanned work require one current task file under `tasks/`; the
  lifecycle is the `task-files:task-files` skill.
- Releases, App Store Connect writes, review replies, and simulator mutation require explicit user
  intent. Inspect the owning script and current remote state immediately before acting.

Verification entry points:

- Shared behavior: `scripts/verify-core-tests.sh`
- Python tooling: `scripts/verify-python-selftests.sh`
- macOS: `scripts/verify-mac-build.sh`
- iPhone: `scripts/verify-ios-build.sh`
- Widget: `scripts/verify-widget-build.sh`

## Scope

Do what was asked, and nothing more. Work that was invented rather than requested is why a task never reaches an end.

### Never invent work

- Never invent a requirement. If the request does not state it and the project does not already require it, it is not a requirement.
- Never widen the scope of a change. The request sets the boundary; a related file, a neighbouring function or a second caller is outside it unless the change cannot work without them.
- Never start adjacent work you thought of yourself: a refactor you noticed, a test you would like to exist, a rename, a tidy-up, a dependency bump, a doc you would have written differently. "While I was in there" is not a reason.
- Never invent edge cases or failure scenarios. Before adding special handling, a fallback or a test for one, cite evidence that it exists: observed data, an actual incident, or a reproducible failure. "It could happen" is not evidence.
- Never treat a suggestion the user has not answered as approval. Silence is not yes, and neither is a suggestion you made yourself.

### Suggest instead

- Noticing work is not permission to do it. Say what you noticed in one line, and stop.
- Put suggestions at the end of the report, after what was actually done, and keep them separate from it so the two are never confused.
- One line each. A suggestion that needs a paragraph is a proposal, and a proposal is asked about before it is written, not after.
- Ask when the request is ambiguous. Do not resolve an ambiguity by building both sides, by building the larger one, or by building the one you find more interesting.

### Finish what was asked

This is not licence to stop early, and scope discipline is not an excuse for leaving something broken.

- A change is finished when what was asked works and has been verified — not when nothing more can be thought of, and not when the first part of it compiles.
- Work the change makes necessary is inside the scope, not outside it: a caller the new signature breaks, a test the change invalidates, a migration the schema now needs. Doing that is finishing the job, not expanding it.
- If the requested change cannot be made without work that was not requested, say so and wait. Do not do it silently, and do not abandon the request because of it.
- Report what was done and what was verified. Do not report intentions, or work you decided against.

*Generated from `npomfret/agent-standards`. Edit the standard there, not this copy.*

## Running commands

How you run commands, and what you ask the user to run. Writing a script that stays in the project is the `scripting` skill's subject; load it before writing one.

### Never hand the user a long command

- Run commands yourself. Ask the user to run something only when it needs them: a login, a password, `sudo`, a device in their hand, an install.
- Never ask the user to type or paste a long command: anything over one line, any chain of `&&`, `;` or `|`, a heredoc, or more than about 80 characters.
- Write it instead to a new executable script in the project's `tmp/` folder, named for what it does (`tmp/install-shellcheck.sh`). Give it `#!/usr/bin/env bash`, `set -euo pipefail` and a comment saying what it does and why. Have it log its detail to a file under `tmp/logs/` and print that path.
- Show the user the script, then ask them to run it with `! tmp/<name>.sh`, so its output lands in the conversation. Read its log afterwards rather than asking what happened.
- One short command, such as `! brew install shfmt`, is given as it is.

### Keep verbose output out of the console

- A command whose output may run past a screen, such as a build, a test suite, an install or a data run, writes to a log file under `tmp/logs/` and you read the parts you need with `tail`, `grep` or a line range. Never let thousands of lines into the conversation.
- Never add a verbose or debug flag just to watch. Read the log file.
- When reporting a run, quote the lines that matter and give the log path. Never paste the log.

*Generated from `npomfret/agent-standards`. Edit the standard there, not this copy.*

## State and dependencies

Everything code depends on is created once, at the program's entry point, and handed to whatever needs it, normally as a constructor parameter. Nothing reaches out to a global for it. This rule has no exceptions.

### No static state

- Never hold state at module, class or global level: no exported instance (`export const store = new Store()`), no module-level `let` or `var`, no mutable static field, no singleton accessor (`getInstance()`, `getLogger()`, `getRuntimeSecrets()`), no module-level cache or memo, no shared client created lazily on first use.
- This covers anything with identity or a lifecycle: stores, API and database clients, connections, pools, loggers, caches, config, secrets, feature flags, registries, event buses.
- A true constant is not state: a frozen literal, a regular expression, a lookup table nothing writes to. If anything can write to it, or it holds a resource, it is state.
- Tests follow the same rule. Each test, or its setup, builds what it uses; no instance is shared between tests through a module.

### Pass dependencies in

- A class takes what it uses as constructor parameters. A function takes it as an argument. Neither imports an instance.
- Each program has one composition root: `main`, the server bootstrap, the app's root component, a test's setup. It creates the instances and wires them together. A framework's scoped mechanism, such as a context provider or a DI container, is fine when the root creates it and passes it down.
- Never default a parameter to a global (`constructor(api = apiClient)`). That is the global again.

### Environment variables

- Only the composition root reads the process environment (`process.env`, `os.environ`, `ProcessInfo.processInfo.environment` and the like) and the command-line arguments. It reads them once, validates them into a typed config object, and passes that object, or the values in it, to what needs them.
- No other code reads an environment variable, including through a helper that wraps the read.

### Existing code is not a precedent

- Where a project already has static state or reads the environment deep in its code, do not copy it, extend it or add to it, however much of it there is. New code takes its dependencies as parameters even when the code around it imports globals.
- Removing existing static state is a change of its own. Do it when asked; otherwise name it in one line at the end of the report.
- If a change cannot be made without new static state, for instance because there is no composition root to create the new object in, stop and say so. Never add the global as a stopgap.

*Generated from `npomfret/agent-standards`. Edit the standard there, not this copy.*
