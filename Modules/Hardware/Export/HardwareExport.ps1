<#
.SYNOPSIS
    FixPC Toolkit — Hardware Module: Export Phase
    Structures hardware inventory and health data for reporting.
    Scriptblock stored as $Script:Export_Hardware.

    ExportData keys:
        summary      — first finding description (null-guarded)
        cpu          — ordered hashtable: name, cores, logical, loadPct, maxMHz
        ram          — ordered hashtable: totalGB, usedGB, freeGB, usedPct, stickCount
        disks        — array of logical disk ordered hashtables per drive
        physDisks    — array of SMART status ordered hashtables per physical drive
        bios         — ordered hashtable: vendor, version, date
        mb           — ordered hashtable: manufacturer, product
        gpuName      — string (may be $null)
        battery      — ordered hashtable: present, name, healthPct, chargePct,
                        status, designedMWh, fullMWh, class
        sensors      — array of sensor rows: name, source, value, class
        cpuTempC     — numeric or $null
        cpuTempSource — string description of which sensor was used
        sensorSource — "librehrm" | "openhrm" | "acpi_only" | "none"
        sensorAvailable — bool
        overallClass — "ok" | "warn" | "error" | "critical" — worst finding severity

.VERSION 1.1
#>

$Script:Export_Hardware = {
    param($Result, $State)

    $d = $Result.Data

    # ============================================================
    #  SUMMARY  (null-guarded — Findings may be empty)
    # ============================================================
    $f = if ($Result.Findings.Count -gt 0) { $Result.Findings[0] } else { $null }
    $Result.ExportData["summary"] = if ($f) { $f.Description } else { "No hardware findings recorded." }

    # ============================================================
    #  CPU
    # ============================================================
    $Result.ExportData["cpu"] = [ordered]@{
        name    = if ($d["CpuName"])    { $d["CpuName"]    } else { "Unknown" }
        cores   = if ($d["CpuCores"])   { $d["CpuCores"]   } else { 0 }
        logical = if ($d["CpuLogical"]) { $d["CpuLogical"] } else { 0 }
        loadPct = if ($null -ne $d["CpuLoadPct"]) { $d["CpuLoadPct"] } else { 0 }
        maxMHz  = if ($d["CpuMaxMHz"])  { $d["CpuMaxMHz"]  } else { 0 }
    }

    # ============================================================
    #  RAM
    # ============================================================
    $ramTotalMB = if ($d["RamTotalMB"]) { $d["RamTotalMB"] } else { 0 }
    $ramUsedMB  = if ($d["RamUsedMB"])  { $d["RamUsedMB"]  } else { 0 }
    $ramFreeMB  = if ($d["RamFreeMB"])  { $d["RamFreeMB"]  } else { 0 }

    $Result.ExportData["ram"] = [ordered]@{
        totalGB    = [math]::Round($ramTotalMB / 1024, 2)
        usedGB     = [math]::Round($ramUsedMB  / 1024, 2)
        freeGB     = [math]::Round($ramFreeMB  / 1024, 2)
        usedPct    = if ($null -ne $d["RamUsedPct"]) { $d["RamUsedPct"] } else { 0 }
        stickCount = if ($d["MemStickCount"]) { $d["MemStickCount"] } else { 0 }
    }

    # ============================================================
    #  LOGICAL DISKS
    # ============================================================
    $diskRows = [System.Collections.Generic.List[object]]::new()
    $logDisks = $d["LogicalDisks"]
    if ($logDisks) {
        foreach ($disk in $logDisks) {
            if ($disk.Size -le 0) { continue }
            $totalGB = [math]::Round($disk.Size / 1GB, 1)
            $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 1)
            $usedPct = [math]::Round(($disk.Size - $disk.FreeSpace) / $disk.Size * 100, 1)

            # Classify for colour coding in HTML report
            $class = if ($usedPct -gt 90 -or $freeGB -lt 3)  { "critical" } `
                     elseif ($usedPct -gt 80 -or $freeGB -lt 8)  { "error"    } `
                     elseif ($usedPct -gt 70 -or $freeGB -lt 15) { "warn"     } `
                     else                                          { "ok"       }

            $diskRows.Add([ordered]@{
                drive   = $disk.DeviceID
                label   = if ($disk.VolumeName) { $disk.VolumeName } else { "" }
                totalGB = $totalGB
                freeGB  = $freeGB
                usedPct = $usedPct
                class   = $class
            })
        }
    }
    $Result.ExportData["disks"] = $diskRows.ToArray()

    # ============================================================
    #  PHYSICAL DISKS (SMART)
    # ============================================================
    $physRows = [System.Collections.Generic.List[object]]::new()
    $physDisks = $d["PhysicalDisks"]
    if ($physDisks) {
        foreach ($pd in $physDisks) {
            $sizeGB = if ($pd.Size -gt 0) { [math]::Round($pd.Size / 1GB, 1) } else { 0 }
            $health = if ($pd.HealthStatus) { $pd.HealthStatus } else { "Unknown" }
            $class  = switch ($health) {
                "Healthy"   { "ok"       }
                "Warning"   { "warn"     }
                "Unhealthy" { "critical" }
                default     { "info"     }
            }
            $physRows.Add([ordered]@{
                name   = if ($pd.FriendlyName) { $pd.FriendlyName } else { "Unknown Drive" }
                type   = if ($pd.MediaType)    { $pd.MediaType    } else { "Unknown"        }
                sizeGB = $sizeGB
                health = $health
                class  = $class
            })
        }
    }
    $Result.ExportData["physDisks"] = $physRows.ToArray()

    # ============================================================
    #  BIOS
    # ============================================================
    $Result.ExportData["bios"] = [ordered]@{
        vendor  = if ($d["BIOSVendor"])  { $d["BIOSVendor"]  } else { "Unknown" }
        version = if ($d["BIOSVersion"]) { $d["BIOSVersion"] } else { "Unknown" }
        date    = if ($d["BIOSDate"])    { $d["BIOSDate"]    } else { "Unknown" }
    }

    # ============================================================
    #  MOTHERBOARD
    # ============================================================
    $Result.ExportData["mb"] = [ordered]@{
        manufacturer = if ($d["MBManufacturer"]) { $d["MBManufacturer"] } else { "Unknown" }
        product      = if ($d["MBProduct"])      { $d["MBProduct"]      } else { "Unknown" }
    }

    # ============================================================
    #  GPU
    # ============================================================
    $Result.ExportData["gpuName"] = if ($d["GPUName"]) { $d["GPUName"] } else { $null }

    # ============================================================
    #  BATTERY
    # ============================================================
    $batHealthPct = $d["BatteryHealthPct"]
    $batClass     = if ($null -ne $batHealthPct) {
        if     ($batHealthPct -lt 60) { "error" }
        elseif ($batHealthPct -lt 80) { "warn"  }
        else                           { "ok"    }
    } else { "info" }

    # Human-readable health classification (used by HTML for clear labelling)
    $batHealthLabel = if ($null -eq $batHealthPct) { "Unknown" }
                      elseif ($batHealthPct -ge 80) { "Healthy"  }
                      elseif ($batHealthPct -ge 60) { "Degraded" }
                      else                           { "Poor"     }

    $Result.ExportData["battery"] = [ordered]@{
        present      = if ($d["BatteryPresent"])     { $true  } else { $false }
        name         = if ($d["BatteryName"])         { $d["BatteryName"]         } else { $null }
        healthPct    = $batHealthPct
        healthLabel  = $batHealthLabel
        chargePct    = $d["BatteryChargePct"]
        status       = if ($d["BatteryStatus"])       { $d["BatteryStatus"]       } else { $null }
        designedMWh  = if ($d["BatteryDesignedMWh"])  { $d["BatteryDesignedMWh"]  } else { $null }
        fullMWh      = if ($d["BatteryFullMWh"])      { $d["BatteryFullMWh"]      } else { $null }
        class        = $batClass
    }

    # ============================================================
    #  SENSOR READINGS  (temperatures + fan speeds)
    #  Consumed by HTML/TXT/JSON reports.
    #  Rows are ordered: OHM/LHM temps first, then ACPI, then drives, then fans.
    # ============================================================
    $sensorRows = [System.Collections.Generic.List[object]]::new()

    $ohmTemps    = $d["OhmTemps"]
    $acpiTemps   = $d["AcpiTemps"]
    $driveTemps  = $d["DriveTemps"]
    $ohmFans     = $d["OhmFans"]
    $ohmNs       = $d["OhmNamespace"]
    $ohmSrcLabel = if ($ohmNs) { $ohmNs.Split('\')[-1] } else { "" }

    # OHM/LHM temperature sensors
    if ($ohmTemps -and $ohmTemps.Count -gt 0) {
        foreach ($s in $ohmTemps) {
            $tc    = $s["TempC"]
            $class = if ($tc -ge 85) { "error" } elseif ($tc -ge 75) { "warn" } else { "ok" }
            $hwCtx = if ($s["HardwareName"]) { " ($($s['HardwareName']))" } else { "" }
            $sensorRows.Add([ordered]@{
                name   = "$($s['Name'])$hwCtx"
                source = $ohmSrcLabel
                value  = "${tc} °C"
                class  = $class
            })
        }
    } elseif ($acpiTemps -and $acpiTemps.Count -gt 0) {
        # Fall back to ACPI zones only when OHM/LHM data is unavailable
        foreach ($a in $acpiTemps) {
            $tc    = $a["TempC"]
            $class = if ($tc -ge 85) { "error" } elseif ($tc -ge 75) { "warn" } else { "ok" }
            $sensorRows.Add([ordered]@{
                name   = $a["Name"]
                source = "ACPI"
                value  = "${tc} °C"
                class  = $class
            })
        }
    }

    # Drive temperatures
    if ($driveTemps -and $driveTemps.Count -gt 0) {
        foreach ($dt in $driveTemps) {
            if ($null -eq $dt["TempC"]) { continue }
            $tc    = $dt["TempC"]
            $class = if ($tc -ge 70) { "error" } elseif ($tc -ge 60) { "warn" } else { "ok" }
            $sensorRows.Add([ordered]@{
                name   = "$($dt['Name']) Temperature"
                source = "Storage"
                value  = "${tc} °C"
                class  = $class
            })
        }
    }

    # Fan speeds (OHM/LHM only)
    if ($ohmFans -and $ohmFans.Count -gt 0) {
        foreach ($fan in $ohmFans) {
            $rpm   = $fan["RPM"]
            $class = if ($rpm -gt 0 -and $rpm -lt 200) { "warn" } else { "ok" }
            $hwCtx = if ($fan["HardwareName"]) { " ($($fan['HardwareName']))" } else { "" }
            $sensorRows.Add([ordered]@{
                name   = "$($fan['Name'])$hwCtx"
                source = "Fan"
                value  = "${rpm} RPM"
                class  = $class
            })
        }
    }

    $Result.ExportData["sensors"]          = $sensorRows.ToArray()
    $Result.ExportData["cpuTempC"]         = $d["CpuTempC"]
    $Result.ExportData["cpuTempSource"]    = $d["CpuTempSource"]
    $Result.ExportData["cpuTempAvailable"] = $null -ne $d["CpuTempC"]
    $Result.ExportData["sensorSource"]     = $d["SensorSource"]
    $Result.ExportData["sensorAvailable"]  = $d["SensorAvailable"]
    # Monitor-running flags — used by HTML to choose between "install LHM" and "run as admin"
    $Result.ExportData["lhmRunning"]       = [bool]$d["LhmRunning"]
    $Result.ExportData["ohmRunning"]       = [bool]$d["OhmRunning"]
    # PawnIO / CPU-temp-unavailable context for HTML rendering
    $Result.ExportData["pawnIODetected"]           = [bool]$d["PawnIODetected"]
    $Result.ExportData["cpuTempUnavailableReason"] = $d["CpuTempUnavailableReason"]
    $Result.ExportData["pawnIOInstallAttempted"]   = [bool]$d["PawnIOInstallAttempted"]
    $Result.ExportData["pawnIOInstallResult"]      = $d["PawnIOInstallResult"]

    # ============================================================
    #  OVERALL CLASS  (worst severity across all findings)
    #  Uses Get-HighestSeverity from Core/Contracts.ps1 — do not duplicate.
    # ============================================================
    $Result.ExportData["overallClass"] = Get-HighestSeverity -Findings $Result.Findings
}
