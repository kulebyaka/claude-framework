---
name: azure-devops
description: "Fetches and analyzes Azure DevOps work items, tasks, user stories, bugs, and features using Azure CLI. Use when user mentions ADO, Azure DevOps, work items, task IDs (like #72382), ticket numbers, user stories, bugs, sprint items, acceptance criteria, or needs to query/update DevOps boards."
allowed-tools: Bash, Read, Write
---

# Azure DevOps Work Item Skill

Provides access to Azure DevOps work items through Azure CLI (`az boards`).

## Environment Variables

These values come from `.claude/settings.json` → `env`:
- `CLAUDE_ADO_ORG` - Azure DevOps organization name
- `CLAUDE_ADO_PROJECT` - Azure DevOps project name
- `CLAUDE_ADO_BASE_URL` - Azure DevOps base URL (e.g., `https://dev.azure.com/org/Project`)
- `CLAUDE_CONTEXT_FILE` - path to save ticket context (default: `llm-context/current ticket.md`)

## Prerequisites

Ensure Azure CLI is installed with DevOps extension and configured:
```bash
az devops configure --defaults organization=https://dev.azure.com/$CLAUDE_ADO_ORG project="$CLAUDE_ADO_PROJECT"
```

## Instructions

### Fetching a Work Item (Recommended: Use Script)

Use the provided Python script for consistent parsing and HTML-to-Markdown conversion:

```bash
# Fetch and parse directly
python .claude/skills/azure-devops/scripts/parse-work-item.py --id {WORK_ITEM_ID}

# With parent context
python .claude/skills/azure-devops/scripts/parse-work-item.py --id {WORK_ITEM_ID} --with-parent

# Save to file (uses CLAUDE_CONTEXT_FILE env var or specified path)
python .claude/skills/azure-devops/scripts/parse-work-item.py --id {WORK_ITEM_ID} --with-parent -o "$CLAUDE_CONTEXT_FILE"

# Or pipe from az cli
az boards work-item show --id {WORK_ITEM_ID} --output json | python .claude/skills/azure-devops/scripts/parse-work-item.py
```

### Manual Fetching (Alternative)

If you need raw JSON access:

```bash
az boards work-item show --id {WORK_ITEM_ID} --output json
```

Key fields in JSON response:
- **Title**: `fields["System.Title"]`
- **Description**: `fields["System.Description"]` (HTML format)
- **Acceptance Criteria**: `fields["Microsoft.VSTS.Common.AcceptanceCriteria"]` (HTML format)
- **Work Item Type**: `fields["System.WorkItemType"]` (Task, User Story, Bug, Feature, Epic)
- **State**: `fields["System.State"]`
- **Assigned To**: `fields["System.AssignedTo"].displayName`

### Finding Parent Work Items

Check the `relations` array for parent links:
- Parent: `rel === "System.LinkTypes.Hierarchy-Reverse"`
- Child: `rel === "System.LinkTypes.Hierarchy-Forward"`

Extract parent ID from the `url` field (last segment).

### Updating Work Items

```bash
# Update state
az boards work-item update --id {ID} --state "Active"

# Update fields
az boards work-item update --id {ID} --fields "System.Title=New Title"
```

### Changing Ticket State

Use Azure CLI to change the state of a work item:

```bash
# Change to "In Code Review" (when PR is created)
az boards work-item update --id {WORK_ITEM_ID} --state "In Code Review"

# Other common state transitions
az boards work-item update --id {WORK_ITEM_ID} --state "Active"
az boards work-item update --id {WORK_ITEM_ID} --state "Resolved"
az boards work-item update --id {WORK_ITEM_ID} --state "Closed"
```

Common work item states:
| State | Description |
|-------|-------------|
| New | Initial state for new work items |
| Active | Work in progress |
| In Code Review | PR created, awaiting review |
| Resolved | Work completed, pending verification |
| Closed | Work verified and closed |

### Creating Work Items

```bash
az boards work-item create --title "Task Title" --type Task --description "Description"
```

## Error Handling

| Error | Solution |
|-------|----------|
| Login required | Run `az login` |
| Extension missing | Run `az extension add --name azure-devops` |
| Not found | Verify work item ID exists |
| Access denied | Check project permissions |

## Output Format

When fetching work items, save structured information to the context file (`$CLAUDE_CONTEXT_FILE`).

Include:
- Task ID and Title
- Work Item Type
- Description (markdown)
- Acceptance Criteria (markdown)
- Parent context (if applicable)
- Direct link to work item

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/parse-work-item.py` | Fetches work item, parses JSON, converts HTML to Markdown |
