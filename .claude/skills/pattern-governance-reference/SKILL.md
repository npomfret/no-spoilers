---
name: pattern-governance-reference
description: Use automatically as reference context for substantial changes, refactors, architectural reviews, or any task with competing implementations. Establishes one approved local pattern and rejects parallel variants. Do not use for trivial or purely mechanical edits.
user-invocable: false
---

# Pattern Governance Reference

- First identify the nearest established pattern in the touched area before planning edits.
- Treat the established implementation as the approved pattern unless the task explicitly changes the standard.
- Reuse or refactor the approved pattern; do not add a second implementation style for the same concern.
- If no approved pattern fits, stop and propose the new pattern before implementing it.
- Pattern drift, duplicate helpers, and parallel flows are correctness issues and must be called out in implementation and review.
