<#
.SYNOPSIS
    FixPC Toolkit — System Module: Collect Phase
    All data-collection scriptblocks for the System module sub-modules.
    Scriptblocks are stored as Script-scope variables and consumed by SystemModule.ps1.

    Naming convention: $Script:Collect_<SubModuleId>

.VERSION 1.0
#>

# ============================================================
#  COLLECT — sysinfo
# ============================================================
$Script:Collect_SysInfo = {
    param($Result, $State)
    $os   = Get-CimInstance Win32_OperatingSystem
    $cs   = Get-CimInstance Win32_ComputerSystem
    $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $bios = Get-CimInstance Win32_BIOS
    $up   = (Get-Date) - $os.LastBootUpTime

    $ramTotal  = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $ramFree   = [math]::Round($os.FreePhysicalMemory / 1MB / 1024, 2)
    $ramUsed   = [math]::Round($ramTotal - $ramFree, 2)
    $ramPct    = [math]::Round(($ramUsed / $ramTotal) * 100, 1)
    $diskTotal = [math]::Round($disk.Size / 1GB, 2)
    $diskFree  = [math]::Round($disk.FreeSpace / 1GB, 2)
    $diskPct   = [math]::Round((($diskTotal - $diskFree) / $diskTotal) * 100, 1)
    $cpuLoad   = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

    $Result.Data["OS"]         = $os.Caption
    $Result.Data["Build"]      = $os.BuildNumber
    $Result.Data["Computer"]   = $cs.Name
    $Result.Data["CPU"]        = $cpu.Name
    $Result.Data["CpuLoad"]    = $cpuLoad
    $Result.Data["RamTotal"]   = $ramTotal
    $Result.Data["RamFree"]    = $ramFree
    $Result.Data["RamUsed"]    = $ramUsed
    $Result.Data["RamPct"]     = $ramPct
    $Result.Data["DiskTotal"]  = $diskTotal
    $Result.Data["DiskFree"]   = $diskFree
    $Result.Data["DiskPct"]    = $diskPct
    $Result.Data["UptimeDays"] = $up.Days
    $Result.Data["UptimeStr"]  = "$($up.Days)d $($up.Hours)h $($up.Minutes)m"
    $Result.Data["BIOS"]       = "$($bios.Manufacturer) v$($bios.SMBIOSBIOSVersion)"
}

# ============================================================
#  COLLECT — sfc   (non-mutating: sfc /verifyonly)
#  Rule: Collect must never repair. sfc /scannow lives in Repair_SFC.
# ============================================================
$Script:Collect_SFC = {
    param($Result, $State)
    # /verifyonly checks file integrity without making any repairs.
    # Output format mirrors /scannow; no files are modified.
    Push-LogMessage -State $State -Message "  Running sfc /verifyonly (read-only integrity check)..." -Type "info"
    $output = & sfc /verifyonly 2>&1 | Out-String
    $Result.Data["VerifyOutput"] = $output
    $Result.Data["ScanOutput"]   = ""   # reserved — populated by Repair_SFC if mode allows
    $Result.Data["LogFile"]      = "$env:SystemRoot\Logs\CBS\CBS.log"
}

# ============================================================
#  COLLECT — dism   (non-mutating: DISM /CheckHealth)
#  Rule: Collect must never repair.
#  /ScanHealth (SafeRepair) and /RestoreHealth (FullRepair) live in Repair_DISM.
# ============================================================
$Script:Collect_DISM = {
    param($Result, $State)
    # /CheckHealth reads the internally-stored health flag — instant, zero writes.
    # Possible results: "No component store corruption" | "Repairable" | "Not repairable"
    # Note: /CheckHealth reports "healthy" by default if /ScanHealth has never been run.
    $output = & DISM /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String
    $Result.Data["CheckOutput"]   = $output
    $Result.Data["ScanOutput"]    = ""   # populated by Repair_DISM (SafeRepair)
    $Result.Data["RestoreOutput"] = ""   # populated by Repair_DISM (FullRepair)
    $Result.Data["LogFile"]       = "$env:SystemRoot\Logs\DISM\dism.log"
}

