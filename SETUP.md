# Setup Guide

## Prerequisites

Before starting, you need:

1. **Claude Pro subscription** ($20/mo) — sign up at https://claude.ai with your email
2. **SSH key** on your Mac/PC:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_vps -N ""
   cat ~/.ssh/id_vps.pub   # send this to the person setting up your VPS
   ```
3. **Telegram bot** (optional — the admin can create this for you):
   - Open Telegram → search @BotFather → `/newbot`
   - Save the bot token (looks like `123456:ABC-DEF...`)

## What the admin does

The admin (person setting up your VPS) will:

1. Install NixOS on the VPS
2. Add your SSH key so you can log in
3. Deploy the harness, telegram bridge, and job search bot
4. Set up a port-forward so you can authorize Claude in your browser

You'll get a message like: "Open this URL in your browser: http://localhost:8080/..."
— click it, log in with your Claude account, and you're done.

## After setup

### Talk to Claude via Telegram

Send a message to your Telegram bot. Claude responds. That's it.

Useful things to ask:
- "Search for remote software jobs matching my profile"
- "Write a cover letter for this job posting: [paste URL]"
- "Help me prepare for a technical interview at [company]"
- "What's new in my job search today?"

### Configure job search

Edit your preferences:
```bash
ssh -p 2222 dev@<YOUR_VPS_IP>
nano ~/harness/0-skills/job-search/job-search-config.json
```

Fields:
- `keywords` — job title or skills ("QA engineer", "Python developer")
- `location` — "remote", "New York", etc.
- `salary_min` — minimum salary filter (0 = no filter)
- `exclude` — companies or terms to skip

### Learn to use the harness

Your harness has a project structure:
```
1-todo/     — ideas and planned projects
2-current/  — active work
3-done/     — archived projects
```

Each project has three files:
- `spec.md` — what you're building
- `progress.md` — what happened each session
- `validation.md` — did it work (experiments with PASS/FAIL)

Ask Claude to help you create your first project:
> "Create a project in 2-current called learn-claude-code with a spec for passing the Claude certification exam"

### SSH access

```bash
ssh -p 2222 dev@<YOUR_VPS_IP>
```

### Useful commands on VPS

```bash
# Check bot status
systemctl --user status claude-tg

# Restart bot
systemctl --user restart claude-tg

# View job search timer
systemctl --user list-timers

# Check disk/memory
htop
df -h
```

## Claude Certification

Goal: pass the Anthropic certification at https://claude.ai/certification

Practice path:
1. Use Claude daily via Telegram — learn what it can and can't do
2. Try building small projects using the harness (three-file model)
3. Read the Claude docs at https://docs.anthropic.com
4. Take the exam when you feel ready

## Costs

| Item | Cost | Billing |
|------|------|---------|
| VPS | ~$2.50/mo | Paid by admin (annual) |
| Claude Pro | $20/mo | Your credit card |
| Telegram | Free | — |
| Total | ~$22.50/mo | — |
