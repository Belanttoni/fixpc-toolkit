<#
.SYNOPSIS
    FixPC Toolkit — Workflow Coordinator
    Orchestrates all module executions in sequence.
    This is the "engine" of the application — it coordinates, never acts directly.
    Business logic lives in modules. Reporting lives in Reports/. UI lives in UI/.

.VERSION 1.0
#>

function Start-DiagnosticWorkflow {
    <#
    .SYNOPSIS
        Main entry point for the diagnostic workflow.
        Runs all selected modules in sequence through the lifecycle engine.
        Called from a background runspace so the UI thread stays responsive.

    .PARAMETER Context
        ExecutionContext from Bootstrap.

    .PARAMETER State
        Shared synchronized state hashtable.

    .PARAMETER ModuleDefinitions
        Ordered array of module definitions to run.
    #>
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Context,
        [Parameter(Mandatory)] [hashtable]      $State,
        [Parameter(Mandatory)] [array]          $ModuleDefinitions
    )

    $State.IsRunning = $true
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    Write-LogInfo -Source "Coordinator" -Message "Workflow started. Modules: $($ModuleDefinitions.Count) | Mode: $($Context.Mode)"
    Push-LogMessage -State $State -Message "FixPC Toolkit | Session: $($Context.SessionId) | Mode: $($Context.Mode)" -Type "info"
    Push-LogMessage -State $State -Message "Computer: $($Context.Computer) | User: $($Context.User)" -Type "info"
    Push-LogMessage -State $State -Message ("-" * 50) -Type "info"

    $totalModules = $ModuleDefinitions.Count
    $stepNum      = 0

    foreach ($modDef in $ModuleDefinitions) {
        $stepNum++
        $progressPct = [int](($stepNum - 1) / $totalModules * 90)  # Reserve last 10% for reports
        Set-Progress -State $State -Value $progressPct -Message "Running: $($modDef.Name) ($stepNum/$totalModules)"

        Write-LogInfo -Source "Coordinator" -Message "Starting module: $($modDef.Id) [$stepNum/$totalModules]"

        try {
            $result = Invoke-SystemSubmodule -ModuleId $modDef.Id -ModuleName $modDef.Name -Context $Context -State $State

            if ($null -ne $result) {
                $results.Add($result)

                # Propagate high-severity warnings to state
                foreach ($f in $result.Findings) {
                    $sev = $f.Severity.ToLower()
                    if ($sev -eq "warn" -or $sev -eq "error" -or $sev -eq "critical") {
                        $sym = if ($sev -eq "error" -or $sev -eq "critical") { [char]0x2716 } else { [char]0x26A0 }
                        Add-StateWarning -State $State -Warning "$sym [$($modDef.Name)] $($f.Title)"
                    }
                }

                # Update performance gauges from sysinfo
                if ($modDef.Id -eq "sysinfo" -and $result.Data.ContainsKey("CpuLoad")) {
                    $State.CpuLoad  = $result.Data.CpuLoad
                    $State.RamPct   = $result.Data.RamPct
                    $State.DiskPct  = $result.Data.DiskPct
                }
            }
        } catch {
            Write-LogError -Source "Coordinator" -Message "Module '$($modDef.Id)' threw unhandled exception: $_"
            Set-ModuleStatus -State $State -ModuleId $modDef.Id -Status "error"
            Push-LogMessage -State $State -Message "Module $($modDef.Name) failed unexpectedly: $_" -Type "error"
        }
    }

    # ── REPORTING PHASE ───────────────────────────────────────
    Set-Progress -State $State -Value 92 -Message "Consolidating results..."
    Write-LogInfo -Source "Coordinator" -Message "Consolidating results..."

    $report = Consolidate-Results -Results $results -Context $Context
    Update-ReportPerformance -Report $report -CpuLoad $State.CpuLoad -RamPct $State.RamPct -DiskPct $State.DiskPct

    Set-Progress -State $State -Value 95 -Message "Generating reports..."
    Write-LogInfo -Source "Coordinator" -Message "Generating reports..."

    $htmlPath = Join-Path $Context.ReportFolder "Report_$($Context.SessionId).html"
    $txtPath  = Join-Path $Context.ReportFolder "Report_$($Context.SessionId).txt"
    $jsonPath = Join-Path $Context.ReportFolder "Report_$($Context.SessionId).json"

    Export-HtmlReport  -Report $report -OutputPath $htmlPath
    Export-TxtReport   -Report $report -OutputPath $txtPath
    Export-JsonReport  -Report $report -OutputPath $jsonPath

    # Update state with report paths
    $State.ReportFolder = $Context.ReportFolder
    $State.ReportHTML   = $htmlPath
    $State.ReportTXT    = $txtPath
    $State.ReportJSON   = $jsonPath
    $State.Results      = $results

    Set-Progress -State $State -Value 100 -Message "Diagnostic complete!"
    Push-LogMessage -State $State -Message "" -Type "ok"
    Push-LogMessage -State $State -Message ("=" * 50) -Type "ok"
    Push-LogMessage -State $State -Message "  DIAGNOSTIC COMPLETE  |  Session: $($Context.SessionId)" -Type "ok"
    Push-LogMessage -State $State -Message "  Reports saved to: $($Context.ReportFolder)" -Type "ok"
    Push-LogMessage -State $State -Message ("=" * 50) -Type "ok"

    Write-LogInfo -Source "Coordinator" -Message "Workflow complete. Session: $($Context.SessionId)"
    Complete-AppState -State $State
    $State.ReportReady = $true
}

Write-Verbose "[WorkflowCoordinator] Workflow coordinator loaded."
