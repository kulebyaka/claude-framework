---
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
argument-hint: <task-number>
description: Start work on a new task with git branch setup
model: sonnet
---

# Start Task Workflow

Automate the git workflow for starting work on a new task.

## Environment Variables

These values come from `.claude/settings.json` → `env`:
- `CLAUDE_GIT_BASE_BRANCH` - base branch to create feature branches from (e.g., "dev", "main")
- `CLAUDE_GIT_FEATURE_PREFIX` - prefix for feature branches (e.g., "feature/")
- `CLAUDE_COMMIT_PREFIX` - prefix for commit messages (e.g., "AB#")

## Usage

```bash
/git-start 71784
```

## Workflow

### 1. Check Current Git State
- Run `git status` to check for uncommitted changes
- If there only NEW unstaged files, continue without warning
- If uncommitted CHANGES exist, warn the user and ask if they want to:
  - Commit current changes first (recommended)
  - Stash current changes
  - Proceed anyway
- Run `git branch --show-current` to show current branch

### 2. Switch to Base Branch
- Checkout the base branch: `git checkout $CLAUDE_GIT_BASE_BRANCH`
- This ensures the feature branch is created from the latest state

### 3. Pull Latest Changes
- Pull latest changes from remote: `git pull origin $CLAUDE_GIT_BASE_BRANCH`
- This ensures the feature branch starts from the most up-to-date code

### 4. Create Feature Branch
- Create and checkout new feature branch: `git checkout -b {CLAUDE_GIT_FEATURE_PREFIX}$1`
- Branch naming convention: `{CLAUDE_GIT_FEATURE_PREFIX}{task-number}`

### 5. Verify Branch Setup
- Run `git branch --show-current` to confirm you're on the new feature branch
- Run `git status` to verify clean working directory

### 6. Ready to Work
- Confirm the branch is ready for development
- Remind user of commit message convention: `{CLAUDE_COMMIT_PREFIX}$1: {description}`
- Suggest next steps:
  - Use `/ado-task $1` to analyze the task and create implementation plan
  - Use `/ado-context $1` to fetch task context without implementation plan

## Git Workflow Pattern

1. **Start**: `{baseBranch}` → `{featurePrefix}{task-number}` (this command)
2. **Work**: Make commits with `{CLAUDE_COMMIT_PREFIX}{task-number}: {description}` format
3. **Complete**: Feature branch → base branch (checkout back)
4. **Next task**: Repeat from step 1

## Error Handling

- If uncommitted changes exist, STOP and ask user what to do
- If base branch doesn't exist, notify user
- If feature branch already exists, ask user if they want to:
  - Switch to existing branch
  - Cancel operation
- If git operations fail, provide clear error messages

## Integration with Other Commands

This command works well with:
- `/ado-task {task-number}`: Analyze the task after branch creation
- `/ado-context {task-number}`: Fetch task context
- Standard git commands for committing and pushing changes

## Notes

- This command focuses purely on git branch setup
- Does NOT fetch task details (use `/ado-task` or `/ado-context` for that)
- After task completion, remember to checkout back to base branch before starting the next task
