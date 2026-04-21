<#
.SYNOPSIS
    FixPC Toolkit — System Module: Export Phase
    Export scriptblocks for all System module sub-modules.
    Scriptblocks are stored as Script-scope variables and consumed by SystemModule.ps1.

    Naming convention: $Script:Export_<SubModuleId>

.VERSION 1.0
#>

# ============================================================
#  EXPORT — sysinfo
# ============================================================
$Script:Export_SysInfo = {
    param($Result, $State)
    $d = $Result.Data
    $ramClass    = if ($d['RamPct']  -gt 85) { "warn" } else { "ok" }
    $diskClass   = if ($d['DiskPct'] -gt 85) { "warn" } else { "ok" }
    $uptimeStatus = if ($d['UptimeDays'] -gt 7) { "warn" } else { "-" }

    $Result.ExportData["rows"] = @(
        @{ Label="OS";      Value="$($d['OS']) Build $($d['Build'])";              Status="-"                         },
        @{ Label="CPU";     Value=$d['CPU'];                                        Status="Load: $($d['CpuLoad'])%"   },
        @{ Label="RAM";     Value="$($d['RamUsed']) GB / $($d['RamTotal']) GB";    Status="$($d['RamPct'])%";    CssClass=$ramClass  },
        @{ Label="Disk C:"; Value="$($d['DiskFree']) GB free / $($d['DiskTotal']) GB"; Status="$($d['DiskPct'])% used"; CssClass=$diskClass },
        @{ Label="Uptime";  Value=$d['UptimeStr'];                                 Status=$uptimeStatus               },
        @{ Label="BIOS";    Value=$d['BIOS'];                                       Status="-"                         }
    )
}

# ============================================================
#  EXPORT — sfc
# ============================================================
$Script:Export_SFC = {
    param($Result, $State)
    $f = if ($Result.Findings.Count -gt 0) { $Result.Findings[0] } else { $null }
    $Result.ExportData["summary"]    = if ($f) { $f.Description } else { "No findings recorded." }
    $Result.ExportData["repaired"]   = if ($f) { $f.Repaired    } else { $false }
    $Result.ExportData["logFile"]    = $Result.Data["LogFile"]
    # Include note if scannow ran (repair mode)
    $Result.ExportData["repairNote"] = if ($Result.Data["ScanOutput"] -ne "") {
        "sfc /scannow was executed."
    } else {
        "sfc /verifyonly only (DiagnoseOnly mode — no repair performed)."
    }
}

# ============================================================
#  EXPORT — dism
# ============================================================
$Script:Export_DISM = {
    param($Result, $State)
    $f = if ($Result.Findings.Count -gt 0) { $Result.Findings[0] } else { $null }
    $Result.ExportData["summary"]  = if ($f) { $f.Description } else { "No findings recorded." }
    $Result.ExportData["repaired"] = if ($f) { $f.Repaired    } else { $false }
    $Result.ExportData["logFile"]  = $Result.Data["LogFile"]
    # Indicate which DISM action was performed (if any)
    $Result.ExportData["repairNote"] = if ($Result.Data["RestoreOutput"] -ne "") {
        "DISM /RestoreHealth was executed (FullRepair)."
    } elseif ($Result.Data["ScanOutput"] -ne "") {
        "DISM /ScanHealth was executed (SafeRepair)."
    } else {
        "DISM /CheckHealth only (DiagnoseOnly mode — no deeper action performed)."
    }
}

# ============================================================
#  EXPORT — chkdsk
# ============================================================
$Script:Export_ChkDsk = {
    param($Result, $State)
    $f = if ($Result.Findings.Count -gt 0) { $Result.Findings[0] } else { $null }
    $Result.ExportData["summary"]    = if ($f) { $f.Description } else { "No findings recorded." }
    $Result.ExportData["repaired"]   = if ($f) { $f.Repaired    } else { $false }
    $Result.ExportData["method"]     = "chkdsk /scan (online) + /spotfix if needed — no reboot required"
    $Result.ExportData["scanOutput"] = $Result.Data["ScanOutput"]
}

