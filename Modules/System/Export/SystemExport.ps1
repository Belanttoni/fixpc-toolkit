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
    $Result.ExportData["rows"] = @(
        @{ Item="OS";      Value="$($d['OS']) Build $($d['Build'])";                                      Status="-"                                                                                          },
        @{ Item="CPU";     Value=$d['CPU'];                                                                Status="Load: $($d['CpuLoad'])%"                                                                   },
        @{ Item="RAM";     Value="$($d['RamUsed']) GB / $($d['RamTotal']) GB";                            Status="$($d['RamPct'])%"; CssClass=$(if($d['RamPct'] -gt 85){"warn"}else{"ok"})                    },
        @{ Item="Disk C:"; Value="$($d['DiskFree']) GB free / $($d['DiskTotal']) GB";                     Status="$($d['DiskPct'])% used"; CssClass=$(if($d['DiskPct'] -gt 85){"warn"}else{"ok"})             },
        @{ Item="Uptime";  Value=$d['UptimeStr'];                                                          Status=$(if($d['UptimeDays'] -gt 7){"warn"}else{"-"})                                              },
        @{ Item="BIOS";    Value=$d['BIOS'];                                                               Status="-"                                                                                          }
    )
}

# ============================================================
#  EXPORT — sfc
# ============================================================
$Script:Export_SFC = {
    param($Result, $State)
    $f = $Result.Findings[0]
    $Result.ExportData["summary"]    = $f.Description
    $Result.ExportData["repaired"]   = $f.Repaired
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
    $f = $Result.Findings[0]
    $Result.ExportData["summary"]  = $f.Description
    $Result.ExportData["repaired"] = $f.Repaired
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
    $Result.ExportData["summary"]    = $Result.Findings[0].Description
    $Result.ExportData["repaired"]   = $Result.Findings[0].Repaired
    $Result.ExportData["method"]     = "chkdsk /scan (online) + /spotfix if needed — no reboot required"
    $Result.ExportData["scanOutput"] = $Result.Data["ScanOutput"]
}

# ============================================================
#  EXPORT — temp
# ============================================================
$Script:Export_Temp = {
    param($Result, $State)
    $freedMB = [math]::Round(($Result.Data["FreedBytes"] ?? 0) / 1MB, 1)
    $Result.ExportData["totalFreedMB"] = $freedMB
    $Result.ExportData["summary"]      = "Total space freed: $freedMB MB"
    $Result.ExportData["paths"]        = $Result.Data["PathInventory"].Keys
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
    $Result.ExportData["titles"]         = $Result.Data["PendingTitles"] ?? @()
    $Result.ExportData["rebootRequired"] = $Result.Data["RebootRequired"] ?? $false
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
