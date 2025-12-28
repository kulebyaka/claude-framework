---
allowed-tools: Bash, Read, Write, Glob, Grep, Task, Skill
argument-hint: <task-number> [--hint <hint-text>]
description: Fetch Azure DevOps task and gather codebase context
model: sonnet
---

# Azure DevOps Task Context Gathering

Fetch Azure DevOps work item $1 and gather relevant codebase context without creating an implementation plan.

## Environment Variables

These values come from `.claude/settings.json` → `env`:
- `CLAUDE_ADO_ORG` - Azure DevOps organization name
- `CLAUDE_ADO_PROJECT` - Azure DevOps project name
- `CLAUDE_ADO_BASE_URL` - Azure DevOps base URL
- `CLAUDE_CONTEXT_FILE` - path to save ticket context (default: `llm-context/current ticket.md`)

## Workflow

1. **Use the azure-devops Skill to Fetch Task Details**
   - Invoke the `azure-devops` skill to fetch work item $1
   - The skill will:
     - Fetch the work item using `az boards work-item show --id $1 --output json`
     - Parse the JSON response to extract title, description, acceptance criteria, work item type, state
     - Extract parent work item ID from relations and fetch parent context if exists
     - Handle HTML to markdown conversion for description fields

2. **Save the Important Information**
   - Rewrite the context file (`$CLAUDE_CONTEXT_FILE`) with structured:
     - Task ID and Title
     - Work Item Type
     - Description (converted to markdown)
     - Acceptance Criteria (converted to markdown)
     - Parent context (if applicable)
     - Link to Azure DevOps work item: `{CLAUDE_ADO_BASE_URL}/_workitems/edit/$1`
   - If there are image URLs in the description, note them for reference

3. **Check for --hint Flag**
   - If the user specified `--hint` in their command, they may have provided useful information about:
     - Where to find relevant implementation files
     - How to approach the implementation
     - Specific code patterns or conventions to follow
     - Files or components that need to be modified
     - Known challenges or gotchas
   - Parse any hint text provided after the `--hint` flag (captured in $ARGUMENTS)
   - If hints mention specific files, prioritize reading those files first
   - Do NOT create an implementation plan
   - Do NOT start any code changes

## Notes

- This command uses the `azure-devops` skill for all Azure DevOps interactions
- Use the Task tool for complex searches across the codebase
- This is a context-gathering command only - use `/ado-task` if you need a full implementation plan
