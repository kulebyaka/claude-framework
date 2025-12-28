---
allowed-tools: Bash, Read, Glob
description: Create a Pull Request with proper naming convention
model: sonnet
---

# Create Pull Request

Create a Pull Request with proper naming convention based on the current task.

## Environment Variables

These values come from `.claude/settings.json` → `env`:
- `CLAUDE_CONTEXT_FILE` - path to current ticket file (default: `llm-context/current ticket.md`)
- `CLAUDE_GIT_DEPLOY_BRANCH` - base branch for PR (e.g., "main", "develop")
- `CLAUDE_GITHUB_REVIEWERS` - comma-separated list of reviewers (e.g., "org/team-name,@me/copilot")
- `CLAUDE_COMMIT_PREFIX` - prefix for PR title (e.g., "AB#")

## Workflow

### 1. Read Current Task Information
- Read the context file (`$CLAUDE_CONTEXT_FILE`) to get:
  - Task number (e.g., 72450)
  - Task title from the heading (e.g., "Bulk Import Distributor PnP Groups")

### 2. Validate Current Branch
- Run `git branch --show-current` to get the current branch name
- Verify the branch name ends with the ticket number from the current task
- If it doesn't match, warn the user and stop

### 3. Push Branch to Remote
- Ensure branch is pushed: `git push -u origin <current-branch>`

### 4. Create Pull Request with Reviewers
- Use GitHub CLI to create PR:
```bash
gh pr create --base $CLAUDE_GIT_DEPLOY_BRANCH --head <current-branch> --title "{CLAUDE_COMMIT_PREFIX}<ticket-number> <ticket-title>" --body "" --reviewer <reviewers>
```
- Add reviewers from `$CLAUDE_GITHUB_REVIEWERS` (if configured)

### 5. Update Azure DevOps Ticket Status
- Use Azure CLI to update ticket status:
```bash
az boards work-item update --id <ticket-number> --state "In Code Review"
```

## Naming Convention

- **Base branch:** from `$CLAUDE_GIT_DEPLOY_BRANCH`
- **Head branch:** Current feature branch (e.g., `feature/72450`)
- **Title format:** `{CLAUDE_COMMIT_PREFIX}<ticket-number> <ticket-title>`
- **Body:** Empty string (can be filled in GitHub UI later)

## Notes

- Always read the context file first to get the task number and title
- If the file doesn't exist, ask the user for the task number and title
- The branch name must end with the ticket number for validation
- Remove any prefix like "J: " from the title (just use the descriptive part)

## Related Skills

- `.claude/skills/github-cli/SKILL.md` - GitHub CLI operations
- `.claude/skills/azure-devops/SKILL.md` - Azure DevOps operations
