<#
.SYNOPSIS
    FixPC Toolkit — Hardware Module: Analyze Phase
    Hardware health evaluation from collected inventory data.
    Scriptblock stored as $Script:Analyze_Hardware.

    Checks (in order):
        1. CPU — load snapshot warning
        2. RAM usage — high usage warning
        3. Logical disks — low space per drive (all fixed disks)
        4. Physical disks — SMART health (Unhealthy / Warning)
        5. Hardware info completeness — flags if critical WMI data is missing
        6. Overall — healthy summary if no issues found

    Thresholds:
        Disk used: > 90% = critical | > 80% = error | > 70% = warn
        Disk free: < 5 GB absolute = at least warn regardless of percentage
        RAM used:  > 90% = error   | > 80% = warn
        CPU load:  > 85% = warn    (snapshot only — not a sustained measure)

    Severity string model: "ok" | "info" | "warn" | "error" | "critical"

.VERSION 1.0
#>

$Script:Analyze_Hardware = {
    param($Result, $State)

    $d = $Result.Data

    # ============================================================
    #  CPU LOAD SNAPSHOT
    # ============================================================
    $cpuLoad = $d["CpuLoadPct"]
    $cpuName = $d["CpuName"]

    if (-not $cpuName) {
        $Result.Findings.Add((New-Finding -Title "CPU Information Unavailable" -Severity "warn" `
            -Description "Could not retrieve CPU information via WMI. Check system drivers."))
        $Result.Warnings.Add("CPU WMI data unavailable.")
        Push-LogMessage -State $State -Message "  WARN: CPU WMI data unavailable." -Type "warn"
    } elseif ($cpuLoad -gt 85) {
        $Result.Findings.Add((New-Finding -Title "High CPU Load" -Severity "warn" `
            -Description "CPU load snapshot: $cpuLoad% ($cpuName). Sustained high CPU usage impacts system responsiveness."))
        $Result.Recommendations.Add("Check Task Manager > Processes (sorted by CPU) to identify high-load processes.")
        Push-LogMessage -State $State -Message "  WARN: CPU load $cpuLoad% — $cpuName" -Type "warn"
    } else {
        $coresStr = "$($d['CpuCores'])C / $($d['CpuLogical'])T @ $([math]::Round($d['CpuMaxMHz']/1000,2)) GHz"
        Push-LogMessage -State $State -Message "  CPU: $cpuName  [$coresStr]  Load: $cpuLoad%" -Type "ok"
    }

    # ============================================================
    #  RAM USAGE
    # ============================================================
    $ramPct   = $d["RamUsedPct"]
    $ramTotal = $d["RamTotalMB"]

    if ($ramTotal -eq 0) {
        $Result.Findings.Add((New-Finding -Title "RAM Usage Data Unavailable" -Severity "warn" `
            -Description "Could not retrieve memory usage from Win32_OperatingSystem."))
        Push-LogMessage -State $State -Message "  WARN: RAM usage data unavailable." -Type "warn"
    } elseif ($ramPct -gt 90) {
        $Result.Findings.Add((New-Finding -Title "Critical RAM Usage" -Severity "error" `
            -Description "RAM usage is at $ramPct% ($($d['RamUsedMB']) MB used of $($d['RamTotalMB']) MB total). System may be severely paging to disk."))
        $Result.Warnings.Add("RAM usage at $ramPct% — system may be swapping heavily to disk.")
        $Result.Recommendations.Add("Close unused applications. Consider upgrading RAM if this is sustained.")
        Push-LogMessage -State $State -Message "  ERROR: RAM $ramPct% used — $($d['RamUsedMB']) / $($d['RamTotalMB']) MB" -Type "error"
    } elseif ($ramPct -gt 80) {
        $Result.Findings.Add((New-Finding -Title "High RAM Usage" -Severity "warn" `
            -Description "RAM usage is at $ramPct% ($($d['RamUsedMB']) MB used of $($d['RamTotalMB']) MB total). Consider closing unused applications."))
        $Result.Recommendations.Add("Close unused background applications to free memory.")
        Push-LogMessage -State $State -Message "  WARN: RAM $ramPct% used — $($d['RamUsedMB']) / $($d['RamTotalMB']) MB" -Type "warn"
    } else {
        $stickStr = if ($d["MemStickCount"] -gt 0) { " ($($d['MemStickCount']) stick(s))" } else { "" }
        Push-LogMessage -State $State -Message "  RAM: $ramPct% used  |  $($d['RamUsedMB']) / $($d['RamTotalMB']) MB$stickStr" -Type "ok"
    }

    # ============================================================
    #  LOGICAL DISK SPACE  (each drive independently)
    # ============================================================
    $logDisks = $d["LogicalDisks"]

    if (-not $logDisks) {
        $Result.Findings.Add((New-Finding -Title "Disk Inventory Unavailable" -Severity "warn" `
            -Description "Could not retrieve logical disk information via WMI."))
        Push-LogMessage -State $State -Message "  WARN: Disk inventory unavailable." -Type "warn"
    } else {
        foreach ($disk in $logDisks) {
            if ($disk.Size -le 0) { continue }

            $drive   = $disk.DeviceID
            $totalGB = [math]::Round($disk.Size / 1GB, 1)
            $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 1)
            $usedPct = [math]::Round(($disk.Size - $disk.FreeSpace) / $disk.Size * 100, 1)
            $label   = if ($disk.VolumeName) { " ($($disk.VolumeName))" } else { "" }

            if ($usedPct -gt 90 -or $freeGB -lt 3) {
                $sev = "critical"
                $Result.Findings.Add((New-Finding -Title "Critical: Drive $drive$label Almost Full" -Severity $sev `
                    -Description "$drive is $usedPct% used — only $freeGB GB free of $totalGB GB. System stability is at risk."))
                $Result.Warnings.Add("Drive $drive is $usedPct% full ($freeGB GB free) — critical space shortage.")
                $Result.Recommendations.Add("Immediately free space on $drive: run Temp Cleanup, empty Recycle Bin, or extend the volume.")
                Push-LogMessage -State $State -Message "  CRITICAL: $drive$label $usedPct% full — $freeGB GB free" -Type "error"
            } elseif ($usedPct -gt 80 -or $freeGB -lt 8) {
                $Result.Findings.Add((New-Finding -Title "Low Disk Space on $drive$label" -Severity "error" `
                    -Description "$drive is $usedPct% used — $freeGB GB free of $totalGB GB."))
                $Result.Warnings.Add("Drive $drive is $usedPct% full ($freeGB GB free).")
                $Result.Recommendations.Add("Free space on $drive: clean temp files, empty Recycle Bin, or move data.")
                Push-LogMessage -State $State -Message "  ERROR: $drive$label $usedPct% used — $freeGB GB free" -Type "error"
            } elseif ($usedPct -gt 70 -or $freeGB -lt 15) {
                $Result.Findings.Add((New-Finding -Title "Disk Space Warning on $drive$label" -Severity "warn" `
                    -Description "$drive is $usedPct% used — $freeGB GB free of $totalGB GB."))
                $Result.Recommendations.Add("Monitor disk space on $drive and consider cleanup soon.")
                Push-LogMessage -State $State -Message "  WARN: $drive$label $usedPct% used — $freeGB GB free" -Type "warn"
            } else {
                Push-LogMessage -State $State -Message "  Disk $drive$label: $usedPct% used — $freeGB GB free of $totalGB GB" -Type "ok"
            }
        }
    }

    # ============================================================
    #  PHYSICAL DISK SMART HEALTH
    # ============================================================
    $physDisks = $d["PhysicalDisks"]

    if ($physDisks) {
        foreach ($pd in $physDisks) {
            $sz    = if ($pd.Size -gt 0) { [math]::Round($pd.Size / 1GB, 1) } else { "?" }
            $label = "$($pd.FriendlyName) [$($pd.MediaType) $sz GB]"

            switch ($pd.HealthStatus) {
                "Healthy" {
                    Push-LogMessage -State $State -Message "  SMART: $label — Healthy" -Type "ok"
                }
                "Warning" {
                    $Result.Findings.Add((New-Finding -Title "SMART Warning: $($pd.FriendlyName)" -Severity "warn" `
                        -Description "Physical drive $label reports WARNING health status. Back up data and monitor closely."))
                    $Result.Warnings.Add("Drive '$($pd.FriendlyName)' is reporting WARNING SMART status.")
                    $Result.Recommendations.Add("Back up all data from '$($pd.FriendlyName)' immediately. Plan for replacement.")
                    Push-LogMessage -State $State -Message "  WARN: SMART $label — WARNING" -Type "warn"
                }
                "Unhealthy" {
                    $Result.Findings.Add((New-Finding -Title "SMART FAILURE: $($pd.FriendlyName)" -Severity "critical" `
                        -Description "Physical drive $label reports UNHEALTHY status. Imminent failure risk — back up immediately!"))
                    $Result.Warnings.Add("DRIVE FAILURE RISK: '$($pd.FriendlyName)' is UNHEALTHY. Back up now!")
                    $Result.Recommendations.Add("URGENT: Back up all data from '$($pd.FriendlyName)' immediately and replace the drive.")
                    Push-LogMessage -State $State -Message "  CRITICAL: SMART $label — UNHEALTHY" -Type "error"
                }
                default {
                    Push-LogMessage -State $State -Message "  SMART: $label — $($pd.HealthStatus)" -Type "info"
                }
            }
        }
    } else {
        Push-LogMessage -State $State -Message "  SMART: Physical disk data not available via Storage module." -Type "info"
    }

    # ============================================================
    #  HARDWARE INFO COMPLETENESS
    # ============================================================
    $missingItems = @()
    if (-not $d["MBManufacturer"]) { $missingItems += "Motherboard" }
    if (-not $d["BIOSVersion"])    { $missingItems += "BIOS"         }
    if ($missingItems.Count -gt 0) {
        Push-LogMessage -State $State -Message "  INFO: Some hardware info unavailable ($($missingItems -join ', '))." -Type "info"
    } else {
        Push-LogMessage -State $State -Message "  MB: $($d['MBManufacturer']) $($d['MBProduct'])  |  BIOS: $($d['BIOSVendor']) $($d['BIOSVersion'])" -Type "ok"
    }

    # ============================================================
    #  OVERALL HEALTHY SUMMARY
    # ============================================================
    if ($Result.Findings.Count -eq 0) {
        $summary = "CPU, RAM, and all disks are within healthy parameters."
        if ($d["CpuName"])    { $summary += " CPU: $($d['CpuName'])." }
        if ($d["RamTotalMB"]) { $summary += " RAM: $($d['RamTotalMB']) MB total, $($d['RamUsedPct'])% used." }
        $Result.Findings.Add((New-Finding -Title "Hardware Healthy" -Severity "ok" -Description $summary))
        Push-LogMessage -State $State -Message "  Hardware: all checks passed." -Type "ok"
    }
}
