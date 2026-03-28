#!/usr/bin/env bash
set -euo pipefail

input="$(cat || true)"

extract_command() {
  if command -v python3 >/dev/null 2>&1; then
    INPUT_PAYLOAD="$input" python3 - <<'PY'
import json
import os

payload = os.environ.get("INPUT_PAYLOAD", "")

try:
    data = json.loads(payload or "{}")
except Exception:
    print("", end="")
    raise SystemExit(0)

command = ""
tool_input = data.get("tool_input")
if isinstance(tool_input, dict):
    value = tool_input.get("command")
    if isinstance(value, str):
        command = value

print(command, end="")
PY
    return
  fi

  printf '%s' "$input"
}

command="$(extract_command)"

deny() {
  local reason="$1"
  printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$reason\"}}"
  exit 0
}

if printf '%s' "$command" | grep -Eq '(^|[;&|[:space:]])(rm[[:space:]]+-rf|git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+checkout[[:space:]]+--|git[[:space:]]+clean([[:space:]]|$)|sudo([[:space:]]|$))'; then
  deny "Blocked by project policy: destructive shell command. Ask the user explicitly before running destructive actions."
fi

exit 0