# ============================================================
#  COLLECT — chkdsk
# ============================================================
$Script:Collect_ChkDsk = {
    param($Result, $State)
    $Result.Data["ScanOutput"]    = & chkdsk C: /scan 2>&1 | Out-String
    $Result.Data["SpotFixOutput"] = ""
}

# ============================================================
#  COLLECT — temp
# ============================================================
$Script:Collect_Temp = {
    param($Result, $State)
    $paths = @(
        $env:TEMP,
        $env:TMP,
        "$env:SystemRoot\Temp",
        "$env:SystemRoot\Prefetch",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Temp",
        "$env:SystemRoot\SoftwareDistribution\Download"
    )
    $inventory = @{}
    foreach ($p in ($paths | Select-Object -Unique)) {
        if (Test-Path $p) {
            $inventory[$p] = Get-FolderSizeBytes -Path $p
        }
    }
    $Result.Data["PathInventory"] = $inventory
    $Result.Data["TotalBytes"]    = ($inventory.Values | Measure-Object -Sum).Sum
}

# ============================================================
#  COLLECT — events
# ============================================================
$Script:Collect_Events = {
    param($Result, $State)
    $since = (Get-Date).AddHours(-24)
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = 'System', 'Application'
        Level     = 1, 2
        StartTime = $since
    } -ErrorAction SilentlyContinue | Select-Object -First 50
    $Result.Data["Events"] = $events
    $Result.Data["Count"]  = if ($events) { $events.Count } else { 0 }
}

# ============================================================
#  COLLECT — winupdate
# ============================================================
$Script:Collect_WinUpdate = {
    param($Result, $State)
    try {
        $sess   = New-Object -ComObject Microsoft.Update.Session
        $srch   = $sess.CreateUpdateSearcher()
        $res    = $srch.Search("IsInstalled=0 and Type='Software'")
        $count  = $res.Updates.Count
        $titles = @()
        for ($i = 0; $i -lt [Math]::Min($count, 30); $i++) {
            $titles += $res.Updates.Item($i).Title
        }
        $Result.Data["PendingCount"]  = $count
        $Result.Data["PendingTitles"] = $titles
        $Result.Data["Session"]       = $sess
        $Result.Data["SearchResult"]  = $res
    } catch {
        $Result.Data["PendingCount"]  = -1
        $Result.Data["Error"]         = $_.ToString()
        $Result.Errors.Add("Windows Update COM error: $_")
    }
}

# ============================================================
#  COLLECT — startup
# ============================================================
$Script:Collect_Startup = {
    param($Result, $State)
    $items    = [System.Collections.Generic.List[PSCustomObject]]::new()
    $regPaths = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";              Scope = "Machine"      },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";              Scope = "User"         },
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run";  Scope = "Machine (x86)"}
    )
    foreach ($rp in $regPaths) {
        if (Test-Path $rp.Path) {
            (Get-ItemProperty $rp.Path -ErrorAction SilentlyContinue).PSObject.Properties |
            Where-Object { $_.Name -notmatch "^PS" } |
            ForEach-Object {
                $items.Add([PSCustomObject]@{ Name = $_.Name; Command = $_.Value; Scope = $rp.Scope })
            }
        }
    }
    $Result.Data["Items"] = $items
    $Result.Data["Count"] = $items.Count
}

# ============================================================
#  COLLECT — smart
# ============================================================
$Script:Collect_Smart = {
    param($Result, $State)
    $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    $Result.Data["Disks"] = $disks
}

# ============================================================
#  COLLECT — ram
# ============================================================
$Script:Collect_Ram = {
    param($Result, $State)
    $sticks = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $memErrors = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2 } -ErrorAction SilentlyContinue |
                 Where-Object { $_.Message -match "memory|parity|hardware error" } |
                 Select-Object -First 10
    $Result.Data["Sticks"]     = $sticks
    $Result.Data["MemErrors"]  = $memErrors
    $Result.Data["ErrorCount"] = if ($memErrors) { $memErrors.Count } else { 0 }
}

Write-Verbose "[System.Collect] Collect phase scriptblocks loaded."