# ============================================================
#  EXPORT — temp
# ============================================================
$Script:Export_Temp = {
    param($Result, $State)
    $freedBytes    = $Result.Data["FreedBytes"]
    # Pre-compute to avoid placing an `if` statement inside a method-call argument
    # (statement-in-expression is a PS5.1 syntax error when used bare inside parentheses).
    $freedBytesVal = if ($null -ne $freedBytes) { [long]$freedBytes } else { 0L }
    $freedMB       = [math]::Round($freedBytesVal / 1MB, 1)
    $Result.ExportData["totalFreedMB"] = $freedMB
    $Result.ExportData["summary"]      = "Total space freed: $freedMB MB"
    $inventory = $Result.Data["PathInventory"]
    $Result.ExportData["paths"]        = if ($inventory) { $inventory.Keys } else { @() }
}

# ============================================================
#  EXPORT — events
# ============================================================
$Script:Export_Events = {
    param($Result, $State)
    $events = $Result.Data["Events"]
    $rows   = @()
    if ($events) {
        $rows = $events | Select-Object -First 30 | ForEach-Object {
            $msg = (Strip-HtmlTags ($_.Message -replace "`r`n", " "))
            @{
                Time    = $_.TimeCreated.ToString("MM/dd HH:mm")
                Level   = $_.LevelDisplayName
                Source  = $_.ProviderName
                Id      = $_.Id
                Message = Truncate-String -Text $msg -MaxLength 120
                Class   = if ($_.LevelDisplayName -eq "Critical") {"error"} else {"warn"}
            }
        }
    }
    $Result.ExportData["rows"]  = $rows
    $Result.ExportData["count"] = $Result.Data["Count"]
}

# ============================================================
#  EXPORT — winupdate
# ============================================================
$Script:Export_WinUpdate = {
    param($Result, $State)
    $Result.ExportData["pendingCount"]   = $Result.Data["PendingCount"]
    $Result.ExportData["titles"]         = if ($null -ne $Result.Data["PendingTitles"])  { $Result.Data["PendingTitles"]  } else { @()    }
    $Result.ExportData["rebootRequired"] = if ($null -ne $Result.Data["RebootRequired"]) { $Result.Data["RebootRequired"] } else { $false }

    # Release COM objects unconditionally — covers both DiagnoseOnly (Repair skipped)
    # and SafeRepair/FullRepair (Repair already nulled them, but idempotent).
    $Result.Data["Session"]      = $null
    $Result.Data["SearchResult"] = $null
}

# ============================================================
#  EXPORT — startup
# ============================================================
$Script:Export_Startup = {
    param($Result, $State)
    $Result.ExportData["count"] = $Result.Data["Count"]
    $Result.ExportData["items"] = $Result.Data["Items"] | Select-Object -First 25 | ForEach-Object {
        @{ Name = $_.Name; Command = Truncate-String $_.Command 90; Scope = $_.Scope }
    }
}

# ============================================================
#  EXPORT — smart
# ============================================================
$Script:Export_Smart = {
    param($Result, $State)
    $disks = $Result.Data["Disks"]
    $Result.ExportData["drives"] = if ($disks) {
        $disks | ForEach-Object {
            @{
                Name   = $_.FriendlyName
                Type   = $_.MediaType
                SizeGB = [math]::Round($_.Size / 1GB, 1)
                Health = $_.HealthStatus
                Class  = switch ($_.HealthStatus) {
                    "Healthy"   { "ok"    }
                    "Warning"   { "warn"  }
                    "Unhealthy" { "error" }
                    default     { ""      }
                }
            }
        }
    } else { @() }
}

# ============================================================
#  EXPORT — ram
# ============================================================
$Script:Export_Ram = {
    param($Result, $State)
    $sticks = $Result.Data["Sticks"]
    $Result.ExportData["sticks"] = if ($sticks) {
        $sticks | ForEach-Object {
            @{
                Slot         = $_.DeviceLocator
                SizeGB       = [math]::Round($_.Capacity / 1GB, 1)
                Speed        = if ($_.Speed) { "$($_.Speed) MHz" } else { "N/A" }
                Manufacturer = $_.Manufacturer
            }
        }
    } else { @() }
    $Result.ExportData["errorCount"] = $Result.Data["ErrorCount"]
}

Write-Verbose "[System.Export] Export phase scriptblocks loaded."
