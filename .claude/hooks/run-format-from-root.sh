#!/usr/bin/env bash
set -euo pipefail

hook_payload="$(cat || true)"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

declare -a target_files
declare -a swift_files
target_count=0
swift_count=0

add_target_file() {
  local candidate="$1"

  [[ -z "$candidate" ]] && return 0

  if [[ "$candidate" == "$repo_root/"* ]]; then
    candidate="${candidate#"$repo_root"/}"
  fi

  [[ -f "$candidate" ]] || return 0

  local existing
  for existing in "${target_files[@]-}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done

  target_files+=("$candidate")
  ((target_count += 1))

  if [[ "$candidate" == *.swift ]]; then
    swift_files+=("$candidate")
    ((swift_count += 1))
  fi
}

if [[ -n "${CLAUDE_FILE_PATHS:-}" ]]; then
  while IFS= read -r file_path; do
    add_target_file "$file_path"
  done < <(printf '%s\n' "$CLAUDE_FILE_PATHS")
fi

if [[ $target_count -eq 0 ]] && [[ -n "$hook_payload" ]] && command -v python3 >/dev/null 2>&1; then
  while IFS= read -r file_path; do
    add_target_file "$file_path"
  done < <(
    HOOK_PAYLOAD="$hook_payload" python3 - <<'PY'
import json
import os

payload = os.environ.get("HOOK_PAYLOAD", "")

try:
    data = json.loads(payload or "{}")
except Exception:
    raise SystemExit(0)

values = []

def add(value):
    if isinstance(value, str):
        values.append(value)

tool_input = data.get("tool_input")
if isinstance(tool_input, dict):
    add(tool_input.get("file_path"))
    add(tool_input.get("path"))
    for key in ("file_paths", "paths"):
        items = tool_input.get(key)
        if isinstance(items, list):
            for item in items:
                add(item)
    edits = tool_input.get("edits")
    if isinstance(edits, list):
        for edit in edits:
            if isinstance(edit, dict):
                add(edit.get("file_path"))
    files = tool_input.get("files")
    if isinstance(files, list):
        for item in files:
            if isinstance(item, dict):
                add(item.get("file_path"))

add(data.get("file_path"))

for value in values:
    print(value)
PY
  )
fi

if [[ $target_count -eq 0 ]]; then
  echo "Skipping auto-format: no touched files found" >&2
  exit 0
fi

ran_formatter=0

if [[ -f package.json ]] && command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY'
import json

try:
    with open("package.json", "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    raise SystemExit(1)

scripts = data.get("scripts")
raise SystemExit(0 if isinstance(scripts, dict) and isinstance(scripts.get("format"), str) else 1)
PY
  then
    npm run format -- "${target_files[@]}"
    ran_formatter=1
  fi
fi

if [[ $swift_count -gt 0 ]] && command -v swiftformat >/dev/null 2>&1; then
  swiftformat "${swift_files[@]}"
  ran_formatter=1
fi

if [[ $ran_formatter -eq 0 ]]; then
  echo "Skipping auto-format: no supported formatter found" >&2
fi

exit 0
