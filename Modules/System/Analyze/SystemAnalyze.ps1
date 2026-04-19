<#
.SYNOPSIS
    FixPC Toolkit — System Module: Analyze Phase
    All analysis scriptblocks for the System module sub-modules.
    Scriptblocks are stored as Script-scope variables and consumed by SystemModule.ps1.

    Naming convention: $Script:Analyze_<SubModuleId>

    Severity string model (project standard):
        "ok" | "info" | "warn" | "error" | "critical"

.VERSION 1.0
#>

# ============================================================
#  ANALYZE — sysinfo
# ============================================================
$Script:Analyze_SysInfo = {
    param($Result, $State)
    $d = $Result.Data

    if ($d["RamPct"] -gt 85) {
        $Result.Findings.Add((New-Finding -Title "High RAM Usage" -Severity "warn" `
            -Description "$($d['RamPct'])% RAM in use ($($d['RamUsed']) GB / $($d['RamTotal']) GB)"))
        $Result.Recommendations.Add("Close unused applications or consider adding more RAM.")
    }
    if ($d["DiskPct"] -gt 85) {
        $Result.Findings.Add((New-Finding -Title "Low Disk Space" -Severity "error" `
            -Description "C: drive $($d['DiskPct'])% full. Only $($d['DiskFree']) GB free of $($d['DiskTotal']) GB."))
        $Result.Recommendations.Add("Run Temp Cleanup and review large files on C:.")
    }
    if ($d["UptimeDays"] -gt 7) {
        $Result.Findings.Add((New-Finding -Title "Extended Uptime" -Severity "warn" `
            -Description "System has not been restarted in $($d['UptimeDays']) days."))
        $Result.Recommendations.Add("Reboot the system to apply updates and clear memory leaks.")
    }
    if ($d["CpuLoad"] -gt 80) {
        $Result.Findings.Add((New-Finding -Title "High CPU Load" -Severity "warn" `
            -Description "Current CPU load: $($d['CpuLoad'])%"))
        $Result.Recommendations.Add("Check Task Manager for processes consuming excessive CPU.")
    }
    if ($Result.Findings.Count -eq 0) {
        $Result.Findings.Add((New-Finding -Title "System Resources Healthy" -Severity "info" `
            -Description "CPU, RAM, and Disk are within normal parameters."))
    }
    Push-LogMessage -State $State -Message "  RAM: $($d['RamPct'])%  |  Disk C: $($d['DiskPct'])%  |  CPU: $($d['CpuLoad'])%  |  Uptime: $($d['UptimeStr'])" -Type "info"
}

# ============================================================
#  ANALYZE — sfc
#  Input: VerifyOutput from sfc /verifyonly (non-mutating Collect phase).
#  sfc /scannow may run in Repair_SFC AFTER this phase; its results are
#  reflected in the finding's Repaired flag and ActionsTaken, not here.
# ============================================================
$Script:Analyze_SFC = {
    param($Result, $State)
    $out = $Result.Data["VerifyOutput"]

    if ($out -match "did not find any integrity violations") {
        $Result.Findings.Add((New-Finding -Title "No Integrity Violations" -Severity "info" `
            -Description "sfc /verifyonly: no corrupted system files detected."))
        Push-LogMessage -State $State -Message "  sfc /verifyonly: no integrity violations found." -Type "ok"
    } elseif ($out -match "found corrupt files" -or $out -match "unable to fix" -or $out -match "could not perform") {
        $Result.Findings.Add((New-Finding -Title "File Integrity Violations Detected" -Severity "warn" `
            -Description "sfc /verifyonly: corrupted or missing system files detected. sfc /scannow will run in SafeRepair or FullRepair mode to repair them."))
        $Result.Warnings.Add("System file integrity violations detected. SFC repair will run if mode allows.")
        $Result.Recommendations.Add("Run in SafeRepair or FullRepair mode to execute sfc /scannow.")
        Push-LogMessage -State $State -Message "  sfc /verifyonly: integrity violations found — repair queued." -Type "warn"
    } else {
        $Result.Findings.Add((New-Finding -Title "SFC Verify Inconclusive" -Severity "warn" `
            -Description "sfc /verifyonly result could not be determined. Check CBS.log for details."))
        Push-LogMessage -State $State -Message "  sfc /verifyonly: inconclusive — check CBS.log." -Type "warn"
    }
}

