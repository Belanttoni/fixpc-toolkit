<#
.SYNOPSIS
    FixPC Toolkit — Core Logging Service
    Centralized, thread-safe logging for all layers.
    Supports file output, UI sync buffer, and severity filtering.

.VERSION 1.0
#>

# ============================================================
#  LOG STATE (module-scoped, initialized via Initialize-Logger)
# ============================================================
$Script:LogState = $null

# ============================================================
#  INITIALIZE LOGGER
# ============================================================
function Initialize-Logger {
    <#
    .SYNOPSIS
        Must be called once at application startup.
        Sets up the log file, minimum level, and shared sync buffer.
    #>
    param(
        [Parameter(Mandatory)] [string]    $LogFolder,
        [LogLevel]                          $MinLevel  = [LogLevel]::Info,
        [hashtable]                         $SyncBuffer = $null   # shared hashtable for UI thread
    )

    if (-not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    }

    $logFile = Join-Path $LogFolder "FixPC_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

    $Script:LogState = @{
        LogFile    = $logFile
        MinLevel   = $MinLevel
        SyncBuffer = $SyncBuffer
        Entries    = [System.Collections.Generic.List[PSCustomObject]]::new()
        Lock       = [System.Object]::new()
    }

    Write-LogEntry -Level Info -Source "Logger" -Message "Logger initialized. File: $logFile | MinLevel: $MinLevel"
}

# ============================================================
#  CORE WRITE FUNCTION
# ============================================================
function Write-LogEntry {
    <#
    .SYNOPSIS
        Primary logging function. Thread-safe.
        Writes to: in-memory list, log file, and UI sync buffer (if configured).
    #>
    param(
        [Parameter(Mandatory)] [LogLevel]$Level,
        [Parameter(Mandatory)] [string]  $Source,
        [Parameter(Mandatory)] [string]  $Message,
        [object]                          $Data    = $null
    )

    if ($null -eq $Script:LogState) { return }
    if ($Level -lt $Script:LogState.MinLevel) { return }

    $entry = New-LogEntry -Level $Level -Source $Source -Message $Message -Data $Data
    $ts    = $entry.Timestamp.ToString("HH:mm:ss.fff")
    $lvl   = $Level.ToString().ToUpper().PadRight(8)
    $line  = "[$ts] [$lvl] [$Source] $Message"

    [System.Threading.Monitor]::Enter($Script:LogState.Lock)
    try {
        # In-memory
        $Script:LogState.Entries.Add($entry)

        # File
        Add-Content -Path $Script:LogState.LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue

        # UI sync buffer — only Warnings and Errors; routine Info stays in the log file.
        # Intentional UI messages use Push-LogMessage directly (State.LogBuffer).
        # Phase step markers are pushed by Write-LogStep via its own direct push.
        if ($null -ne $Script:LogState.SyncBuffer) {
            $uiType = switch ($Level) {
                ([LogLevel]::Warning)  { "warn"  }
                ([LogLevel]::Error)    { "error" }
                ([LogLevel]::Critical) { "error" }
                default                { $null   }   # Info/Debug: file only
            }
            if ($null -ne $uiType) {
                $Script:LogState.SyncBuffer.LogBuffer += "[$uiType]$Message`n"
            }
        }
    } finally {
        [System.Threading.Monitor]::Exit($Script:LogState.Lock)
    }
}

# ============================================================
#  CONVENIENCE WRAPPERS
# ============================================================
function Write-LogDebug    { param([string]$Source, [string]$Message, [object]$Data=$null) Write-LogEntry -Level Debug    -Source $Source -Message $Message -Data $Data }
function Write-LogInfo     { param([string]$Source, [string]$Message, [object]$Data=$null) Write-LogEntry -Level Info     -Source $Source -Message $Message -Data $Data }
function Write-LogWarning  { param([string]$Source, [string]$Message, [object]$Data=$null) Write-LogEntry -Level Warning  -Source $Source -Message $Message -Data $Data }
function Write-LogError    { param([string]$Source, [string]$Message, [object]$Data=$null) Write-LogEntry -Level Error    -Source $Source -Message $Message -Data $Data }
function Write-LogCritical { param([string]$Source, [string]$Message, [object]$Data=$null) Write-LogEntry -Level Critical -Source $Source -Message $Message -Data $Data }

# ============================================================
#  STEP LOGGER — marks beginning of a named phase
# ============================================================
function Write-LogStep {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$StepName,
        [int] $StepNumber  = 0,
        [int] $TotalSteps  = 0
    )

    $numStr = if ($StepNumber -gt 0) { "[$StepNumber/$TotalSteps] " } else { "" }
    Write-LogEntry -Level Info -Source $Source -Message "$numStr=== $StepName ==="

    if ($null -ne $Script:LogState.SyncBuffer) {
        $Script:LogState.SyncBuffer.LogBuffer += "[step]$numStr$StepName`n"
    }
}

# ============================================================
#  GET LOG ENTRIES — for report export
# ============================================================
function Get-LogEntries {
    param(
        [LogLevel] $MinLevel  = [LogLevel]::Info,
        [string]   $Source    = ""
    )

    if ($null -eq $Script:LogState) { return @() }

    $entries = $Script:LogState.Entries | Where-Object { $_.Level -ge $MinLevel }
    if ($Source) { $entries = $entries | Where-Object { $_.Source -eq $Source } }
    return $entries
}

function Get-LogFilePath {
    if ($null -eq $Script:LogState) { return "" }
    return $Script:LogState.LogFile
}

function Get-LogEntriesAsText {
    param([LogLevel]$MinLevel = [LogLevel]::Info)

    return (Get-LogEntries -MinLevel $MinLevel | ForEach-Object {
        $ts  = $_.Timestamp.ToString("HH:mm:ss")
        $lvl = $_.Level.ToString().PadRight(8)
        "[$ts] [$lvl] [$($_.Source)] $($_.Message)"
    }) -join "`n"
}

Write-Verbose "[Logging] Logging service loaded."
