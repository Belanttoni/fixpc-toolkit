<#
.SYNOPSIS
    FixPC Toolkit — Hardware Module: Collect Phase
    Non-mutating collection of hardware identity and health indicators.
    Scriptblock stored as $Script:Collect_Hardware.

    Rule: Collect must NEVER modify hardware state, run firmware tools,
    or perform any operation that changes system configuration.

    Sources:
        Win32_Processor       — CPU model, cores, load snapshot
        Win32_PhysicalMemory  — installed RAM sticks and capacity
        Win32_OperatingSystem — RAM usage snapshot (KB values)
        Win32_LogicalDisk     — all local fixed drives (DriveType=3)
        Get-PhysicalDisk      — SMART health status per physical drive
        Win32_BaseBoard       — motherboard manufacturer and product
        Win32_BIOS            — BIOS vendor, version, release date
        Win32_VideoController — primary GPU name (optional, best-effort)

.VERSION 1.0
#>

$Script:Collect_Hardware = {
    param($Result, $State)

    Push-LogMessage -State $State -Message "  Collecting CPU information..." -Type "info"

    # ============================================================
    #  CPU
    # ============================================================
    $cpus = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $Result.Data["CPUs"]       = $cpus
    $Result.Data["CpuName"]    = if ($cpus) { ($cpus | Select-Object -First 1).Name.Trim() } else { $null }
    $Result.Data["CpuCores"]   = if ($cpus) {
        ($cpus | Measure-Object -Property NumberOfCores -Sum).Sum
    } else { 0 }
    $Result.Data["CpuLogical"] = if ($cpus) {
        ($cpus | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    } else { 0 }
    $Result.Data["CpuMaxMHz"]  = if ($cpus) { ($cpus | Select-Object -First 1).MaxClockSpeed } else { 0 }
    # LoadPercentage is a snapshot — useful as an indicator, not a definitive measure
    $Result.Data["CpuLoadPct"] = if ($cpus) {
        [math]::Round(($cpus | Measure-Object -Property LoadPercentage -Average).Average, 1)
    } else { 0 }

    Push-LogMessage -State $State -Message "  Collecting RAM information..." -Type "info"

    # ============================================================
    #  RAM — physical sticks
    # ============================================================
    $sticks = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $Result.Data["MemSticks"]     = $sticks
    $Result.Data["MemStickCount"] = if ($sticks) { @($sticks).Count } else { 0 }
    $Result.Data["MemTotalGB"]    = if ($sticks) {
        [math]::Round(($sticks | Measure-Object -Property Capacity -Sum).Sum / 1GB, 1)
    } else { 0 }

    # RAM usage snapshot from OS (values are in KB)
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os -and $os.TotalVisibleMemorySize -gt 0) {
        $totalKB = $os.TotalVisibleMemorySize
        $freeKB  = $os.FreePhysicalMemory
        $usedKB  = $totalKB - $freeKB
        $Result.Data["RamTotalMB"] = [math]::Round($totalKB / 1024, 0)
        $Result.Data["RamFreeMB"]  = [math]::Round($freeKB  / 1024, 0)
        $Result.Data["RamUsedMB"]  = [math]::Round($usedKB  / 1024, 0)
        $Result.Data["RamUsedPct"] = [math]::Round($usedKB / $totalKB * 100, 1)
    } else {
        $Result.Data["RamTotalMB"] = 0
        $Result.Data["RamFreeMB"]  = 0
        $Result.Data["RamUsedMB"]  = 0
        $Result.Data["RamUsedPct"] = 0
    }

    Push-LogMessage -State $State -Message "  Collecting disk inventory..." -Type "info"

    # ============================================================
    #  LOGICAL DISKS  (DriveType=3 = local fixed disks only)
    # ============================================================
    $logDisks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    $Result.Data["LogicalDisks"] = $logDisks

    # ============================================================
    #  PHYSICAL DISKS  (SMART health via Storage module)
    # ============================================================
    try {
        $physDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    } catch {
        $physDisks = $null
    }
    $Result.Data["PhysicalDisks"] = $physDisks

    # ============================================================
    #  MOTHERBOARD
    # ============================================================
    $mb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $Result.Data["Motherboard"]    = $mb
    $Result.Data["MBManufacturer"] = if ($mb) { $mb.Manufacturer } else { $null }
    $Result.Data["MBProduct"]      = if ($mb) { $mb.Product      } else { $null }

    # ============================================================
    #  BIOS
    # ============================================================
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $Result.Data["BIOS"]        = $bios
    $Result.Data["BIOSVendor"]  = if ($bios) { $bios.Manufacturer      } else { $null }
    $Result.Data["BIOSVersion"] = if ($bios) { $bios.SMBIOSBIOSVersion  } else { $null }
    $Result.Data["BIOSDate"]    = if ($bios -and $bios.ReleaseDate) {
        try { $bios.ReleaseDate.ToString("yyyy-MM-dd") } catch { $null }
    } else { $null }

    # ============================================================
    #  GPU  (best-effort — non-critical)
    # ============================================================
    $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
           Select-Object -First 1
    $Result.Data["GPU"]     = $gpu
    $Result.Data["GPUName"] = if ($gpu) { $gpu.Name } else { $null }
}
