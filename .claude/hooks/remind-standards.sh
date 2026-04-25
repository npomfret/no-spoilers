#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Pattern rule: for non-trivial work, use feature-workflow. Identify the nearest approved implementation before editing, then reuse or refactor the shared boundary instead of adding a variant. Duplicate helpers, alternate architectures, and inconsistent naming are correctness issues, not style issues. For Claude setup changes, use claude-setup-maintenance. For broad or architectural work, use codebase-explorer first and keep pattern-governance-reference active for the rest of the run."}}
EOF
