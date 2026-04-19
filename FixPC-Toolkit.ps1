#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    FixPC Toolkit v1.0 — Entry Point
    Slow PC diagnostic and repair automation tool.

    Architecture:
        Entry         → UI.WinForms/MainForm.ps1
        UI.WinForms   → App/WorkflowCoordinator.ps1
        App           → Modules/System/SystemModule.ps1
        SystemModule  → System/Collect|Analyze|Repair|Export stage files
        Modules       → Core/* (Contracts, Logging, State, Validation, Execution, Utilities)
        App           → Reports/* (HTML, TXT, JSON)

    Active UI layer : UI.WinForms/
    Deprecated      : UI/ (contains throw-stubs — safe to delete via git rm UI/)

    Execution Modes:
        DiagnoseOnly — collect and analyze only, no changes
        SafeRepair   — non-destructive repairs (default)
        FullRepair   — all repairs including aggressive fixes

.NOTES
    Run as Administrator:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        .\FixPC-Toolkit.ps1

    To compile to .exe (optional):
        Install-Module ps2exe -Force -Scope CurrentUser
        ps2exe .\FixPC-Toolkit.ps1 .\FixPC-Toolkit.exe -requireAdmin -noConsole -title "FixPC Toolkit"

.VERSION 1.0
#>

# ============================================================
#  BOOTSTRAP — resolve root path and load all layers
# ============================================================
$ToolkitRoot = $PSScriptRoot

# Core (order matters — Contracts must be first)
. "$ToolkitRoot\Core\Contracts.ps1"
. "$ToolkitRoot\Core\Utilities.ps1"
. "$ToolkitRoot\Core\Logging.ps1"
. "$ToolkitRoot\Core\State.ps1"
. "$ToolkitRoot\Core\Validation.ps1"
. "$ToolkitRoot\Core\Execution.ps1"

# App
. "$ToolkitRoot\App\Bootstrap.ps1"
. "$ToolkitRoot\App\ExecutionContext.ps1"
. "$ToolkitRoot\App\ResultConsolidator.ps1"
. "$ToolkitRoot\App\WorkflowCoordinator.ps1"

# UI.WinForms (load last — depends on Core + App definitions)
. "$ToolkitRoot\UI.WinForms\Theme.ps1"
. "$ToolkitRoot\UI.WinForms\Components.ps1"
. "$ToolkitRoot\UI.WinForms\MainForm.ps1"

# ============================================================
#  CREATE SHARED STATE
# ============================================================
$AppState = New-AppState

# ============================================================
#  GET MODULE DEFINITIONS
# ============================================================
$Modules = Get-AllModuleDefinitions

# Initialize module status slots in state
foreach ($m in $Modules) {
    $AppState.ModuleStatus[$m.Id] = "pending"
    $AppState.ModuleTimes[$m.Id]  = ""
}

# ============================================================
#  LAUNCH UI
# ============================================================
Show-MainForm -ModuleDefinitions $Modules -InitialState $AppState
