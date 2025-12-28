<#
.SYNOPSIS
    Deploy to environment and optionally update Azure DevOps task status on success.

.PARAMETER TaskId
    The Azure DevOps work item ID (e.g., 72191)

.PARAMETER Environment
    Target environment (e.g., QA01, QA02, QA05). Default: from $env:CLAUDE_DEFAULT_ENVIRONMENT or QA02

.PARAMETER Branch
    Git branch to deploy. Default: from $env:CLAUDE_GIT_DEPLOY_BRANCH or main

.PARAMETER TargetState
    State to set on successful deployment. Default: "Ready for testing"

.PARAMETER SkipTaskUpdate
    Skip updating the Azure DevOps task status (deploy only)

.PARAMETER IdleThreshold
    Seconds of idle time before sending notification. Default: from $env:CLAUDE_NOTIFY_IDLE_THRESHOLD or 30

.PARAMETER NoNotify
    Skip notifications entirely

.PARAMETER NtfyTopic
    ntfy.sh topic for push notifications. Default: from $env:CLAUDE_NTFY_TOPIC

.EXAMPLE
    .\deploy-and-update-task.ps1 -TaskId 72191
    .\deploy-and-update-task.ps1 -TaskId 72191 -SkipTaskUpdate
    .\deploy-and-update-task.ps1 -TaskId 72191 -Environment QA05
    .\deploy-and-update-task.ps1 -TaskId 72191 -Environment QA02 -TargetState "In Progress"
    .\deploy-and-update-task.ps1 -TaskId 72191 -NoNotify
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$TaskId = 0,

    [Parameter(Mandatory=$false)]
    [string]$Environment = $(if ($env:CLAUDE_DEFAULT_ENVIRONMENT) { $env:CLAUDE_DEFAULT_ENVIRONMENT } else { "QA02" }),

    [Parameter(Mandatory=$false)]
    [string]$Branch = $(if ($env:CLAUDE_GIT_DEPLOY_BRANCH) { $env:CLAUDE_GIT_DEPLOY_BRANCH } else { "main" }),

    [Parameter(Mandatory=$false)]
    [string]$TargetState = "Ready for testing",

    [Parameter(Mandatory=$false)]
    [switch]$SkipTaskUpdate,

    [Parameter(Mandatory=$false)]
    [int]$IdleThreshold = $(if ($env:CLAUDE_NOTIFY_IDLE_THRESHOLD) { [int]$env:CLAUDE_NOTIFY_IDLE_THRESHOLD } else { 30 }),

    [Parameter(Mandatory=$false)]
    [switch]$NoNotify,

    [Parameter(Mandatory=$false)]
    [string]$NtfyTopic = $(if ($env:CLAUDE_NTFY_TOPIC) { $env:CLAUDE_NTFY_TOPIC } else { "" }),

    [Parameter(Mandatory=$false)]
    [string]$WorkflowFile = $(if ($env:CLAUDE_GITHUB_WORKFLOW_FILE) { $env:CLAUDE_GITHUB_WORKFLOW_FILE } else { "build.yml" })
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$NotifyScript = Join-Path $ScriptDir "smart-notify.ps1"

function Send-Notification {
    param([string]$Message)

    if ($NoNotify) { return }

    if (Test-Path $NotifyScript) {
        $notifyArgs = @{
            Message = $Message
            IdleThreshold = $IdleThreshold
        }
        if ($NtfyTopic -ne "") {
            $notifyArgs.Topic = $NtfyTopic
        }
        & $NotifyScript @notifyArgs
    }
}

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Deploying to $Environment" -ForegroundColor Cyan
if ($TaskId -gt 0) {
    $prefix = if ($env:CLAUDE_COMMIT_PREFIX) { $env:CLAUDE_COMMIT_PREFIX } else { "" }
    Write-Host " Task: $prefix$TaskId" -ForegroundColor Cyan
}
Write-Host "========================================"  -ForegroundColor Cyan

