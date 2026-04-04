#!/usr/bin/env bash
# Daily job search runner — invoked by systemd timer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/job-search-config.json"
HARNESS_ROOT="${HARNESS_ROOT:-$HOME/harness}"
SENT_LOG="$HARNESS_ROOT/.job-search-sent.json"

# Load config
if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

KEYWORDS=$(jq -r '.keywords // "software engineer"' "$CONFIG")
LOCATION=$(jq -r '.location // "remote"' "$CONFIG")
SALARY_MIN=$(jq -r '.salary_min // 0' "$CONFIG")
EXCLUDE=$(jq -r '.exclude | join(", ")' "$CONFIG" 2>/dev/null || echo "")

# Build search prompt
PROMPT="Search for job listings matching these criteria:
- Keywords: $KEYWORDS
- Location: $LOCATION
- Minimum salary: \$$SALARY_MIN
- Exclude: $EXCLUDE

Search LinkedIn, Indeed, and any other major job boards you can access.
Format each result as:
- **Title** at **Company** — Location — Salary range
  Link: [URL]
  Posted: [date]

Only include jobs posted in the last 7 days. Skip jobs already in the sent log.
After listing results, output a JSON array of job IDs/URLs for tracking."

# Run Claude
RESULT=$(claude -p "$PROMPT" 2>/dev/null || echo "ERROR: Claude failed")

# Send to Telegram if configured
TG_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TG_CHAT="${TELEGRAM_CHAT_ID:-}"

if [[ -n "$TG_TOKEN" && -n "$TG_CHAT" ]]; then
  # Truncate to TG message limit (4096 chars)
  MSG=$(echo "$RESULT" | head -c 4000)
  curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    -d chat_id="$TG_CHAT" \
    -d parse_mode="Markdown" \
    --data-urlencode "text=$MSG" > /dev/null
fi

echo "$RESULT"
