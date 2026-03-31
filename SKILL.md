---
name: time-machine
description: Backup, restore, and migrate OpenClaw installations. Handles complete state preservation including workspace memories, credentials, skills, and configuration. Use when: (1) Backing up OpenClaw to prevent data loss, (2) Migrating to a new server, (3) Restoring from a backup, (4) User mentions "backup", "migrate", "时光机", or server transfer.
---

# Time Machine - OpenClaw Backup & Migration

Complete backup and restore solution for OpenClaw state.

## What Gets Backed Up (The "Soul")

| Path | Contents |
|------|----------|
| `workspace/` | Memories, SOUL.md, USER.md, daily logs |
| `credentials/` | API keys, tokens |
| `telegram/` | Telegram channel configuration |
| `skills/` | Custom skills |
| `cron/` | Scheduled tasks |
| `openclaw.json` | Main configuration |
| `identity/` | Identity files |

**Excluded**: OpenClaw binaries (~1.4GB), can be reinstalled.

## Quick Start

```bash
# Create backup
./scripts/time-machine backup

# List backups (shows index numbers)
./scripts/time-machine list

# Restore by index number
./scripts/time-machine restore 1

# Restore by filename
./scripts/time-machine restore openclaw-soul-20260331-004110.tar.gz

# One-click migrate to new server
./scripts/time-machine migrate user@new-server.com
```

## Manual Migration Workflow

Source server:
```bash
openclaw gateway stop
./scripts/time-machine backup
scp ~/.time_machine/openclaw-soul-*.tar.gz new-server:~/
```

Target server:
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
./scripts/time-machine restore openclaw-soul-*.tar.gz
openclaw gateway start
```

## Important Notes

1. **Stop service before backup** — Prevents data inconsistency
2. **Auto-backup on restore** — Script backs up current config before overwriting
3. **Telegram Bot** — May need new token from @BotFather after IP change
4. **Node pairing** — Mobile app needs re-pairing with new server

## File Locations

- Backups: `~/.time_machine/`
- Safety backups: `~/.openclaw.bak.<timestamp>/`
