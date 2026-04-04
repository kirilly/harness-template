# Setup Guide — Self-Service VPS

Set up your own AI-powered job search bot on a VPS. All steps are yours to run.

## Step 1: Prerequisites (your Windows PC)

Open WSL terminal (Ubuntu) for all commands below.

### 1a. Generate SSH key
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_vps -N ""
```

### 1b. Buy Claude Pro subscription
- Go to https://claude.ai → sign up with your email
- Subscribe to Pro ($20/mo) — this powers your bot + gives you web access

### 1c. Create Telegram bot
- Open Telegram → search `@BotFather` → send `/newbot`
- Follow prompts → save the bot token (looks like `123456:ABC-DEF...`)
- Send any message to your new bot so it creates a chat
- Get your chat ID: open `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates` in browser → find `"chat":{"id":123456}`

## Step 2: VPS initial setup

You should have received VPS credentials (IP, root password) from your hosting provider.

### 2a. Copy your SSH key to the VPS
```bash
ssh-copy-id -i ~/.ssh/id_vps root@<VPS_IP>
ssh -i ~/.ssh/id_vps root@<VPS_IP>   # verify it works
```

### 2b. Install NixOS
```bash
ssh -i ~/.ssh/id_vps root@<VPS_IP>

# This replaces Ubuntu with NixOS (~5 min, VPS will reboot)
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
  NIX_CHANNEL=nixos-24.11 bash -x
```

Wait ~5 minutes for reboot, then reconnect:
```bash
ssh -i ~/.ssh/id_vps root@<VPS_IP>
```

### 2c. Deploy NixOS config
```bash
# On the VPS as root:
cd /etc/nixos
git clone https://github.com/kirilly/nix-vps.git setup
cd setup
cp config.env.example config.env
```

Edit `config.env` with your values:
```bash
nano config.env
```
Fill in:
- `VPS_HOSTNAME` — any name you want (e.g. `my-bot`)
- `SSH_PUBKEY` — paste your public key from `cat ~/.ssh/id_vps.pub` (run this in WSL on your PC)
- `USERNAME` — keep `dev` or change it
- `SSH_PORT` — keep `2222` or change it
- `SERVICES` — keep `claude-tg,harness-pull,healthcheck`
- `CLAUDE_AUTH` — keep `subscription`

Then generate and apply config:
```bash
bash setup.sh
cp generated/* /etc/nixos/
```

### 2d. Set up secrets (agenix encryption)
```bash
# Still on VPS as root:

# Generate encryption key
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_age_key -N ""

# Install age tool
nix-env -iA nixos.age

# Get your age public key
AGE_KEY=$(nix-shell -p ssh-to-age --run "ssh-to-age < /etc/ssh/ssh_host_age_key.pub")
echo "Your age key: $AGE_KEY"

# Encrypt your Telegram bot token
echo "YOUR_BOT_TOKEN_HERE" | age -r "$AGE_KEY" -o /etc/nixos/secrets/telegram-token.age

# Create a gocryptfs password (random)
openssl rand -base64 32 | age -r "$AGE_KEY" -o /etc/nixos/secrets/gocryptfs-pass.age

# Update secrets.nix with your age key
sed -i "s|age1.*replace.*|$AGE_KEY\";|" /etc/nixos/generated/secrets/secrets.nix
cp /etc/nixos/generated/secrets/secrets.nix /etc/nixos/secrets/secrets.nix

# Apply everything
nixos-rebuild switch
```

## Step 3: Deploy the bot

```bash
# Switch to your user
su - dev

# Clone repos
git clone https://github.com/kirilly/harness-template.git ~/harness
git clone https://github.com/kirilly/telegram-bridge.git ~/telegram

# Install telegram bridge dependencies
cd ~/telegram
bun install

# Create telegram .env
cat > ~/telegram/.env << EOF
TELEGRAM_BOT_TOKEN=$(sudo cat /run/agenix/telegram-token)
TELEGRAM_CHAT_ID=YOUR_CHAT_ID_HERE
EOF
```

## Step 4: Authenticate Claude

This requires a browser on your Windows PC.

```bash
# On your PC (WSL), open an SSH tunnel:
ssh -L 8080:localhost:8080 -p 2222 -i ~/.ssh/id_vps dev@<VPS_IP>

# On the VPS (in that same SSH session):
claude login
```

Claude will show a URL like `http://localhost:8080/...` — open it in your Windows browser, log in with your Claude account, and authorize.

## Step 5: Start everything

```bash
# On VPS as dev user:

# Start the Claude Telegram bot
systemctl --user enable --now claude-tg.service

# Test: send a message to your Telegram bot — it should reply!

# Configure job search
nano ~/harness/0-skills/job-search/job-search-config.json

# Start daily job search timer
systemctl --user enable --now job-search-daily.timer

# Verify timers are running
systemctl --user list-timers
```

## Step 6: Verify

- [ ] Send a message to your TG bot → Claude responds
- [ ] `systemctl --user list-timers` shows job-search-daily.timer active
- [ ] Restart the bot: `systemctl --user restart claude-tg` → still works
- [ ] SSH from your PC: `ssh -p 2222 -i ~/.ssh/id_vps dev@<VPS_IP>`

## After setup

### Talk to Claude via Telegram

Send a message to your bot. Claude responds. That's it.

Useful things to ask:
- "Search for remote software jobs matching my profile"
- "Write a cover letter for this job posting: [paste URL]"
- "Help me prepare for a technical interview at [company]"
- "What's new in my job search today?"

### Configure job search

From WSL:
```bash
ssh -p 2222 -i ~/.ssh/id_vps dev@<VPS_IP>
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

### Useful VPS commands

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
| VPS | ~$2.50/mo | Annual prepay |
| Claude Pro | $20/mo | Your credit card |
| Telegram | Free | — |
| **Total** | **~$22.50/mo** | — |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Bot doesn't respond | `systemctl --user restart claude-tg` |
| "Claude login expired" | Re-run Step 4 (SSH tunnel + `claude login`) |
| Can't SSH in | Check VPS IP and port: `ssh -p 2222 -i ~/.ssh/id_vps dev@<IP>` |
| Job search not running | `systemctl --user status job-search-daily.timer` |
