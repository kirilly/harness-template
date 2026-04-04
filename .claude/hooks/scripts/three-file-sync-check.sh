#!/usr/bin/env bash
# PostToolUse hook: when any of the three files changes, remind to sync the others.
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE_PATH" ]] && exit 0

BASENAME=$(basename "$FILE_PATH")
DIR=$(dirname "$FILE_PATH")

case "$BASENAME" in
  spec.md|progress.md|validation.md) ;;
  *) exit 0 ;;
esac

has_spec=false; has_progress=false; has_validation=false
[[ -f "$DIR/spec.md" ]] && has_spec=true
[[ -f "$DIR/progress.md" ]] && has_progress=true
[[ -f "$DIR/validation.md" ]] && has_validation=true

warnings=""

case "$BASENAME" in
  spec.md)
    if $has_validation; then
      spec_criteria=$(grep -cE '### SC[0-9]' "$DIR/spec.md" 2>/dev/null || echo 0)
      val_experiments=$(grep -cE '^### E[0-9]' "$DIR/validation.md" 2>/dev/null || echo 0)
      if [[ "$spec_criteria" -gt "$val_experiments" ]]; then
        warnings="spec.md has $spec_criteria criteria but validation.md has only $val_experiments experiments."
      fi
    fi
    ;;
  progress.md)
    if ! $has_validation; then
      warnings="progress.md updated but no validation.md found. Create one to track experiments."
    fi
    ;;
  validation.md)
    if $has_progress; then
      pass_count=$(grep -cE '\*\*Status:\*\*.*PASS' "$DIR/validation.md" 2>/dev/null || echo 0)
      total=$(grep -cE '^### E[0-9]' "$DIR/validation.md" 2>/dev/null || echo 0)
      if [[ "$pass_count" -eq "$total" && "$total" -gt 0 ]]; then
        warnings="All $total experiments PASS. Update progress.md to reflect completion."
      fi
    fi
    ;;
esac

if [[ -n "$warnings" ]]; then
  echo "$warnings" >&2
fi
exit 0