# Step 1: Trigger the deployment
Write-Host "`n[1/4] Triggering deployment workflow..." -ForegroundColor Yellow
gh workflow run $WorkflowFile --ref $Branch -f environment=$Environment

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to trigger deployment workflow!" -ForegroundColor Red
    exit 1
}

Write-Host "Workflow triggered. Waiting for it to start..." -ForegroundColor Green
Start-Sleep -Seconds 5

# Step 2: Get the run ID
Write-Host "`n[2/4] Getting workflow run ID..." -ForegroundColor Yellow
$runId = gh run list --workflow=$WorkflowFile --limit=1 --json databaseId -q '.[0].databaseId'

if (-not $runId) {
    Write-Host "Failed to get workflow run ID!" -ForegroundColor Red
    exit 1
}

Write-Host "Workflow run ID: $runId" -ForegroundColor Green

# Step 3: Watch the deployment (minimal output to avoid context bloat)
Write-Host "`n[3/4] Watching deployment progress..." -ForegroundColor Yellow

$status = ""
$conclusion = ""
$lastStatus = ""
$dots = 0

while ($status -ne "completed") {
    $runInfo = gh run view $runId --json status,conclusion 2>$null | ConvertFrom-Json
    $status = $runInfo.status
    $conclusion = $runInfo.conclusion

    if ($status -ne $lastStatus) {
        if ($lastStatus -ne "") { Write-Host "" }
        Write-Host "Status: $status" -ForegroundColor Yellow -NoNewline
        $lastStatus = $status
        $dots = 0
    } else {
        $dots++
        if ($dots % 6 -eq 0) {
            Write-Host "." -NoNewline
        }
    }

    if ($status -ne "completed") {
        Start-Sleep -Seconds 10
    }
}
Write-Host ""

Write-Host "Deployment conclusion: $conclusion" -ForegroundColor $(if ($conclusion -eq "success") { "Green" } else { "Red" })

# Step 4: Update Azure DevOps task if successful (unless skipped)
$prefix = if ($env:CLAUDE_COMMIT_PREFIX) { $env:CLAUDE_COMMIT_PREFIX } else { "" }

if ($conclusion -eq "success") {
    if ($SkipTaskUpdate -or $TaskId -eq 0) {
        Write-Host "`n[4/4] Skipping task update" -ForegroundColor Yellow
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host " DEPLOYMENT COMPLETE" -ForegroundColor Green
        Write-Host " Environment: $Environment" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan

        Send-Notification "Deploy OK to $Environment"
    } else {
        Write-Host "`n[4/4] Updating Azure DevOps task #$TaskId to '$TargetState'..." -ForegroundColor Yellow

        try {
            az boards work-item update --id $TaskId --state $TargetState --output none

            if ($LASTEXITCODE -eq 0) {
                Write-Host "Task $prefix$TaskId updated to '$TargetState' successfully!" -ForegroundColor Green
                Write-Host "`n========================================" -ForegroundColor Cyan
                Write-Host " DEPLOYMENT COMPLETE" -ForegroundColor Green
                Write-Host " Environment: $Environment" -ForegroundColor Cyan
                Write-Host " Task $prefix$TaskId -> $TargetState" -ForegroundColor Cyan
                Write-Host "========================================" -ForegroundColor Cyan

                Send-Notification "Deploy OK: $prefix$TaskId to $Environment -> $TargetState"
            } else {
                Write-Host "Failed to update task status!" -ForegroundColor Red
                Send-Notification "Deploy OK but task update FAILED: $prefix$TaskId to $Environment"
                exit 1
            }
        }
        catch {
            Write-Host "Error updating task: $_" -ForegroundColor Red
            Send-Notification "Deploy OK but task update FAILED: $prefix$TaskId"
            exit 1
        }
    }
} else {
    Write-Host "`n[4/4] Deployment was not successful" -ForegroundColor Red
    Write-Host "Deployment status: $conclusion" -ForegroundColor Red
    $taskInfo = if ($TaskId -gt 0) { " ($prefix$TaskId)" } else { "" }
    Send-Notification "DEPLOY FAILED$taskInfo to $Environment ($conclusion)"
    exit 1
}
