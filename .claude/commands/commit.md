---
allowed-tools: Bash, Read, Glob
description: Commit all changes related to current task with proper message format
model: sonnet
---

# Commit Current Task Changes

Commit all staged and unstaged changes with a properly formatted commit message based on the current task.

## Environment Variables

These values come from `.claude/settings.json` → `env`:
- `CLAUDE_CONTEXT_FILE` - path to current ticket file (default: `llm-context/current ticket.md`)
- `CLAUDE_COMMIT_PREFIX` - prefix for commit messages (e.g., "AB#" or empty)

## Workflow

### 1. Read Current Task Information
- Read the context file (`$CLAUDE_CONTEXT_FILE`) to get:
  - Task number (e.g., 72382)
  - Task title/description for commit message context

### 2. Check Git Status
- Run `git status` to see all modified, added, and untracked files
- Identify which files are related to the current task
- Ignore the .md files, .claude folder, llm-context folder

### 3. Stage Changes
- Stage all the files related to the task

### 4. Create Commit
- Format commit message as: `{CLAUDE_COMMIT_PREFIX}<task-number>: <brief description>`
- The description should be:
  - Brief (50-72 characters ideally)
  - Written in imperative mood (e.g., "add", "fix", "update", not "added", "fixed")
  - Describing what the change does, not how

### 5. Execute Commit
- Run `git commit -m "{CLAUDE_COMMIT_PREFIX}<task-number>: <description>"`
- Avoid multi-line commit messages

## Commit Message Examples

- `AB#72382: add exclude from budgets field`
- `AB#71155: add AutomaticStockIntegration field to warehouse entity`
- `#1234: fix login redirect issue`
- `1234: update user validation logic`

## Notes

- Always read the context file first to get the task number
- If the file doesn't exist, ask the user for the task number
- Keep commit messages concise but descriptive
- Multiple small commits are preferred over one large commit