# ============================================================
#  ANALYZE — dism
#  Input: CheckOutput from DISM /CheckHealth (non-mutating Collect phase).
#  /ScanHealth (SafeRepair) and /RestoreHealth (FullRepair) run in Repair_DISM
#  AFTER this phase; their results update findings via Repaired flag / ActionsTaken.
#
#  CheckHealth limitation: reports "healthy" by default if /ScanHealth has never
#  been run on this machine. SafeRepair /ScanHealth provides a deeper assessment.
# ============================================================
$Script:Analyze_DISM = {
    param($Result, $State)
    $out = $Result.Data["CheckOutput"]

    if ($out -match "No component store corruption detected") {
        $Result.Findings.Add((New-Finding -Title "Component Store Healthy" -Severity "info" `
            -Description "DISM /CheckHealth: no stored corruption flag detected. Run in SafeRepair mode for a full /ScanHealth assessment."))
        $Result.Recommendations.Add("Run in SafeRepair mode to execute DISM /ScanHealth for a deeper component store check.")
        Push-LogMessage -State $State -Message "  DISM CheckHealth: no corruption flag. SafeRepair will run /ScanHealth." -Type "ok"
    } elseif ($out -match "component store is repairable" -or $out -match "Repairable") {
        $Result.Findings.Add((New-Finding -Title "Component Store Repairable" -Severity "warn" `
            -Description "DISM /CheckHealth: corruption detected — component store can be repaired. Run in FullRepair mode to execute DISM /RestoreHealth."))
        $Result.Warnings.Add("DISM: component store has repairable corruption.")
        $Result.Recommendations.Add("Run in FullRepair mode to execute DISM /RestoreHealth.")
        Push-LogMessage -State $State -Message "  DISM CheckHealth: repairable corruption detected." -Type "warn"
    } elseif ($out -match "not repairable" -or $out -match "Irreparable") {
        $Result.Findings.Add((New-Finding -Title "Component Store Damage — Requires OS Repair" -Severity "error" `
            -Description "DISM /CheckHealth: component store damage detected that cannot be self-repaired. Consider OS repair or in-place upgrade."))
        $Result.Warnings.Add("DISM: component store damage may require OS repair.")
        Push-LogMessage -State $State -Message "  DISM CheckHealth: irreparable damage detected." -Type "error"
    } else {
        $Result.Findings.Add((New-Finding -Title "DISM CheckHealth Inconclusive" -Severity "warn" `
            -Description "DISM /CheckHealth result could not be determined. Check dism.log for details."))
        Push-LogMessage -State $State -Message "  DISM CheckHealth: inconclusive — check dism.log." -Type "warn"
    }
}

# ============================================================
#  ANALYZE — chkdsk
# ============================================================
$Script:Analyze_ChkDsk = {
    param($Result, $State)
    $scan = $Result.Data["ScanOutput"]

    if ($scan -match "bad sector") {
        $Result.Findings.Add((New-Finding -Title "Bad Sectors Detected" -Severity "critical" `
            -Description "Bad sectors found on C:. Drive may be failing. Back up immediately!"))
        $Result.Warnings.Add("Bad sectors on C: — drive may be failing. Back up data immediately!")
        Push-LogMessage -State $State -Message "  BAD SECTORS detected — drive may be failing!" -Type "error"
    } elseif ($scan -match "found problems" -or $scan -match "errors found") {
        $Result.Findings.Add((New-Finding -Title "File System Errors Detected" -Severity "warn" `
            -Description "CHKDSK found file system errors that need repair."))
        Push-LogMessage -State $State -Message "  File system errors found - will attempt SpotFix..." -Type "warn"
    } else {
        $Result.Findings.Add((New-Finding -Title "No File System Errors" -Severity "info" `
            -Description "CHKDSK found no file system errors on C:."))
        Push-LogMessage -State $State -Message "  No file system errors found." -Type "ok"
    }
}

# ============================================================
#  ANALYZE — temp
# ============================================================
$Script:Analyze_Temp = {
    param($Result, $State)
    $totalMB = [math]::Round($Result.Data["TotalBytes"] / 1MB, 1)

    if ($totalMB -gt 1000) {
        $Result.Findings.Add((New-Finding -Title "Large Temp Footprint" -Severity "warn" `
            -Description "$totalMB MB of temporary files found across known temp locations."))
        $Result.Recommendations.Add("Clean temporary files to reclaim disk space.")
    } elseif ($totalMB -gt 200) {
        $Result.Findings.Add((New-Finding -Title "Moderate Temp Files" -Severity "warn" `
            -Description "$totalMB MB of temporary files found."))
    } else {
        $Result.Findings.Add((New-Finding -Title "Temp Files within Normal Range" -Severity "info" `
            -Description "$totalMB MB of temporary files found."))
    }
    Push-LogMessage -State $State -Message "  Temp files found: $totalMB MB" -Type "info"
}

