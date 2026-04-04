# Admin Provisioning Checklist

Run through this when setting up a new VPS for someone.

## Inputs needed

Collect from the person before starting:

- [ ] Their SSH public key (`ssh-ed25519 AAAA...`)
- [ ] Their Claude account email (they need Pro subscription active)
- [ ] TG bot token (either they create via BotFather or you do it)
- [ ] TG chat ID (get after first message to the bot)
- [ ] Job search preferences (keywords, location, salary)

## VPS info

Fill in after purchasing:

```bash
VPS_IP=
VPS_HOSTNAME=
USERNAME=dev
SSH_PORT=2222
```

## Step 1: Initial access

```bash
ssh-copy-id root@$VPS_IP
ssh root@$VPS_IP
```

## Step 2: Install NixOS

```bash
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
  NIX_CHANNEL=nixos-24.11 bash -x
# Wait ~5min for reboot, then reconnect on port 22
```

## Step 3: Deploy nix-vps config

```bash
ssh root@$VPS_IP
cd /etc/nixos
git clone https://github.com/kirilly/nix-vps.git setup
cd setup
cp config.env.example config.env
# Edit config.env with the person's values:
#   VPS_HOSTNAME, SSH_PUBKEY, USERNAME, SSH_PORT, SERVICES, SECRETS
bash setup.sh
cp generated/* /etc/nixos/
```

## Step 4: Age key + secrets

```bash
# Generate age key for this VPS
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_age_key -N ""

# Get the age public key
cat /etc/ssh/ssh_host_age_key.pub

# On your Mac — encrypt each secret:
echo "BOT_TOKEN_HERE" | age -r "age1..." -o telegram-token.age
echo "GOCRYPTFS_PASSWORD" | age -r "age1..." -o gocryptfs-pass.age
echo "GITHUB_PAT_HERE" | age -r "age1..." -o github-pat.age

# Copy to VPS
scp -P $SSH_PORT telegram-token.age gocryptfs-pass.age github-pat.age \
  root@$VPS_IP:/etc/nixos/secrets/

# Update secrets.nix with the age public key, then rebuild
ssh root@$VPS_IP 'nixos-rebuild switch'
```

## Step 5: Clone repos as dev user

```bash
ssh -p $SSH_PORT $USERNAME@$VPS_IP

git clone https://github.com/kirilly/harness-template.git ~/harness
git clone https://github.com/kirilly/telegram-bridge.git ~/telegram
cd ~/telegram && bun install

# Create TG .env
cat > ~/telegram/.env << 'EOF'
TELEGRAM_BOT_TOKEN=<from agenix or paste>
EOF
```

## Step 6: Auth Claude (with the person)

```bash
# On YOUR Mac — port forward:
ssh -L 8080:localhost:8080 -p $SSH_PORT $USERNAME@$VPS_IP

# On the VPS:
claude login
# Copy the localhost URL → send to the person → they open in browser → authorize
```

## Step 7: Start services

```bash
ssh -p $SSH_PORT $USERNAME@$VPS_IP

# Start Claude TG bot
systemctl --user enable --now claude-tg.service

# Test: send a message to the TG bot, verify response

# Configure and start job search
nano ~/harness/0-skills/job-search/job-search-config.json
systemctl --user enable --now job-search-daily.timer

# Verify
systemctl --user list-timers
```

## Step 8: Verify everything

- [ ] SSH works with their key: `ssh -p 2222 dev@$VPS_IP`
- [ ] Claude TG bot responds to messages
- [ ] Job search timer is active
- [ ] `claude login` persists after service restart
- [ ] Git push/pull works from VPS

## Post-setup

- Send them the SETUP.md link
- Walk them through sending first TG message
- Show them how to SSH in
- Explain the harness structure (1-todo, 2-current, 3-done)
