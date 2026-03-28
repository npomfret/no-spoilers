---
name: pattern-governance-reference
description: Use PROACTIVELY for substantial work, refactors, reviews, or any task where multiple implementations are possible, to enforce approved repo patterns and reject alternate solutions for the same outcome.
user-invocable: false
---

# Pattern Governance Reference

- First identify the nearest established pattern in the touched area before planning edits.
- Treat the established implementation as the approved pattern unless the task explicitly changes the standard.
- Reuse or refactor the approved pattern; do not add a second implementation style for the same concern.
- If no approved pattern fits, stop and propose the new pattern before implementing it.
- Pattern drift, duplicate helpers, and parallel flows are correctness issues and must be called out in implementation and review.
- Parallel work is allowed only when ownership is disjoint by file or domain.
