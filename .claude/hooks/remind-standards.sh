#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Pattern rule: identify the nearest approved implementation before editing. Reuse or refactor the shared boundary instead of adding a variant. Duplicate helpers, alternate architectures, and inconsistent naming are correctness issues, not style issues. For broad or architectural work, use codebase-explorer first and keep pattern-governance-reference active for the rest of the run."}}
EOF
