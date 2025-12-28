# GitHub CLI Skill

Comprehensive guide for using GitHub CLI (`gh`) commands effectively in Claude Code.

## Environment Variables

These values come from `.claude/settings.json` → `env`:
- `CLAUDE_GIT_DEPLOY_BRANCH` - base branch for PRs (e.g., "main", "develop")
- `CLAUDE_GITHUB_WORKFLOW_FILE` - workflow file name (e.g., "build.yml")
- `CLAUDE_GITHUB_REVIEWERS` - comma-separated reviewers (e.g., "org/team,@me/copilot")
- `CLAUDE_DEFAULT_ENVIRONMENT` - default deployment environment
- `CLAUDE_ENVIRONMENTS` - comma-separated list of available environments

## Overview

This skill covers all common GitHub CLI operations:
- Pull Request management
- Workflow execution and monitoring
- Repository operations
- PR comment handling
- API interactions

## Pull Request Operations

### Create Pull Request

```bash
gh pr create --base $CLAUDE_GIT_DEPLOY_BRANCH --head <HEAD_BRANCH> --title "<TITLE>" --body "<BODY>" --reviewer <REVIEWER>
```

**Usage:**
- Use `--base` for target branch, `--head` for source branch
- Use `--body ""` for empty body (can be filled in GitHub UI later)
- Use `--reviewer` (or `-r`) to add reviewers directly (can be repeated for multiple reviewers)
- Reviewer format: `username`, `org/team-name`, or `@me/copilot`
- See `/pr` slash command for project-specific naming conventions

### View Pull Request

```bash
# View PR details
gh pr view <PR_NUMBER>

# Get PR JSON data
gh pr view <PR_NUMBER> --json commits,files,title,body
```

**Usage:**
- Use `gh pr view <number>` to inspect PR details
- Add `--json` flag to get structured data for parsing
- Useful fields: `commits`, `files`, `title`, `body`, `state`, `comments`

### Get PR Comments

```bash
# Get all comments from a PR
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments

# Filter for unresolved comments
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments --jq '.[] | select(.resolved == false)'
```

### Apply Commits from PR

```bash
# Cherry-pick commits from a PR (excluding merge commits)
gh pr view <PR_NUMBER> --json commits -q '.commits[].oid' | xargs -I {} git cherry-pick {}
```

### Add/Edit PR Reviewers

```bash
# Add reviewers to a PR
gh pr edit --add-reviewer <reviewer>

# Add multiple reviewers at once
gh pr edit --add-reviewer org/team-name --add-reviewer @me/copilot

# Add reviewer to specific PR
gh pr edit <PR_NUMBER> --add-reviewer <reviewer>
```

## Workflow Operations

### Trigger Workflow

```bash
# Deploy to specific environment
gh workflow run $CLAUDE_GITHUB_WORKFLOW_FILE --ref $CLAUDE_GIT_DEPLOY_BRANCH -f environment=<ENV>
```

**Usage:**
- Always specify `--ref` for the target branch
- Use `-f` flag to pass workflow input parameters
- Environment options from `$CLAUDE_ENVIRONMENTS`

**Related slash command:** `/deploy`

### Monitor Workflow Run

```bash
# Watch the latest workflow run in real-time
gh run watch $(gh run list --workflow=$CLAUDE_GITHUB_WORKFLOW_FILE --limit=1 --json databaseId -q '.[0].databaseId')

# Combined deployment + monitoring
gh workflow run $CLAUDE_GITHUB_WORKFLOW_FILE --ref $CLAUDE_GIT_DEPLOY_BRANCH -f environment=<ENV> && sleep 3 && gh run watch $(gh run list --workflow=$CLAUDE_GITHUB_WORKFLOW_FILE --limit=1 --json databaseId -q '.[0].databaseId')
```

### List Workflow Runs

```bash
# List recent workflow runs
gh run list --workflow=$CLAUDE_GITHUB_WORKFLOW_FILE --limit=10

# Get specific run details
gh run view <run-id>

# Check run status
gh run list --workflow=$CLAUDE_GITHUB_WORKFLOW_FILE --json status,conclusion,databaseId
```

## Repository Operations

### Check Repository Status

```bash
# View current repo info
gh repo view

# Get JSON data
gh repo view --json name,owner,defaultBranchRef
```

### Browse on GitHub

