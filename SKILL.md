---
name: claw-time-machine
description: Backup, restore, and migrate OpenClaw installations. Handles complete state preservation including workspace memories, credentials, skills, and configuration. Use when: (1) Backing up OpenClaw to prevent data loss, (2) Migrating to a new server, (3) Restoring from a backup, (4) User mentions "backup", "migrate", "时光机", or server transfer.
version: 1.0.3
---

# Claw Time Machine - OpenClaw Backup & Migration

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
./scripts/ctm.sh backup

# List backups (shows index numbers)
./scripts/ctm.sh list

# Restore by index number
./scripts/ctm.sh restore 1

# Restore by filename
./scripts/ctm.sh restore openclaw-soul-20260331-004110.tar.gz

# One-click migrate to new server
./scripts/ctm.sh migrate user@new-server.com
```

## Handling Backup Count Queries

When user asks "有几个备份", "how many backups", "backup count", or similar:

1. Check the backup directory:
   ```bash
   ls -la ~/.ctm/openclaw-soul-*.tar.gz 2>/dev/null
   ```

2. Report findings:
   - **If directory empty/missing**: "还没有备份"
   - **If backups exist**: "找到 N 个备份：" + 列出文件名、大小、创建时间
   - **Show latest**: 特别指出最新的备份

### Example Responses

- "找到 3 个备份：
  - openclaw-soul-20260331-004110.tar.gz (256KB, 3月31日)
  - openclaw-soul-20260330-120000.tar.gz (251KB, 3月30日)
  - openclaw-soul-20260328-080000.tar.gz (248KB, 3月28日)
  最新的是 3月31日 的备份"

## Manual Migration Workflow

Source server:
```bash
openclaw gateway stop
./scripts/ctm.sh backup
scp ~/.ctm/openclaw-soul-*.tar.gz new-server:~/
```

Target server:
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
./scripts/ctm.sh restore openclaw-soul-*.tar.gz
openclaw gateway start
```

## Important Notes

1. **Stop service before backup** — Prevents data inconsistency during active writes
2. **Auto-backup on restore** — Script backs up current config before overwriting (safety net)

## File Locations

- Backups: `~/.ctm/`
- Safety backups: `~/.openclaw.bak.<timestamp>/`
