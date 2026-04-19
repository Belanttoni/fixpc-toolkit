<#
.SYNOPSIS
    FixPC Toolkit — Core Utilities
    Common helper functions used across all layers.
    No UI, no business logic, no module logic — pure utilities.

.VERSION 1.0
#>

# ============================================================
#  TIMING
# ============================================================
function New-Stopwatch {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    return $sw
}

function Get-ElapsedSeconds {
    param([System.Diagnostics.Stopwatch]$Stopwatch)
    $Stopwatch.Stop()
    return [math]::Round($Stopwatch.Elapsed.TotalSeconds, 1)
}

function Format-Duration {
    param([double]$Seconds)
    if ($Seconds -lt 60) { return "${Seconds}s" }
    $m = [math]::Floor($Seconds / 60)
    $s = [math]::Round($Seconds % 60, 0)
    return "${m}m ${s}s"
}

# ============================================================
#  SIZE FORMATTING
# ============================================================
function Format-ByteSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "$([math]::Round($Bytes/1GB, 2)) GB" }
    if ($Bytes -ge 1MB) { return "$([math]::Round($Bytes/1MB, 1)) MB" }
    if ($Bytes -ge 1KB) { return "$([math]::Round($Bytes/1KB, 1)) KB" }
    return "$Bytes B"
}

function Get-FreedMB {
    param([long]$BytesBefore, [long]$BytesAfter)
    return [math]::Round(($BytesBefore - $BytesAfter) / 1MB, 1)
}

# ============================================================
#  STRING HELPERS
# ============================================================
function Truncate-String {
    param([string]$Text, [int]$MaxLength = 120, [string]$Suffix = "...")
    if ($Text.Length -le $MaxLength) { return $Text }
    return $Text.Substring(0, $MaxLength - $Suffix.Length) + $Suffix
}

function Strip-HtmlTags {
    param([string]$Text)
    return $Text -replace '<[^>]+>', ''
}

function Escape-Html {
    param([string]$Text)
    return $Text `
        -replace '&', '&amp;' `
        -replace '<', '&lt;'  `
        -replace '>', '&gt;'  `
        -replace '"', '&quot;'
}

function Format-Timestamp {
    param([datetime]$Date = (Get-Date), [string]$Format = "MM/dd/yyyy HH:mm:ss")
    return $Date.ToString($Format)
}

# NOTE: Severity helpers (Get-HighestSeverity, Convert-SeverityToHtmlClass,
#       Convert-SeverityToUiStatus, Compare-Severity) are defined in Core/Contracts.ps1
#       which must be loaded first.

# ============================================================
#  DISK HELPERS
# ============================================================
function Get-FolderSizeBytes {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0L }
    try {
        return (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
    } catch { return 0L }
}

function Remove-FolderContents {
    <#
    .SYNOPSIS
        Safely removes the contents of a folder (not the folder itself).
        Returns bytes freed.
    #>
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0L }
    $before = Get-FolderSizeBytes $Path
    try {
        Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } catch { }
    $after = Get-FolderSizeBytes $Path
    return ($before - $after)
}

# ============================================================
#  SYMBOL CONSTANTS (encoding-safe via [char])
# ============================================================
$Script:Sym = @{
    Check = [char]0x2714   # ✔
    Warn  = [char]0x26A0   # ⚠
    Cross = [char]0x2716   # ✖
    Dot   = [char]0x25CF   # ●
    Dash  = [char]0x2014   # —
    Arrow = ">"
}

function Get-Symbol { param([string]$Name) return $Script:Sym[$Name] }

Write-Verbose "[Utilities] Utilities loaded."
