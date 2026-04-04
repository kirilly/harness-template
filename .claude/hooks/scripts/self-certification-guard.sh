#!/usr/bin/env bash
# PreToolUse hook (Write|Edit): BLOCK marking experiments PASS without evidence.
set -euo pipefail

INPUT=$(timeout 1 cat 2>/dev/null || true)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

BASENAME=$(basename "$FILE_PATH")
[[ "$BASENAME" != "validation.md" ]] && exit 0

CONTENT=""
if [[ "$TOOL" == "Write" ]]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
elif [[ "$TOOL" == "Edit" ]]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
fi
[[ -z "$CONTENT" ]] && exit 0

if ! echo "$CONTENT" | grep -qiE '\*\*Status:\*\*.*PASS'; then
  exit 0
fi

if echo "$CONTENT" | grep -qiE '\*\*Evidence:\*\*\s*TBD'; then
  cat >&2 <<GATE
{"decision":"block","reason":"Cannot mark experiment PASS with TBD evidence. Add concrete evidence first."}
GATE
  exit 2
fi

exit 0
