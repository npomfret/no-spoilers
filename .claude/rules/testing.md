---
description: Verification rules for build, test, and evidence reporting.
---

# Testing Rules

- Use the repo's approved verification commands or scripts. If the project has not standardized them yet, verify the real build and test entry points before running anything.
- Prefer the canonical wrappers in `scripts/` for current Swift and Xcode verification.
- Choose the smallest meaningful build, compile, test, or behavior-risk scope first.
- Distinguish compile or build confidence from changed-behavior confidence. Do not run broader tests when a narrower check answers the question.
- Treat missing verification for a changed behavior or refactor as a correctness gap.
- If a bug is fixed or behavior changes, rerun the relevant verification before handoff.
- Report exact commands and pass or fail outcomes.
- If repeated raw tool invocation would become policy drift, add or propose a shared wrapper instead of normalizing ad-hoc commands.
- Do not claim confidence without executed evidence.
