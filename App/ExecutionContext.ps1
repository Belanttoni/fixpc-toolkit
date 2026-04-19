<#
.SYNOPSIS
    FixPC Toolkit — Execution Context Manager
    Provides runtime context to modules during a workflow run.
    Passed by reference to all module invocations.

.VERSION 1.0
#>

function Get-ActiveModules {
    <#
    .SYNOPSIS
        Returns the filtered list of module definitions to execute,
        based on the ExecutionContext.Modules filter.
        If the filter is empty, all modules are returned.
    #>
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Context,
        [Parameter(Mandatory)] [array]          $AllDefinitions
    )

    if ($null -eq $Context.Modules -or $Context.Modules.Count -eq 0) {
        return $AllDefinitions
    }

    return $AllDefinitions | Where-Object { $_.Id -in $Context.Modules }
}

function Update-ContextReportPaths {
    <#
    .SYNOPSIS
        Stamps the execution context with the final report file paths.
        Called by WorkflowCoordinator after reports are generated.
    #>
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Context,
        [Parameter(Mandatory)] [string]         $Html,
        [Parameter(Mandatory)] [string]         $Txt,
        [Parameter(Mandatory)] [string]         $Json
    )

    $Context | Add-Member -NotePropertyName "ReportHTML" -NotePropertyValue $Html -Force
    $Context | Add-Member -NotePropertyName "ReportTXT"  -NotePropertyValue $Txt  -Force
    $Context | Add-Member -NotePropertyName "ReportJSON" -NotePropertyValue $Json -Force
}

function Get-ContextSummary {
    <#
    .SYNOPSIS
        Returns a human-readable summary of the execution context.
    #>
    param([Parameter(Mandatory)][PSCustomObject]$Context)

    return @"
Session  : $($Context.SessionId)
Mode     : $($Context.Mode)
Computer : $($Context.Computer)
User     : $($Context.User)
OS       : $($Context.OS)
Started  : $($Context.StartTime.ToString("MM/dd/yyyy HH:mm:ss"))
Reports  : $($Context.ReportFolder)
"@
}

Write-Verbose "[ExecutionContext] Execution context manager loaded."
