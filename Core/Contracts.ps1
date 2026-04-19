<#
.SYNOPSIS
    FixPC Toolkit — Core Contracts
    Defines all shared data structures, enums, and interface contracts.
    Every module and service MUST conform to these definitions.

.VERSION 1.1 (realigned — severity model + result schema per project standard)
#>

# ============================================================
#  EXECUTION MODES
# ============================================================
enum ExecutionMode {
    DiagnoseOnly = 0   # Collect + Analyze only. No changes made.
    SafeRepair   = 1   # Non-destructive repairs only.
    FullRepair   = 2   # All repairs including aggressive fixes.
}

# ============================================================
#  SEVERITY MODEL  (official project standard — string values)
#  ok | info | warn | error | critical
# ============================================================
$Script:SEV_OK       = "ok"
$Script:SEV_INFO     = "info"
$Script:SEV_WARN     = "warn"
$Script:SEV_ERROR    = "error"
$Script:SEV_CRITICAL = "critical"

# Ordered array used for weight comparison (index = severity weight)
$Script:SeverityOrder = @("ok", "info", "warn", "error", "critical")

function Compare-Severity {
    <#
    .SYNOPSIS
        Returns 1 if A is more severe than B, -1 if less, 0 if equal.
    #>
    param([string]$A, [string]$B)
    $ia = $Script:SeverityOrder.IndexOf($A.ToLower())
    $ib = $Script:SeverityOrder.IndexOf($B.ToLower())
    if ($ia -gt $ib) { return 1 }
    if ($ia -lt $ib) { return -1 }
    return 0
}

function Get-HighestSeverity {
    <#
    .SYNOPSIS
        Returns the highest severity string from a list of Finding objects.
    #>
    param([System.Collections.Generic.List[PSCustomObject]]$Findings)

    if (-not $Findings -or $Findings.Count -eq 0) { return $Script:SEV_OK }
    $highest = $Script:SEV_OK
    foreach ($f in $Findings) {
        if ((Compare-Severity $f.Severity $highest) -gt 0) {
            $highest = $f.Severity
        }
    }
    return $highest
}

function Convert-SeverityToHtmlClass {
    param([string]$Severity)
    switch ($Severity.ToLower()) {
        "critical" { return "error" }
        "error"    { return "error" }
        "warn"     { return "warn"  }
        "info"     { return "info"  }
        "ok"       { return "ok"    }
        default    { return "ok"    }
    }
}

function Convert-SeverityToUiStatus {
    param([string]$Severity)
    switch ($Severity.ToLower()) {
        "critical" { return "error" }
        "error"    { return "error" }
        "warn"     { return "warn"  }
        "info"     { return "ok"    }
        "ok"       { return "ok"    }
        default    { return "ok"    }
    }
}

# ============================================================
#  LOG LEVELS
# ============================================================
enum LogLevel {
    Debug    = 0
    Info     = 1
    Warning  = 2
    Error    = 3
    Critical = 4
}

# ============================================================
#  MODULE LIFECYCLE STAGES
# ============================================================
enum ModuleStage {
    Pending  = 0
    Collect  = 1
    Analyze  = 2
    Repair   = 3
    Export   = 4
    Complete = 5
    Failed   = 6
    Skipped  = 7
}

# ============================================================
#  MODULE RESULT CONTRACT
#  Field names are the official contract. Do not add/rename fields.
# ============================================================
function New-ModuleResult {
    <#
    .SYNOPSIS
        Factory — creates a standardized module result object.
    #>
    param(
        [Parameter(Mandatory)] [string]       $ModuleName,
        [Parameter(Mandatory)] [ExecutionMode]$ExecutionMode
    )

    return [PSCustomObject]@{
        # Identity
        ModuleName      = $ModuleName
        ExecutionMode   = $ExecutionMode

        # Timing  (StartedAt / FinishedAt — project contract field names)
        StartedAt       = $null
        FinishedAt      = $null
        DurationSeconds = 0

        # Outcome
        Success         = $true
        Severity        = $Script:SEV_OK    # string: ok|info|warn|error|critical
        Stage           = [ModuleStage]::Pending

        # Findings
        Findings        = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Recommendations
        Recommendations = [System.Collections.Generic.List[string]]::new()

        # Actions taken (repair modes only)
        ActionsTaken    = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Issues
        Errors          = [System.Collections.Generic.List[string]]::new()
        Warnings        = [System.Collections.Generic.List[string]]::new()

        # Raw collected data (module-specific, schema-free)
        Data            = [ordered]@{}

        # Formatted data for report export
        ExportData      = [ordered]@{}
    }
}

# ============================================================
#  FINDING CONTRACT
# ============================================================
function New-Finding {
    param(
        [Parameter(Mandatory)] [string]$Title,
        [Parameter(Mandatory)] [string]$Severity,    # ok|info|warn|error|critical
        [string] $Description  = "",
        [string] $Detail       = "",
        [bool]   $Repaired     = $false,
        [string] $RepairAction = ""
    )

    if ($Severity -notin $Script:SeverityOrder) {
        throw "Invalid severity '$Severity'. Must be: $($Script:SeverityOrder -join ', ')"
    }

    return [PSCustomObject]@{
        Title        = $Title
        Severity     = $Severity
        Description  = $Description
        Detail       = $Detail
        Repaired     = $Repaired
        RepairAction = $RepairAction
        Timestamp    = Get-Date
    }
}

# ============================================================
#  ACTION RECORD CONTRACT
# ============================================================
function New-ActionRecord {
    param(
        [Parameter(Mandatory)] [string]$Action,
        [Parameter(Mandatory)] [string]$Target,
        [bool]   $Success     = $true,
        [string] $Detail      = "",
        [string] $ErrorDetail = ""
    )

    return [PSCustomObject]@{
        Action      = $Action
        Target      = $Target
        Success     = $Success
        Detail      = $Detail
        ErrorDetail = $ErrorDetail
        Timestamp   = Get-Date
    }
}

# ============================================================
#  LOG ENTRY CONTRACT
# ============================================================
function New-LogEntry {
    param(
        [Parameter(Mandatory)] [LogLevel]$Level,
        [Parameter(Mandatory)] [string]  $Source,
        [Parameter(Mandatory)] [string]  $Message,
        [object] $Data = $null
    )

    return [PSCustomObject]@{
        Timestamp = Get-Date
        Level     = $Level
        Source    = $Source
        Message   = $Message
        Data      = $Data
    }
}

# ============================================================
#  EXECUTION CONTEXT CONTRACT
# ============================================================
function New-ExecutionContext {
    param(
        [ExecutionMode] $Mode    = [ExecutionMode]::DiagnoseOnly,
        [string[]]      $Modules = @()
    )

    return [PSCustomObject]@{
        SessionId    = [System.Guid]::NewGuid().ToString("N").Substring(0, 8).ToUpper()
        Mode         = $Mode
        StartTime    = Get-Date
        Computer     = $env:COMPUTERNAME
        User         = $env:USERNAME
        OS           = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
        Modules      = $Modules
        ReportFolder = "$env:SystemDrive\FixPC_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
    }
}

# NOTE: Assert-ValidModuleResult is defined in Core/Validation.ps1 (loaded after this file).
# It is the canonical result validation function. Do not redefine it here.

Write-Verbose "[Contracts] Loaded. Severity model: $($Script:SeverityOrder -join ' | ')"