# ============================================================
#  ANALYZE — events
# ============================================================
$Script:Analyze_Events = {
    param($Result, $State)
    $count = $Result.Data["Count"]

    if ($count -eq 0) {
        $Result.Findings.Add((New-Finding -Title "No Critical Events" -Severity "info" `
            -Description "No critical or error events found in the last 24 hours."))
        Push-LogMessage -State $State -Message "  No critical events in last 24h." -Type "ok"
    } elseif ($count -le 5) {
        $Result.Findings.Add((New-Finding -Title "Few Error Events" -Severity "warn" `
            -Description "$count error/critical events found in the last 24 hours."))
        Push-LogMessage -State $State -Message "  $count events found (low)." -Type "warn"
    } elseif ($count -le 15) {
        $Result.Findings.Add((New-Finding -Title "Moderate Error Events" -Severity "warn" `
            -Description "$count error/critical events found in the last 24 hours."))
        $Result.Warnings.Add("$count error events in last 24h — review recommended.")
        Push-LogMessage -State $State -Message "  $count events found (moderate)." -Type "warn"
    } else {
        $Result.Findings.Add((New-Finding -Title "High Error Event Count" -Severity "error" `
            -Description "$count error/critical events in last 24h. System may be unstable."))
        $Result.Warnings.Add("$count critical events in last 24h — system may be unstable.")
        Push-LogMessage -State $State -Message "  $count events found (HIGH)." -Type "error"
    }
}

# ============================================================
#  ANALYZE — winupdate
# ============================================================
$Script:Analyze_WinUpdate = {
    param($Result, $State)
    $cnt = $Result.Data["PendingCount"]

    if ($cnt -eq -1) {
        $Result.Findings.Add((New-Finding -Title "Update Check Failed" -Severity "warn" `
            -Description "Could not query Windows Update. Check manually via Settings."))
        Push-LogMessage -State $State -Message "  Could not check Windows Update automatically." -Type "warn"
    } elseif ($cnt -eq 0) {
        $Result.Findings.Add((New-Finding -Title "System Up To Date" -Severity "info" `
            -Description "No pending Windows updates found."))
        Push-LogMessage -State $State -Message "  System is up to date." -Type "ok"
    } else {
        $sev = if ($cnt -gt 10) { "error" } elseif ($cnt -gt 3) { "warn" } else { "warn" }
        $Result.Findings.Add((New-Finding -Title "$cnt Pending Updates" -Severity $sev `
            -Description "$cnt Windows updates available."))
        $Result.Warnings.Add("$cnt Windows updates pending.")
        Push-LogMessage -State $State -Message "  $cnt updates pending." -Type "warn"
    }
}

# ============================================================
#  ANALYZE — startup
# ============================================================
$Script:Analyze_Startup = {
    param($Result, $State)
    $count = $Result.Data["Count"]

    if ($count -gt 20) {
        $Result.Findings.Add((New-Finding -Title "Very High Startup Count" -Severity "error" `
            -Description "$count programs configured to launch at startup. This significantly impacts boot time."))
        $Result.Recommendations.Add("Review startup programs in Task Manager > Startup tab and disable non-essential items.")
    } elseif ($count -gt 12) {
        $Result.Findings.Add((New-Finding -Title "Elevated Startup Count" -Severity "warn" `
            -Description "$count startup programs found. May impact boot performance."))
        $Result.Recommendations.Add("Review startup items and disable unnecessary ones.")
    } else {
        $Result.Findings.Add((New-Finding -Title "Startup Count Normal" -Severity "info" `
            -Description "$count startup programs found."))
    }
    Push-LogMessage -State $State -Message "  $count startup items found." -Type "info"
}

