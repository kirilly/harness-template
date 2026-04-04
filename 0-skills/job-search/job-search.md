# Job Search Skill

Automated daily job search via Claude Code on VPS.

## How it works

1. `job-search-daily.timer` fires once per day
2. Runs `job-search.sh` which invokes `claude -p` with the search prompt
3. Claude searches configured job boards, filters by preferences, formats results
4. Results sent to Telegram via bot API

## Configuration

Edit `job-search-config.json` to set:
- Job title / keywords
- Location preferences
- Salary range
- Job boards to search
- Exclusion filters

## Files

- `job-search.sh` — Runner script (systemd entry point)
- `job-search-config.json` — Search preferences
- `systemd/job-search-daily.service` — Systemd service unit
- `systemd/job-search-daily.timer` — Daily timer (runs at 09:00 local)
