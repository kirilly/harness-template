#!/usr/bin/env bash
# Stop hook: append lightweight session summary to progress.md
set -euo pipefail

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Find progress.md in CWD or parents
progress_file=""
dir="${CWD:-$(pwd)}"
for _ in 1 2 3; do
  if [[ -f "$dir/progress.md" ]]; then
    progress_file="$dir/progress.md"
    break
  fi
  dir="$(dirname "$dir")"
done
[[ -z "$progress_file" ]] && exit 0

# Extract files touched from transcript
files_touched=""
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  files_touched=$(jq -r '
    [.[] | select(.type == "tool_use") |
     .tool_input.file_path // empty |
     select(. != "")] | unique | .[]' "$TRANSCRIPT_PATH" 2>/dev/null | head -20 || true)
fi

# Append summary
timestamp=$(date "+%Y-%m-%d %H:%M")
short_id="${SESSION_ID:0:8}"

{
  echo ""
  echo "### Auto-summary — $timestamp (session $short_id)"
  if [[ -n "$files_touched" ]]; then
    echo "- **Files touched:**"
    echo "$files_touched" | while read -r f; do echo "  - $f"; done
  fi
} >> "$progress_file"