# ============================================================
#  ANALYZE — smart
# ============================================================
$Script:Analyze_Smart = {
    param($Result, $State)
    $disks = $Result.Data["Disks"]

    if (-not $disks) {
        $Result.Findings.Add((New-Finding -Title "SMART Data Unavailable" -Severity "warn" `
            -Description "Could not retrieve physical disk SMART data via WMI."))
        Push-LogMessage -State $State -Message "  Could not read SMART data." -Type "warn"
        return
    }

    foreach ($d in $disks) {
        $sz = [math]::Round($d.Size / 1GB, 1)
        switch ($d.HealthStatus) {
            "Healthy" {
                $Result.Findings.Add((New-Finding -Title "Drive Healthy" -Severity "info" `
                    -Description "$($d.FriendlyName) | $($d.MediaType) | $sz GB — Healthy"))
                Push-LogMessage -State $State -Message "  $($d.FriendlyName): Healthy" -Type "ok"
            }
            "Warning" {
                $Result.Findings.Add((New-Finding -Title "Drive Warning" -Severity "warn" `
                    -Description "$($d.FriendlyName) | $($d.MediaType) | $sz GB — WARNING"))
                $Result.Warnings.Add("Drive '$($d.FriendlyName)' reports WARNING status.")
                Push-LogMessage -State $State -Message "  $($d.FriendlyName): WARNING" -Type "warn"
            }
            "Unhealthy" {
                $Result.Findings.Add((New-Finding -Title "Drive UNHEALTHY" -Severity "critical" `
                    -Description "$($d.FriendlyName) | $($d.MediaType) | $sz GB — UNHEALTHY. Back up data immediately!"))
                $Result.Warnings.Add("Drive '$($d.FriendlyName)' is UNHEALTHY. Back up immediately!")
                Push-LogMessage -State $State -Message "  $($d.FriendlyName): UNHEALTHY!" -Type "error"
            }
            default {
                $Result.Findings.Add((New-Finding -Title "Drive Status Unknown" -Severity "warn" `
                    -Description "$($d.FriendlyName) | $sz GB — Status: $($d.HealthStatus)"))
                Push-LogMessage -State $State -Message "  $($d.FriendlyName): $($d.HealthStatus)" -Type "info"
            }
        }
    }
}

# ============================================================
#  ANALYZE — ram
# ============================================================
$Script:Analyze_Ram = {
    param($Result, $State)
    $errCount = $Result.Data["ErrorCount"]

    if ($errCount -gt 0) {
        $Result.Findings.Add((New-Finding -Title "Memory Errors Detected" -Severity "error" `
            -Description "$errCount memory-related error events found in System log. RAM may be faulty."))
        $Result.Warnings.Add("$errCount memory errors in event log — RAM may be faulty.")
        Push-LogMessage -State $State -Message "  $errCount memory-related events found." -Type "warn"
    } else {
        $Result.Findings.Add((New-Finding -Title "No Memory Errors" -Severity "info" `
            -Description "No memory-related errors found in the System event log."))
        Push-LogMessage -State $State -Message "  No memory errors in event log." -Type "ok"
    }

    $sticks = $Result.Data["Sticks"]
    if ($sticks) {
        $totalRAM = [math]::Round(($sticks | Measure-Object -Property Capacity -Sum).Sum / 1GB, 1)
        Push-LogMessage -State $State -Message "  Installed RAM: $totalRAM GB ($($sticks.Count) module(s))" -Type "info"
    }
}

Write-Verbose "[System.Analyze] Analyze phase scriptblocks loaded."
