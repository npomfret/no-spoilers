---
name: bug-investigation
description: Use automatically when reproducing, diagnosing, or fixing a bug, flaky test, unexplained runtime behavior, or failed build. Enforces one reversible hypothesis at a time and a clean evidence baseline. Do not use for feature work without an observed failure.
user-invocable: true
---

# Bug Investigation

1. Load the applicable subsystem rules and `test-changes`; inspect relevant code, tests, logs, and
   recent changes.
2. Define the observed failure and the smallest reliable reproducer. Add the smallest practical
   failing test first when the behavior is testable.
3. Record the working-tree baseline and preserve every pre-existing change.
4. For each hypothesis, state the predicted observation and make one minimal reversible experiment.
5. Run the reproducer. Retain only changes that produced predicted or clearly useful evidence;
   otherwise reverse that experiment completely before trying another. Never stack unsupported
   conjectures.
6. Implement the evidence-supported fix, verify the original failure and nearby behavior, then run
   the relevant broader check.
7. Review the final diff and remove temporary logs, probes, flags, timing changes, speculative fixes,
   and scaffolding without a deliberate permanent role.
8. Decide separately whether the reproducer should remain, be rewritten or consolidated, or be
   removed based on enduring contract value, regression risk, stability, and maintenance cost.
9. Report the diagnosis evidence, exact verification, permanent-test decision, and residual
   uncertainty.
