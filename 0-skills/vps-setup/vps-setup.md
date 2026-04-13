---
tags:
  - type/skill
  - domain/infrastructure
  - status/active
---
# VPS Setup — Agent Provisioning Skill

Reference/template skill only.

Preferred product path:
- start from `job-search`
- optionally add `tg-bridge`
- then use `job-search-tg-bridge`
- only later use `nix-vps`

Use this skill only when the person has already decided they want the harness template plus VPS deployment path.

You are setting up a VPS for the user. Follow these phases in order. Collect required information from the user before each phase. Every step has a VERIFY command — run it and confirm before proceeding.

## Before You Start

Collect from the user:
- VPS IP address and root password
- SSH public key (or generate one: `ssh-keygen -t ed25519 -f ~/.ssh/id_vps -N ""`)
- Telegram bot token (from @BotFather)
- Telegram chat ID and user ID (from @userinfobot + bot API getUpdates)

Store these as shell variables for the session:
```bash
VPS_IP="..."
SSH_PUBKEY="..."
TG_BOT_TOKEN="..."
TG_CHAT_ID="..."
TG_USER_ID="..."
```

## Phase A: NixOS Install (~10 min)

### A1. Copy SSH key to VPS
```bash
ssh-copy-id root@$VPS_IP
```
VERIFY: `ssh root@$VPS_IP 'echo ok'`

### A2. Install NixOS via nixos-infect
```bash
ssh root@$VPS_IP 'curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-24.11 bash -x'
```
Wait ~5 minutes for VPS to reboot. Then:
```bash
ssh-keygen -R $VPS_IP
```
VERIFY: `ssh root@$VPS_IP 'nixos-version'` (type "yes" for new fingerprint)

## Phase B: Config Deploy (~5 min)

### B1. Clone and configure
```bash
ssh root@$VPS_IP 'cd /etc/nixos && git clone https://github.com/kirilly/nix-vps-template.git setup && cd setup && cp config.env.example config.env'
```

### B2. Write config.env
Write config.env on the VPS with the user's values:
```bash
ssh root@$VPS_IP "cat > /etc/nixos/setup/config.env << 'EOF'
VPS_HOSTNAME=my-bot
SSH_PUBKEY=$SSH_PUBKEY
USERNAME=dev
SSH_PORT=2222
SERVICES=claude-tg,harness-pull,healthcheck,job-search-daily
CLAUDE_AUTH=subscription
SECRETS=telegram-token
SYNCTHING_ENABLED=false
GOCRYPTFS_VOLUMES=
EOF"
```

### B3. Generate and apply NixOS config
```bash
ssh root@$VPS_IP 'cd /etc/nixos/setup && bash setup.sh && cp generated/* /etc/nixos/ && cp -r generated/secrets/ /etc/nixos/secrets/'
```
VERIFY: `ssh root@$VPS_IP 'nix-instantiate --parse /etc/nixos/configuration.nix'`

### B4. Set up age encryption for secrets
```bash
ssh root@$VPS_IP 'ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_age_key -N ""'
ssh root@$VPS_IP 'nix-env -iA nixos.age'
```

Get the age public key:
```bash
AGE_KEY=$(ssh root@$VPS_IP 'nix-shell -p ssh-to-age --run "ssh-to-age < /etc/ssh/ssh_host_age_key.pub"')
echo "Age key: $AGE_KEY"
```

Encrypt TG token and update secrets:
```bash
ssh root@$VPS_IP "echo '$TG_BOT_TOKEN' | age -r '$AGE_KEY' -o /etc/nixos/secrets/telegram-token.age"
ssh root@$VPS_IP "sed -i 's|age1.*replace.*|$AGE_KEY\";|' /etc/nixos/secrets/secrets.nix"
```

### B5. Apply NixOS config
```bash
ssh root@$VPS_IP 'nixos-rebuild switch'
```
**WARNING:** SSH port changes to 2222 and password auth is disabled after this.
VERIFY: `ssh -p 2222 dev@$VPS_IP 'echo ok'`

## Phase C: Software Deploy (~10 min)

### C1. Install Claude Code
```bash
ssh -p 2222 dev@$VPS_IP 'npm install -g @anthropic-ai/claude-code'
```
VERIFY: `ssh -p 2222 dev@$VPS_IP 'claude --version'`

