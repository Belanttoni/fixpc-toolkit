<#
.SYNOPSIS
    FixPC Toolkit — Core Execution Engine
    Manages the lifecycle of a single module invocation.
    Enforces the Collect → Analyze → Repair → Export contract.
    Wraps execution with timing, error handling, and state updates.

.VERSION 1.0
#>

function Invoke-ModuleLifecycle {
    <#
    .SYNOPSIS
        Executes a module through its full lifecycle:
            1. Collect  — gather raw system data
            2. Analyze  — evaluate findings and severity
            3. Repair   — apply fixes (if mode allows)
            4. Export   — prepare data for reporting

        Each phase is a scriptblock passed by the Module Layer.
        This engine handles: timing, logging, error trapping, state updates.

    .PARAMETER ModuleId
        The module identifier (used for state updates).

    .PARAMETER ModuleName
        Human-readable module name (used for logging).

    .PARAMETER ExecutionMode
        Controls whether repair phases are permitted.

    .PARAMETER State
        Shared synchronized hashtable (from State.ps1).

    .PARAMETER CollectBlock
        Scriptblock: data collection. Must populate $Result.Data.

    .PARAMETER AnalyzeBlock
        Scriptblock: analysis. Must populate $Result.Findings and $Result.Severity.

    .PARAMETER RepairBlock
        Scriptblock: repairs. Only called if mode allows. Must populate $Result.ActionsTaken.

    .PARAMETER ExportBlock
        Scriptblock: export formatting. Must populate $Result.ExportData.

    .RETURNS
        A fully populated ModuleResult object.
    #>
    param(
        [Parameter(Mandatory)] [string]       $ModuleId,
        [Parameter(Mandatory)] [string]       $ModuleName,
        [Parameter(Mandatory)] [ExecutionMode]$ExecutionMode,
        [Parameter(Mandatory)] [hashtable]    $State,
        [Parameter(Mandatory)] [scriptblock]  $CollectBlock,
        [Parameter(Mandatory)] [scriptblock]  $AnalyzeBlock,
        [scriptblock]                          $RepairBlock  = $null,
        [Parameter(Mandatory)] [scriptblock]  $ExportBlock
    )

    # Create standardized result
    $Result = New-ModuleResult -ModuleName $ModuleName -ExecutionMode $ExecutionMode
    $Result.StartedAt = Get-Date

    $sw = New-Stopwatch

    try {
        # ── PHASE 1: COLLECT ─────────────────────────────
        Set-ModuleStatus -State $State -ModuleId $ModuleId -Status "running"
        $Result.Stage = [ModuleStage]::Collect
        Push-LogMessage -State $State -Message "=== $ModuleName ===" -Type "step"
        Write-LogStep -Source $ModuleId -StepName "Collect"

        try {
            & $CollectBlock $Result $State
            Write-LogDebug -Source $ModuleId -Message "Collect phase complete."
        } catch {
            $Result.Errors.Add("Collect failed: $_")
            Write-LogError -Source $ModuleId -Message "Collect failed: $_"
            $Result.Success = $false
        }

        # ── PHASE 2: ANALYZE ─────────────────────────────
        $Result.Stage = [ModuleStage]::Analyze
        Write-LogStep -Source $ModuleId -StepName "Analyze"

        try {
            & $AnalyzeBlock $Result $State
            $Result.Severity = Get-HighestSeverity -Findings $Result.Findings
            Write-LogDebug -Source $ModuleId -Message "Analyze phase complete. Severity: $($Result.Severity)"
        } catch {
            $Result.Errors.Add("Analyze failed: $_")
            Write-LogError -Source $ModuleId -Message "Analyze failed: $_"
            $Result.Success = $false
        }

        # ── PHASE 3: REPAIR ──────────────────────────────
        if ($null -ne $RepairBlock -and (Test-CanRepair -Mode $ExecutionMode)) {
            $Result.Stage = [ModuleStage]::Repair
            Write-LogStep -Source $ModuleId -StepName "Repair"

            try {
                & $RepairBlock $Result $State
                Write-LogDebug -Source $ModuleId -Message "Repair phase complete. Actions taken: $($Result.ActionsTaken.Count)"
            } catch {
                $Result.Errors.Add("Repair failed: $_")
                Write-LogError -Source $ModuleId -Message "Repair failed: $_"
                # Repair failure does not set Success=false if collect/analyze succeeded
            }
        } elseif ($null -ne $RepairBlock -and $ExecutionMode -eq [ExecutionMode]::DiagnoseOnly) {
            Write-LogInfo -Source $ModuleId -Message "Repair skipped (DiagnoseOnly mode)."
        }

        # ── PHASE 4: EXPORT ──────────────────────────────
        $Result.Stage = [ModuleStage]::Export
        Write-LogStep -Source $ModuleId -StepName "Export"

        try {
            & $ExportBlock $Result $State
            Write-LogDebug -Source $ModuleId -Message "Export phase complete."
        } catch {
            $Result.Errors.Add("Export failed: $_")
            Write-LogError -Source $ModuleId -Message "Export failed: $_"
        }

        $Result.Stage = [ModuleStage]::Complete

    } catch {
        $Result.Success  = $false
        $Result.Stage    = [ModuleStage]::Failed
        $Result.Severity = $Script:SEV_ERROR
        $Result.Errors.Add("Unhandled exception: $_")
        Write-LogError -Source $ModuleId -Message "Unhandled exception: $_"
    }

    # ── FINALIZE ─────────────────────────────────────────
    $Result.FinishedAt      = Get-Date
    $Result.DurationSeconds = Get-ElapsedSeconds -Stopwatch $sw
    $timeStr                = Format-Duration -Seconds $Result.DurationSeconds

    Set-ModuleTime -State $State -ModuleId $ModuleId -TimeString $timeStr

    # Determine UI status from severity + success
    $uiStatus = if (-not $Result.Success) {
        "error"
    } else {
        Convert-SeverityToUiStatus -Severity $Result.Severity
    }

    Set-ModuleStatus -State $State -ModuleId $ModuleId -Status $uiStatus

    $statusIcon = switch ($uiStatus) {
        "ok"    { Get-Symbol "Check" }
        "warn"  { Get-Symbol "Warn"  }
        "error" { Get-Symbol "Cross" }
        default { " " }
    }

    Write-LogInfo -Source $ModuleId -Message "$statusIcon $ModuleName completed in $timeStr | Status: $uiStatus | Findings: $($Result.Findings.Count)"

    return $Result
}

Write-Verbose "[Execution] Execution engine loaded."
