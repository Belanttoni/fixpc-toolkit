<#
.SYNOPSIS
    FixPC Toolkit — Result Consolidator
    Aggregates all module results into a single consolidated report object.
    Validates each result before accepting it.
    Feeds the Report layer.

    Severity model (project standard strings): ok | info | warn | error | critical

.VERSION 1.1 (realigned — string severity model)
#>

function Consolidate-Results {
    <#
    .SYNOPSIS
        Takes a list of ModuleResult objects and produces:
        - A consolidated summary object
        - The unified warnings list
        - The overall severity
        - Stats for the report header

    .PARAMETER Results
        List of PSCustomObject (ModuleResult) from all modules.

    .PARAMETER Context
        ExecutionContext — for session metadata.

    .RETURNS
        A ConsolidatedReport PSCustomObject.
    #>
    param(
        [Parameter(Mandatory)] [System.Collections.Generic.List[PSCustomObject]]$Results,
        [Parameter(Mandatory)] [PSCustomObject]$Context
    )

    Write-LogInfo -Source "Consolidator" -Message "Consolidating $($Results.Count) module results."

    # Validate each result
    foreach ($r in $Results) {
        try { Assert-ValidModuleResult -Result $r }
        catch {
            Write-LogWarning -Source "Consolidator" -Message "Invalid result from '$($r.ModuleName)': $_"
        }
    }

    # Aggregate warnings across all modules
    $allWarnings = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $Results) {
        foreach ($w in $r.Warnings) { $allWarnings.Add("[$($r.ModuleName)] $w") }
        foreach ($e in $r.Errors)   { $allWarnings.Add("[ERROR][$($r.ModuleName)] $e") }

        # Promote high-severity findings to warnings list
        foreach ($f in $r.Findings) {
            $sev = $f.Severity.ToLower()
            if ($sev -eq "error" -or $sev -eq "critical") {
                $sym = if ($sev -eq "critical") { Get-Symbol "Cross" } else { Get-Symbol "Warn" }
                $allWarnings.Add("$sym [$($r.ModuleName)] $($f.Title): $($f.Description)")
            }
        }
    }

    # Overall severity = highest across all modules (uses Compare-Severity from Contracts.ps1)
    $overallSeverity = "ok"
    foreach ($r in $Results) {
        if ((Compare-Severity $r.Severity $overallSeverity) -gt 0) {
            $overallSeverity = $r.Severity
        }
    }

    # Stats — based on UiStatus string derived from severity
    $okCount   = ($Results | Where-Object {
        $_.Success -and ($_.Severity -eq "ok" -or $_.Severity -eq "info")
    }).Count

    $warnCount = ($Results | Where-Object {
        $_.Severity -eq "warn"
    }).Count

    $errCount  = ($Results | Where-Object {
        -not $_.Success -or $_.Severity -eq "error" -or $_.Severity -eq "critical"
    }).Count

    $endTime     = Get-Date
    $totalSec    = ($endTime - $Context.StartTime).TotalSeconds
    $totalDurStr = Format-Duration -Seconds ([math]::Round($totalSec, 1))

    $report = [PSCustomObject]@{
        # Metadata
        SessionId       = $Context.SessionId
        Computer        = $Context.Computer
        User            = $Context.User
        OS              = $Context.OS
        ExecutionMode   = $Context.Mode
        StartTime       = $Context.StartTime
        EndTime         = $endTime
        TotalDuration   = $totalDurStr
        ReportFolder    = $Context.ReportFolder

        # Results
        ModuleResults   = $Results
        AllWarnings     = $allWarnings
        OverallSeverity = $overallSeverity   # string: ok|info|warn|error|critical

        # Stats
        TotalModules    = $Results.Count
        OkCount         = $okCount
        WarnCount       = $warnCount
        ErrorCount      = $errCount
        FindingsTotal   = ($Results | ForEach-Object { $_.Findings.Count } | Measure-Object -Sum).Sum
        ActionsTotal    = ($Results | ForEach-Object { $_.ActionsTaken.Count } | Measure-Object -Sum).Sum

        # Performance snapshot (populated separately by sysinfo module)
        CpuLoad         = 0
        RamPct          = 0
        DiskPct         = 0
    }

    Write-LogInfo -Source "Consolidator" -Message "Consolidation complete. Overall severity: $overallSeverity | Warnings: $($allWarnings.Count)"
    return $report
}

function Update-ReportPerformance {
    <#
    .SYNOPSIS
        Injects CPU/RAM/Disk values into the consolidated report after sysinfo runs.
    #>
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Report,
        [double] $CpuLoad = 0,
        [double] $RamPct  = 0,
        [double] $DiskPct = 0
    )
    $Report.CpuLoad  = $CpuLoad
    $Report.RamPct   = $RamPct
    $Report.DiskPct  = $DiskPct
}

Write-Verbose "[Consolidator] Result consolidator loaded."
