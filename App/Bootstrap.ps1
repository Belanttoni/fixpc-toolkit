<#
.SYNOPSIS
    FixPC Toolkit — Application Bootstrap
    Initializes all services in the correct order.
    This is the ONLY file that loads Core services — all other layers import via Bootstrap.

.VERSION 1.0
#>

function Initialize-FixPCToolkit {
    <#
    .SYNOPSIS
        Bootstraps the full application:
        1. Validates prerequisites
        2. Creates execution context
        3. Creates shared state
        4. Initializes logger
        5. Returns ready-to-use context + state

    .PARAMETER Mode
        ExecutionMode enum value.

    .PARAMETER ModuleIds
        Array of module IDs to run. Empty = run all.

    .PARAMETER SyncBuffer
        The synchronized hashtable (State) that the logger should write UI messages to.
        Pass the State object returned by New-AppState.
    #>
    param(
        [ExecutionMode] $Mode      = [ExecutionMode]::DiagnoseOnly,
        [string[]]      $ModuleIds = @(),
        [hashtable]     $SyncBuffer = $null
    )

    # 1. Prerequisite: must be Administrator
    Assert-IsAdministrator

    # 2. Create execution context
    $ctx = New-ExecutionContext -Mode $Mode -Modules $ModuleIds

    # 3. Ensure report folder exists
    Ensure-DirectoryExists -Path $ctx.ReportFolder

    # 4. Initialize logger (writes to report folder)
    Initialize-Logger `
        -LogFolder  $ctx.ReportFolder `
        -MinLevel   ([LogLevel]::Info) `
        -SyncBuffer $SyncBuffer

    Write-LogInfo -Source "Bootstrap" -Message "FixPC Toolkit starting."
    Write-LogInfo -Source "Bootstrap" -Message "Session: $($ctx.SessionId) | Mode: $($ctx.Mode) | Computer: $($ctx.Computer)"
    Write-LogInfo -Source "Bootstrap" -Message "Report folder: $($ctx.ReportFolder)"

    if ($ModuleIds.Count -eq 0) {
        Write-LogInfo -Source "Bootstrap" -Message "No specific modules requested — all modules will run."
    } else {
        Write-LogInfo -Source "Bootstrap" -Message "Modules requested: $($ModuleIds -join ', ')"
    }

    return $ctx
}

function Get-AllModuleDefinitions {
    <#
    .SYNOPSIS
        Returns the ordered list of all module definitions.
        Used by WorkflowCoordinator and UI to build the module list.
    #>
    return @(
        @{ Id = "sysinfo";   Name = "System Information";      Desc = "CPU, RAM, Disk, Uptime";           ScriptPath = "Modules\System\SystemModule.ps1" },
        @{ Id = "sfc";       Name = "SFC /scannow";            Desc = "System file integrity check";       ScriptPath = "Modules\System\SystemModule.ps1" },
        @{ Id = "dism";      Name = "DISM RestoreHealth";      Desc = "Windows image repair";              ScriptPath = "Modules\System\SystemModule.ps1" },
        @{ Id = "chkdsk";    Name = "CHKDSK /scan+/spotfix";  Desc = "Disk error scan (no reboot)";       ScriptPath = "Modules\System\SystemModule.ps1" },
        @{ Id = "temp";      Name = "Clear Temp Files";        Desc = "Free disk space";                   ScriptPath = "Modules\System\SystemModule.ps1" },
        @{ Id = "events";    Name = "Event Viewer";            Desc = "Critical errors (last 24h)";        ScriptPath = "Modules\System\SystemModule.ps1" },
        @{ Id = "winupdate"; Name = "Windows Update";         Desc = "Detect & install updates";           ScriptPath = "Modules\System\SystemModule.ps1" },
        @{ Id = "startup";   Name = "Startup Programs";        Desc = "Boot impact analysis";              ScriptPath = "Modules\System\SystemModule.ps1" },
        @{ Id = "smart";     Name = "Disk SMART Health";       Desc = "Physical drive health";             ScriptPath = "Modules\System\SystemModule.ps1" },
        @{ Id = "ram";       Name = "RAM Health";              Desc = "Memory diagnostic check";           ScriptPath = "Modules\System\SystemModule.ps1"  },
        @{ Id = "network";   Name = "Network Diagnostics";    Desc = "Connectivity & DNS checks";          ScriptPath = "Modules\Network\NetworkModule.ps1" },
        @{ Id = "hardware";  Name = "Hardware Diagnostics";   Desc = "CPU, RAM, disk & SMART health";       ScriptPath = "Modules\Hardware\HardwareModule.ps1" }
    )
}

Write-Verbose "[Bootstrap] Bootstrap service loaded."
