<#
.SYNOPSIS
    FixPC Toolkit — System Module (Router)
    Reference module. All other modules follow this pattern.

    Covers:
        sysinfo   — System Information (CPU, RAM, Disk, Uptime)
        sfc       — SFC /scannow
        dism      — DISM RestoreHealth
        chkdsk    — CHKDSK /scan + /spotfix (no reboot)
        temp      — Clear Temporary Files
        events    — Event Viewer (last 24h)
        winupdate — Windows Update
        startup   — Startup Programs
        smart     — Disk SMART Health
        ram       — RAM Health

    Each sub-module follows: Collect → Analyze → Repair → Export
    Phase scriptblocks live in the stage subdirectories:
        Collect\SystemCollect.ps1
        Analyze\SystemAnalyze.ps1
        Repair\SystemRepair.ps1
        Export\SystemExport.ps1

.VERSION 1.1 (realigned — stage subdirectory architecture)
#>

# ============================================================
#  DOT-SOURCE STAGE FILES
# ============================================================
$ModuleRoot = $PSScriptRoot

. "$ModuleRoot\Collect\SystemCollect.ps1"
. "$ModuleRoot\Analyze\SystemAnalyze.ps1"
. "$ModuleRoot\Repair\SystemRepair.ps1"
. "$ModuleRoot\Export\SystemExport.ps1"

# ============================================================
#  MODULE ROUTER
#  Dispatches to the correct sub-module based on ModuleId.
# ============================================================
function Invoke-SystemSubmodule {
    param(
        [Parameter(Mandatory)] [string]        $ModuleId,
        [Parameter(Mandatory)] [string]        $ModuleName,
        [Parameter(Mandatory)] [PSCustomObject]$Context,
        [Parameter(Mandatory)] [hashtable]     $State
    )

    switch ($ModuleId) {
        "sysinfo"   { return Invoke-SysInfo   -Context $Context -State $State }
        "sfc"       { return Invoke-SFC       -Context $Context -State $State }
        "dism"      { return Invoke-DISM      -Context $Context -State $State }
        "chkdsk"    { return Invoke-ChkDsk    -Context $Context -State $State }
        "temp"      { return Invoke-TempClean -Context $Context -State $State }
        "events"    { return Invoke-EventScan -Context $Context -State $State }
        "winupdate" { return Invoke-WinUpdate -Context $Context -State $State }
        "startup"   { return Invoke-Startup   -Context $Context -State $State }
        "smart"     { return Invoke-SmartDisk -Context $Context -State $State }
        "ram"       { return Invoke-RamHealth -Context $Context -State $State }
        default {
            Write-LogWarning -Source "SystemModule" -Message "Unknown module ID: $ModuleId"
            return $null
        }
    }
}

# ============================================================
#  SUB-MODULE INVOCATION FUNCTIONS
#  Each wires the stage scriptblocks into Invoke-ModuleLifecycle.
# ============================================================

function Invoke-SysInfo {
    param([PSCustomObject]$Context, [hashtable]$State)
    return Invoke-ModuleLifecycle `
        -ModuleId      "sysinfo" `
        -ModuleName    "System Information" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_SysInfo `
        -AnalyzeBlock  $Script:Analyze_SysInfo `
        -ExportBlock   $Script:Export_SysInfo
}

function Invoke-SFC {
    param([PSCustomObject]$Context, [hashtable]$State)
    # Collect: sfc /verifyonly (non-mutating)
    # Repair:  sfc /scannow   (SafeRepair or FullRepair only — may take several minutes)
    return Invoke-ModuleLifecycle `
        -ModuleId      "sfc" `
        -ModuleName    "SFC /scannow" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_SFC `
        -AnalyzeBlock  $Script:Analyze_SFC `
        -RepairBlock   $Script:Repair_SFC `
        -ExportBlock   $Script:Export_SFC
}

function Invoke-DISM {
    param([PSCustomObject]$Context, [hashtable]$State)
    # Collect: DISM /CheckHealth (instant metadata read — non-mutating)
    # Repair:  DISM /ScanHealth  (SafeRepair) or /RestoreHealth (FullRepair — 15-45 min, normal to pause at 62%)
    return Invoke-ModuleLifecycle `
        -ModuleId      "dism" `
        -ModuleName    "DISM RestoreHealth" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_DISM `
        -AnalyzeBlock  $Script:Analyze_DISM `
        -RepairBlock   $Script:Repair_DISM `
        -ExportBlock   $Script:Export_DISM
}

function Invoke-ChkDsk {
    param([PSCustomObject]$Context, [hashtable]$State)
    Push-LogMessage -State $State -Message "  Using online scan (chkdsk /scan) — no reboot required." -Type "info"
    return Invoke-ModuleLifecycle `
        -ModuleId      "chkdsk" `
        -ModuleName    "CHKDSK /scan+/spotfix" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_ChkDsk `
        -AnalyzeBlock  $Script:Analyze_ChkDsk `
        -RepairBlock   $Script:Repair_ChkDsk `
        -ExportBlock   $Script:Export_ChkDsk
}

function Invoke-TempClean {
    param([PSCustomObject]$Context, [hashtable]$State)
    return Invoke-ModuleLifecycle `
        -ModuleId      "temp" `
        -ModuleName    "Clear Temp Files" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_Temp `
        -AnalyzeBlock  $Script:Analyze_Temp `
        -RepairBlock   $Script:Repair_Temp `
        -ExportBlock   $Script:Export_Temp
}

function Invoke-EventScan {
    param([PSCustomObject]$Context, [hashtable]$State)
    return Invoke-ModuleLifecycle `
        -ModuleId      "events" `
        -ModuleName    "Event Viewer" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_Events `
        -AnalyzeBlock  $Script:Analyze_Events `
        -ExportBlock   $Script:Export_Events
}

function Invoke-WinUpdate {
    param([PSCustomObject]$Context, [hashtable]$State)
    return Invoke-ModuleLifecycle `
        -ModuleId      "winupdate" `
        -ModuleName    "Windows Update" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_WinUpdate `
        -AnalyzeBlock  $Script:Analyze_WinUpdate `
        -RepairBlock   $Script:Repair_WinUpdate `
        -ExportBlock   $Script:Export_WinUpdate
}

function Invoke-Startup {
    param([PSCustomObject]$Context, [hashtable]$State)
    return Invoke-ModuleLifecycle `
        -ModuleId      "startup" `
        -ModuleName    "Startup Programs" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_Startup `
        -AnalyzeBlock  $Script:Analyze_Startup `
        -ExportBlock   $Script:Export_Startup
}

function Invoke-SmartDisk {
    param([PSCustomObject]$Context, [hashtable]$State)
    return Invoke-ModuleLifecycle `
        -ModuleId      "smart" `
        -ModuleName    "Disk SMART Health" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_Smart `
        -AnalyzeBlock  $Script:Analyze_Smart `
        -ExportBlock   $Script:Export_Smart
}

function Invoke-RamHealth {
    param([PSCustomObject]$Context, [hashtable]$State)
    return Invoke-ModuleLifecycle `
        -ModuleId      "ram" `
        -ModuleName    "RAM Health" `
        -ExecutionMode $Context.Mode `
        -State         $State `
        -CollectBlock  $Script:Collect_Ram `
        -AnalyzeBlock  $Script:Analyze_Ram `
        -RepairBlock   $Script:Repair_Ram `
        -ExportBlock   $Script:Export_Ram
}

Write-Verbose "[SystemModule] System module loaded (stage subdirectory architecture)."
