---
allowed-tools: Bash
argument-hint: [task-number] [--env <environment>] [--update-task]
description: Deploy to environment, optionally update task status
model: haiku
---

# Deploy and Update Task Status

Deploy the application to an environment. Optionally update the Azure DevOps task to "Ready for testing" on success.

## Environment Variables

These values come from `.claude/settings.json` → `env`:
- `CLAUDE_DEFAULT_ENVIRONMENT` - default deployment environment (e.g., "QA02")
- `CLAUDE_GIT_DEPLOY_BRANCH` - branch to deploy from (e.g., "main")
- `CLAUDE_GITHUB_WORKFLOW_FILE` - GitHub workflow file name (e.g., "build.yml")
- `CLAUDE_NTFY_TOPIC` - ntfy.sh topic for notifications (optional)
- `CLAUDE_NOTIFY_IDLE_THRESHOLD` - seconds of idle time before notification (default: 30)
- `CLAUDE_COMMIT_PREFIX` - prefix for task display (e.g., "AB#")

## Arguments

- `$1` - Task number (optional) - e.g., 72191. Only needed if using `--update-task`
- `--env` - Environment (optional) - e.g., QA01, QA02, QA05. Default: from env var
- `--update-task` - Update task to "Ready for testing" on success (optional, off by default)

## Examples

```bash
/deploy                             # Deploy to default env only (no task update)
/deploy --env QA05                  # Deploy to QA05 only
/deploy 72191 --update-task         # Deploy to default env and update task status
/deploy 72191 --env QA05 --update-task  # Deploy to QA05 and update task status
```

## Instructions

1. Parse the arguments:
   - First numeric argument is the task number (optional, only required with --update-task)
   - If `--env` flag is provided, use the next argument as environment
   - If `--update-task` flag is provided, update the task status on success (requires task number)

2. Run the deployment script with PowerShell:

**Without task number (deploy only):**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".claude/scripts/deploy-and-update-task.ps1" -Environment <environment> -SkipTaskUpdate
```

**With task number but no update:**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".claude/scripts/deploy-and-update-task.ps1" -TaskId <task-number> -Environment <environment> -SkipTaskUpdate
```

**With task update (when --update-task is specified):**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".claude/scripts/deploy-and-update-task.ps1" -TaskId <task-number> -Environment <environment>
```

3. The script will:
   - Trigger GitHub workflow deployment to the specified environment
   - Watch the deployment progress in real-time
   - On success with `--update-task`: Update Azure DevOps task to "Ready for testing"
   - Send notification when complete (if user is idle and topic is configured)
