<#
.SYNOPSIS
    FixPC Toolkit — Core Validation Service
    Guards for execution mode boundaries, parameter checks, and pre-conditions.
    Every module uses these validators before acting.

.VERSION 1.0
#>

# ============================================================
#  EXECUTION MODE GUARDS
# ============================================================
function Assert-CanRepair {
    <#
    .SYNOPSIS
        Returns $true if the current execution mode allows any repair.
        Throws if mode is DiagnoseOnly and a repair is attempted.
    #>
    param(
        [Parameter(Mandatory)] [ExecutionMode]$Mode,
        [Parameter(Mandatory)] [string]        $ActionDescription
    )

    if ($Mode -eq [ExecutionMode]::DiagnoseOnly) {
        throw "POLICY VIOLATION: Repair blocked in DiagnoseOnly mode. Action: '$ActionDescription'"
    }
    return $true
}

function Assert-CanFullRepair {
    <#
    .SYNOPSIS
        Returns $true only if mode is FullRepair.
        Use for aggressive/destructive operations.
    #>
    param(
        [Parameter(Mandatory)] [ExecutionMode]$Mode,
        [Parameter(Mandatory)] [string]        $ActionDescription
    )

    if ($Mode -ne [ExecutionMode]::FullRepair) {
        throw "POLICY VIOLATION: This action requires FullRepair mode. Action: '$ActionDescription'"
    }
    return $true
}

function Test-CanRepair {
    <#
    .SYNOPSIS
        Non-throwing version of Assert-CanRepair. Returns bool.
    #>
    param([ExecutionMode]$Mode)
    return $Mode -ne [ExecutionMode]::DiagnoseOnly
}

function Test-CanFullRepair {
    <#
    .SYNOPSIS
        Non-throwing version of Assert-CanFullRepair. Returns bool.
    #>
    param([ExecutionMode]$Mode)
    return $Mode -eq [ExecutionMode]::FullRepair
}

# ============================================================
#  ADMINISTRATOR CHECK
# ============================================================
function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Returns $true if current session is elevated (Administrator).
    #>
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-IsAdministrator {
    if (-not (Test-IsAdministrator)) {
        throw "FixPC Toolkit requires Administrator privileges. Please re-run as Administrator."
    }
}

# ============================================================
#  MODULE ID VALIDATION
# ============================================================
$Script:ValidModuleIds = @(
    "sysinfo", "sfc", "dism", "chkdsk", "temp",
    "events", "winupdate", "startup", "smart", "ram", "network"
)

function Test-ValidModuleId {
    param([string]$ModuleId)
    return $ModuleId -in $Script:ValidModuleIds
}

function Assert-ValidModuleId {
    param([string]$ModuleId)
    if (-not (Test-ValidModuleId $ModuleId)) {
        throw "Invalid module ID: '$ModuleId'. Valid IDs: $($Script:ValidModuleIds -join ', ')"
    }
}

# ============================================================
#  PATH VALIDATION
# ============================================================
function Assert-PathExists {
    param([string]$Path, [string]$Label = "Path")
    if (-not (Test-Path $Path)) {
        throw "$Label not found: '$Path'"
    }
}

function Ensure-DirectoryExists {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# ============================================================
#  RESULT VALIDATION  (canonical — see Core/Contracts.ps1 for schema definition)
# ============================================================
function Assert-ValidModuleResult {
    <#
    .SYNOPSIS
        Validates that a ModuleResult conforms to the New-ModuleResult contract.
        Called by ResultConsolidator before accepting a result.
        Required fields mirror New-ModuleResult in Contracts.ps1.
    #>
    param([Parameter(Mandatory)][PSCustomObject]$Result)

    $required = @(
        "ModuleName", "ExecutionMode", "Success",
        "StartedAt", "FinishedAt", "DurationSeconds",
        "Severity", "Stage",
        "Findings", "Recommendations", "ActionsTaken",
        "Errors", "Warnings",
        "Data", "ExportData"
    )

    foreach ($prop in $required) {
        if ($null -eq $Result.PSObject.Properties[$prop]) {
            throw "ModuleResult is missing required field: '$prop'"
        }
    }

    # Severity must be a valid project string value
    $validSeverities = @("ok", "info", "warn", "error", "critical")
    if ($Result.Severity -notin $validSeverities) {
        throw "ModuleResult.Severity is invalid: '$($Result.Severity)'. Must be one of: $($validSeverities -join ', ')"
    }

    return $true
}

Write-Verbose "[Validation] Validation service loaded."
