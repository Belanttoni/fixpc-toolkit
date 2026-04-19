<#
.SYNOPSIS
    FixPC Toolkit — Core State Manager
    Centralized, thread-safe state store shared between background runspace and UI thread.
    The UI Timer polls this store to update the interface without blocking.

.VERSION 1.0
#>

# ============================================================
#  STATE STORE
# ============================================================
function New-AppState {
    <#
    .SYNOPSIS
        Creates and returns the synchronized shared state object.
        Must be called once at startup, before runspaces are created.
        The returned hashtable is passed to all runspaces.
    #>
    $state = [hashtable]::Synchronized(@{

        # ── Workflow control ──────────────────────────────
        IsRunning    = $false
        IsDone       = $false
        IsAborted    = $false

        # ── Progress ──────────────────────────────────────
        Progress     = 0          # 0–100
        StatusMsg    = "Ready"    # current status message for UI

        # ── Log buffer ────────────────────────────────────
        # Format: "[type]message\n"  types: normal|ok|warn|error|info|step
        LogBuffer    = ""

        # ── Module states ─────────────────────────────────
        # Key: moduleId  Value: pending|running|ok|warn|error|skipped
        ModuleStatus = [hashtable]::Synchronized(@{})

        # ── Module timing ─────────────────────────────────
        # Key: moduleId  Value: "12.3s"
        ModuleTimes  = [hashtable]::Synchronized(@{})

        # ── Consolidated results (set after completion) ───
        Results      = $null   # List[ModuleResult]
        Warnings     = [System.Collections.Generic.List[string]]::new()

        # ── Report paths ──────────────────────────────────
        ReportFolder = ""
        ReportHTML   = ""
        ReportTXT    = ""
        ReportJSON   = ""
        ReportReady  = $false

        # ── Performance snapshot (for UI gauges) ──────────
        CpuLoad      = 0
        RamPct       = 0
        DiskPct      = 0
    })

    return $state
}

# ============================================================
#  STATE ACCESSORS (thread-safe helpers)
# ============================================================
function Set-ModuleStatus {
    param(
        [Parameter(Mandatory)] [hashtable]$State,
        [Parameter(Mandatory)] [string]   $ModuleId,
        [Parameter(Mandatory)] [string]   $Status        # pending|running|ok|warn|error|skipped
    )
    $State.ModuleStatus[$ModuleId] = $Status
}

function Set-ModuleTime {
    param(
        [Parameter(Mandatory)] [hashtable]$State,
        [Parameter(Mandatory)] [string]   $ModuleId,
        [Parameter(Mandatory)] [string]   $TimeString
    )
    $State.ModuleTimes[$ModuleId] = $TimeString
}

function Set-Progress {
    param(
        [Parameter(Mandatory)] [hashtable]$State,
        [Parameter(Mandatory)] [int]      $Value,    # 0-100
        [string]                           $Message  = ""
    )
    $State.Progress  = [Math]::Max(0, [Math]::Min(100, $Value))
    if ($Message) { $State.StatusMsg = $Message }
}

function Add-StateWarning {
    param(
        [Parameter(Mandatory)] [hashtable]$State,
        [Parameter(Mandatory)] [string]   $Warning
    )
    $State.Warnings.Add($Warning)
}

function Push-LogMessage {
    <#
    .SYNOPSIS
        Thread-safe: appends a formatted message to the UI log buffer.
        The UI timer drains this buffer on the main thread.
    #>
    param(
        [Parameter(Mandatory)] [hashtable]$State,
        [Parameter(Mandatory)] [string]   $Message,
        [string] $Type = "normal"   # normal|ok|warn|error|info|step
    )
    $State.LogBuffer += "[$Type]$Message`n"
}

function Complete-AppState {
    param([Parameter(Mandatory)] [hashtable]$State)
    $State.Progress  = 100
    $State.IsDone    = $true
    $State.IsRunning = $false
}

Write-Verbose "[State] State manager loaded."
