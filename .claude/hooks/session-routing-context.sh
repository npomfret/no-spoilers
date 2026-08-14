#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Routing baseline: prefer .claude/skills, .claude/agents, and .claude/rules over ad-hoc execution. For non-trivial changes, use feature-workflow: audit upstream/downstream/lateral code, identify the approved pattern, refactor for readiness when needed, then implement. Load spoiler-safety rules and use spoiler-safety-reviewer for product data, models, caches, UI copy, fixtures, or screenshots. Use claude-setup-maintenance for Claude control-plane changes and release-and-delivery only for explicit delivery work. Use codebase-explorer for pattern lookup, implement-apple-change for Apple-platform implementation/refactor work, build-verify for compile/build confidence, test-changes for targeted behavior-risk verification, and review-working-tree or pattern-compliance-reviewer for read-only drift checks. Report exact command evidence before claiming completion."}}
EOF
