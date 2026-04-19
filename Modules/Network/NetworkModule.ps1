<#
.SYNOPSIS
    FixPC Toolkit — Network Module (Router)
    Reference implementation for the Network module family.

    Covers:
        network — Full network diagnostic (adapter, IP, connectivity, DNS)

    Each sub-module follows: Collect → Analyze → Repair → Export
    Phase scriptblocks live in the stage subdirectories:
        Collect\NetworkCollect.ps1
        Analyze\NetworkAnalyze.ps1
        Repair\NetworkRepair.ps1
        Export\NetworkExport.ps1

    Exposed function: Invoke-NetworkSubmodule
        Same signature as Invoke-SystemSubmodule so WorkflowCoordinator's
        Invoke-ModuleById can route to it identically.

.VERSION 1.0
#>

# ============================================================
#  DOT-SOURCE STAGE FILES
# ============================================================
$ModuleRoot = $PSScriptRoot

. "$ModuleRoot\Collect\NetworkCollect.ps1"
. "$ModuleRoot\Analyze\NetworkAnalyze.ps1"
. "$ModuleRoot\Repair\NetworkRepair.ps1"
. "$ModuleRoot\Export\NetworkExport.ps1"

# ============================================================
#  MODULE ROUTER
#  Dispatches to the correct sub-module based on ModuleId.
#  V1: only "network" exists. Future IDs can be added here.
# ============================================================
function Invoke-NetworkSubmodule {
    param(
        [Parameter(Mandatory)] [string]        $ModuleId,
        [Parameter(Mandatory)] [string]        $ModuleName,
        [Parameter(Mandatory)] [PSCustomObject]$Context,
        [Parameter(Mandatory)] [hashtable]     $State
    )

    switch ($ModuleId) {
        "network" { return Invoke-NetworkDiagnostic -Context $Context -State $State }
        default {
            Write-LogWarning -Source "NetworkModule" -Message "Unknown network module ID: '$ModuleId'"
            return $null
        }
    }
}

# ============================================================
#  SUB-MODULE INVOCATION
# ============================================================

function Invoke-NetworkDiagnostic {
    param([PSCustomObject]$Context, [hashtable]$State)

    return Invoke-ModuleLifecycle `
        -ModuleId      "network" `
        -ModuleName    "Network Diagnostics" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_Network `
        -AnalyzeBlock  $Script:Analyze_Network `
        -RepairBlock   $Script:Repair_Network `
        -ExportBlock   $Script:Export_Network
}

Write-Verbose "[NetworkModule] Network module loaded (stage subdirectory architecture)."