```bash
# Open current repo in browser
gh browse

# Open specific PR
gh browse -- pull/2503

# Open specific file
gh browse src/app/component.ts
```

## API Operations

### Generic API Calls

```bash
# Get PR comments
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments

# Use jq for filtering
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments --jq '.[] | select(.resolved == false)'

# POST request
gh api repos/{owner}/{repo}/issues/<ISSUE_NUMBER>/comments -f body="Comment text"
```

## Common Patterns & Best Practices

### 1. Deployment Flow

```bash
# Full deployment with monitoring
gh workflow run $CLAUDE_GITHUB_WORKFLOW_FILE --ref $CLAUDE_GIT_DEPLOY_BRANCH -f environment=<ENV> && \
  sleep 3 && \
  gh run watch $(gh run list --workflow=$CLAUDE_GITHUB_WORKFLOW_FILE --limit=1 --json databaseId -q '.[0].databaseId')
```

### 2. PR Review Flow

```bash
# 1. View PR
gh pr view <PR_NUMBER>

# 2. Get unresolved comments
gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments --jq '.[] | select(.resolved == false)'

# 3. Checkout PR branch
gh pr checkout <PR_NUMBER>

# 4. Make changes and push
git add . && git commit -m "Address review comments" && git push
```

### 3. Branch + PR Creation Flow

```bash
# 1. Create feature branch
git checkout -b $CLAUDE_GIT_FEATURE_PREFIX<TICKET_NUMBER>

# 2. Make changes and commit
# ... (make changes)
git add . && git commit -m "$CLAUDE_COMMIT_PREFIX<TICKET_NUMBER>: Description"

# 3. Push branch
git push -u origin $CLAUDE_GIT_FEATURE_PREFIX<TICKET_NUMBER>

# 4. Create PR
gh pr create --base $CLAUDE_GIT_DEPLOY_BRANCH --head $CLAUDE_GIT_FEATURE_PREFIX<TICKET_NUMBER> --title "$CLAUDE_COMMIT_PREFIX<TICKET_NUMBER> Title" --body ""
```

### 4. Workflow Status Check

```bash
# Check if deployment succeeded
gh run list --workflow=$CLAUDE_GITHUB_WORKFLOW_FILE --limit=1 --json status,conclusion -q '.[0]'

# Watch for completion in scripts
while [[ $(gh run list --workflow=$CLAUDE_GITHUB_WORKFLOW_FILE --limit=1 --json status -q '.[0].status') == "in_progress" ]]; do
  sleep 10
done
```

## Integration with Azure DevOps

GitHub CLI commands are often combined with Azure CLI for workflow automation:

```bash
# Deploy and update task status
gh workflow run $CLAUDE_GITHUB_WORKFLOW_FILE --ref $CLAUDE_GIT_DEPLOY_BRANCH -f environment=<ENV> && \
  sleep 3 && \
  gh run watch $(gh run list --workflow=$CLAUDE_GITHUB_WORKFLOW_FILE --limit=1 --json databaseId -q '.[0].databaseId') && \
  az boards work-item update --id <TASK_ID> --state "Ready for testing"
```

See `/deploy` slash command for automated deployment with task updates.

## Related Slash Commands

- `/pr` - Create Pull Request with proper naming convention
- `/deploy` - Deploy to environment with optional task update
- `/git-start` - Start work on new task with git branch setup
- `/commit` - Commit changes with proper message format

## Tips

1. **Always validate inputs**: Check ticket numbers, branch names, and PR numbers before executing commands
2. **Use JSON output**: For automation, always use `--json` flag with specific field selection
3. **Monitor long operations**: Use `gh run watch` for workflows, don't just trigger and forget
4. **Read context files**: Get ticket info from context file for consistency
5. **Combine with git**: Most gh commands work best when combined with git operations
6. **Use sleep between operations**: When triggering then watching workflows, add `sleep 3` delay
7. **Check permissions**: Ensure gh CLI is authenticated with proper scopes (`gh auth status`)

## Authentication

Ensure GitHub CLI is authenticated:
```bash
# Check auth status
gh auth status

# Login if needed
gh auth login

# Refresh token
gh auth refresh
```

## References

- GitHub CLI Manual: https://cli.github.com/manual/
- GitHub API Docs: https://docs.github.com/en/rest