### C2. Clone repos
```bash
ssh -p 2222 dev@$VPS_IP 'git clone https://github.com/kirilly/harness-template.git ~/harness && git clone https://github.com/kirilly/telegram-bridge.git ~/telegram && git clone https://github.com/kirilly/nix-vps-template.git ~/nix-vps'
```

### C3. Install telegram-bridge
```bash
ssh -p 2222 dev@$VPS_IP 'cd ~/telegram && bun install'
```

### C4. Create telegram .env
```bash
ssh -p 2222 dev@$VPS_IP "cat > ~/telegram/.env << EOF
TELEGRAM_BOT_TOKEN=$TG_BOT_TOKEN
TELEGRAM_CHAT_ID=$TG_CHAT_ID
TG_ALLOWED_USERS=$TG_USER_ID
EOF"
```

### C5. Create Claude MCP config

`channel-server.ts` requires both `TELEGRAM_BOT_TOKEN` and `TG_ALLOWED_USERS`
— both live in `~/telegram/.env` (written in C4). The `set -a; source ...; set +a`
pattern exports them for the child. The stderr redirect prevents bun's
stderr writes from blocking on Claude's MCP stdio pipe.

```bash
ssh -p 2222 dev@$VPS_IP 'mkdir -p ~/.claude && cat > ~/.claude.json << '"'"'EOF'"'"'
{
  "hasCompletedOnboarding": true,
  "mcpServers": {
    "tg": {
      "command": "bash",
      "args": ["-c", "set -a; . ~/telegram/.env; set +a; exec bun ~/telegram/channel-server.ts 2>>/tmp/tg-bun-stderr.log"]
    }
  }
}
EOF'
```
VERIFY: `ssh -p 2222 dev@$VPS_IP 'cat ~/.claude.json | jq .mcpServers.tg'`

## Phase D: Auth + Start (~5 min)

### D1. Claude login
Tell the user: "Open a NEW terminal on your PC and run this SSH tunnel:"
```bash
ssh -L 8080:localhost:8080 -p 2222 dev@$VPS_IP
```

Then on the VPS:
```bash
ssh -p 2222 dev@$VPS_IP 'claude login'
```
Claude prints a URL. User opens it in their browser, logs in with their Claude account, authorizes.
If the URL uses a different port (e.g. 3000), tell user to reconnect tunnel with that port.

VERIFY: `ssh -p 2222 dev@$VPS_IP 'claude --version'`

### D2. Start services
```bash
ssh -p 2222 dev@$VPS_IP 'systemctl --user daemon-reload && systemctl --user enable --now claude-tg'
```
VERIFY: `ssh -p 2222 dev@$VPS_IP 'systemctl --user is-active claude-tg'`

### D3. Test
Ask the user to send a message to their TG bot. Bot should reply within 30 seconds.

## Phase E: Job Search Setup

### E1. Configure job search
Ask the user for their job search preferences:
- Keywords (e.g. "QA engineer", "Python developer")
- Location (e.g. "remote", "New York")
- Minimum salary (0 = no filter)
- Exclusions (companies/terms to skip)

Write the config:
```bash
ssh -p 2222 dev@$VPS_IP "cat > ~/harness/0-skills/job-search/job-search-config.json << EOF
{
  \"keywords\": [\"...\"],
  \"location\": \"remote\",
  \"salary_min\": 0,
  \"exclude\": []
}
EOF"
```

### E2. Verify job search timer
The timer is already configured in NixOS config (via setup.sh with SERVICES=...job-search-daily).
VERIFY: `ssh -p 2222 dev@$VPS_IP 'systemctl --user list-timers | grep job-search'`

## Rollback

If something goes wrong:
- **Config issue:** `ssh root@$VPS_IP 'nixos-rebuild switch --rollback'`
- **Full reset:** Reinstall Ubuntu 24.04 via VPS provider panel, start from Phase A
- **Claude auth:** `ssh -p 2222 dev@$VPS_IP 'rm -rf ~/.claude.json ~/.claude/'` then re-run Phase D

## Done

All services running:
- claude-tg.service — Telegram bot (always-on)
- job-search-daily.timer — daily at 09:00
- harness-pull.timer — git pull every 15 min
- healthcheck.timer — every 10 min (silent when healthy)
