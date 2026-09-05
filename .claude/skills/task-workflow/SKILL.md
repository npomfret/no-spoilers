---
name: task-workflow
description: Use automatically when planning work, starting a multi-step task, updating implementation progress, recording verification, or closing work. Also use for unplanned work too complex for one commit message. Do not create a task file for a trivial self-contained edit.
user-invocable: true
---

# Task Workflow

Keep exactly one markdown file per piece of work in the nearest owning `tasks/` directory. Use a
short imperative search-term slug. Update an existing owner instead of creating a duplicate.

## Required flow

1. Start with `## The issue`: the bug, feature, refactor, or research question and why it matters.
2. Add a section only when the work has content for it:
   - `## Brainstorming` for candidate and rejected approaches with reasons
   - `## The plan` for working phases with observable success criteria
   - `## Tracking` for current state, decisions, exact verification, blockers, and residual risk
3. Keep the file current by correcting stale claims in place; do not append a chronological diary.
4. Mark work complete only after implementation and verification exist.
5. Update the task file in the same commit as the work it describes.
6. When the last work lands, record final evidence in that commit. Delete the completed task file in
   a separate follow-up commit; first move any durable decision that code cannot express to `docs/`.

Task files are working records, never authorities. Product code and durable documentation must not
depend on them. Move genuinely outstanding work to a new, narrower task before deleting a completed
one.
