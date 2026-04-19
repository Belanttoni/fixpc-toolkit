<#
.SYNOPSIS
    FixPC Toolkit — Hardware Module Router
    Dot-sources all Hardware stage scriptblocks and exposes
    Invoke-HardwareSubmodule as the dispatch entry point.

    Modules handled: "hardware"

    Stage scriptblocks registered:
        $Script:Collect_Hardware   (HardwareCollect.ps1)
        $Script:Analyze_Hardware   (HardwareAnalyze.ps1)
        $Script:Repair_Hardware    (HardwareRepair.ps1)
        $Script:Export_Hardware    (HardwareExport.ps1)

    Repair policy (enforced by Invoke-ModuleLifecycle):
        DiagnoseOnly — Repair block NOT called.
        SafeRepair   — Repair block called; generates advisory records only.
        FullRepair   — Repair block called; generates advisory records only.
        Hardware V1 never modifies hardware state in any mode.

.VERSION 1.0
#>

$ModuleRoot = $PSScriptRoot

. "$ModuleRoot\Collect\HardwareCollect.ps1"
. "$ModuleRoot\Analyze\HardwareAnalyze.ps1"
. "$ModuleRoot\Repair\HardwareRepair.ps1"
. "$ModuleRoot\Export\HardwareExport.ps1"

# ============================================================
#  PUBLIC ROUTER
# ============================================================
function Invoke-HardwareSubmodule {
    param(
        [Parameter(Mandatory)] [string]       $ModuleId,
        [Parameter(Mandatory)] [string]       $ModuleName,
        [Parameter(Mandatory)] [PSCustomObject]$Context,
        [Parameter(Mandatory)] [hashtable]    $State
    )

    switch ($ModuleId) {
        "hardware" { return Invoke-HardwareDiagnostic -Context $Context -State $State }
        default {
            Write-LogWarning -Context $Context `
                -Message "HardwareModule: unknown module id '$ModuleId' — skipping."
            return $null
        }
    }
}

# ============================================================
#  HARDWARE DIAGNOSTIC
# ============================================================
function Invoke-HardwareDiagnostic {
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Context,
        [Parameter(Mandatory)] [hashtable]    $State
    )

    return Invoke-ModuleLifecycle `
        -ModuleId       "hardware" `
        -ModuleName     "Hardware Diagnostics" `
        -Context        $Context `
        -State          $State `
        -CollectBlock   $Script:Collect_Hardware `
        -AnalyzeBlock   $Script:Analyze_Hardware `
        -RepairBlock    $Script:Repair_Hardware `
        -ExportBlock    $Script:Export_Hardware
}

Write-Verbose "[HardwareModule] Hardware module loaded."
