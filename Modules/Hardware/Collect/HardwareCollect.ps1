<#
.SYNOPSIS
    FixPC Toolkit — Hardware Module: Collect Phase
    Non-mutating collection of hardware identity and health indicators.
    Scriptblock stored as $Script:Collect_Hardware.

    Rule: Collect must NEVER modify hardware state, run firmware tools,
    or perform any operation that changes system configuration.

    Sources:
        Win32_Processor               — CPU model, cores, load snapshot
        Win32_PhysicalMemory          — installed RAM sticks and capacity
        Win32_OperatingSystem         — RAM usage snapshot (KB values)
        Win32_LogicalDisk             — all local fixed drives (DriveType=3)
        Get-PhysicalDisk              — SMART health status per physical drive
        Win32_BaseBoard               — motherboard manufacturer and product
        Win32_BIOS                    — BIOS vendor, version, release date
        Win32_VideoController         — primary GPU name (optional, best-effort)
        root\LibreHardwareMonitor     — Tier-2 CPU/drive/fan sensors (LHM, optional)
        root\OpenHardwareMonitor      — Tier-2 sensors fallback (OHM, optional)
        MSAcpi_ThermalZoneTemperature — Tier-1 ACPI zone temps (always attempted)
        MSFT_StorageReliabilityCounter — NVMe/SATA drive temps (Win 10 1903+)
        Win32_Battery                 — laptop charge level and status
        Win32_PortableBattery         — alternate battery capacity source
        root\wmi\BatteryStaticData    — designed capacity (mWh)
        root\wmi\BatteryFullChargedCapacity — actual full charge (mWh, health calc)

    LHM/OHM detection notes:
        Get-CimInstance with -ErrorAction SilentlyContinue converts WMI errors
        to non-terminating errors that are silently discarded — the catch block
        never executes and the query returns $null.  All sensor queries here use
        -ErrorAction Stop inside try/catch so every failure is caught and logged.
        Sensor type filtering is always done in PowerShell, never via WQL filter,
        because the LHM WMI bridge does not reliably honour WQL predicates.

.VERSION 1.2
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

    Push-LogMessage -State $State -Message "  Collecting sensor data..." -Type "info"

    # ============================================================
    #  SENSOR DATA — TIER 1: ACPI Thermal Zones
    #  Zero-dependency. Available on virtually all Windows systems.
    #  Temperatures are in tenths of Kelvin: °C = (value - 2731.5) / 10
    # ============================================================
    $acpiTemps = [System.Collections.Generic.List[object]]::new()
    try {
        $thermalZones = Get-CimInstance -Namespace "root\WMI" `
            -ClassName "MSAcpi_ThermalZoneTemperature" `
            -ErrorAction SilentlyContinue
        if ($thermalZones) {
            foreach ($zone in $thermalZones) {
                $tempC = [math]::Round(($zone.CurrentTemperature - 2731.5) / 10, 1)
                # Sanity check: only accept plausible readings (0–120 °C)
                if ($tempC -ge 0 -and $tempC -le 120) {
                    $zoneName = $zone.InstanceName -replace ".*ThermalZone\\", "Zone: " `
                                                   -replace "_\d+$", ""
                    $acpiTemps.Add([ordered]@{
                        Name  = $zoneName
                        TempC = $tempC
                    })
                }
            }
        }
    } catch { }
    $Result.Data["AcpiTemps"] = $acpiTemps
    Push-LogMessage -State $State `
        -Message "  ACPI thermal zones: $($acpiTemps.Count)" -Type "info"

    # ============================================================
    #  SENSOR DATA — TIER 2: LibreHardwareMonitor / OpenHardwareMonitor WMI bridge
    #
    #  Detection strategy (two-path, fully logged):
    #
    #    1. Check whether LHM/OHM processes are running.  This informs advisory
    #       messages but does NOT gate the WMI queries — the process may run under
    #       a different session and the provider may still be registered.
    #
    #    2. For each namespace, attempt Get-CimInstance (WS-Management / WinRM).
    #       Use -ErrorAction Stop so exceptions surface in catch — SilentlyContinue
    #       would swallow them and make null indistinguishable from an empty result.
    #
    #    3. If CimInstance fails or returns 0 sensors, attempt Get-WmiObject (DCOM).
    #       DCOM and WS-Man use different protocol stacks; some dynamic WMI providers
    #       (including LHM on certain Windows configurations) are reachable via DCOM
    #       when WS-Man cannot access them.
    #
    #    4. The __NAMESPACE list is checked for diagnostics only — it is NOT a gate.
    #       Dynamic WMI providers like LHM may not appear in __NAMESPACE enumeration
    #       even when the namespace is fully accessible.  Skipping based on that list
    #       was the original source of false-negative "not detected" results.
    #
    #    5. Sensor type filtering is always done in PowerShell (never via WQL filter),
    #       because the LHM WMI bridge does not reliably honour WQL predicates.
    #
    #  Failure modes logged distinctly:
    #    • process running, both paths failed → WMI bridge needs elevated privileges
    #    • CimInstance failed, WmiObject OK   → DCOM path used, WS-Man not accessible
    #    • both paths 0 sensors               → LHM may still be initialising
    #    • sensors found, no CPU match        → full sensor name dump logged
    # ============================================================
    $ohmTemps        = [System.Collections.Generic.List[object]]::new()
    $ohmFans         = [System.Collections.Generic.List[object]]::new()
    $ohmNamespace    = $null
    $ohmLevelSensors = @()

    # --- Process discovery -------------------------------------------------
    $lhmProc = $null
    $ohmProc = $null
    try { $lhmProc = Get-Process -Name "LibreHardwareMonitor" -ErrorAction SilentlyContinue } catch { }
    try { $ohmProc = Get-Process -Name "OpenHardwareMonitor"  -ErrorAction SilentlyContinue } catch { }

    $lhmRunning = [bool]$lhmProc
    $ohmRunning = [bool]$ohmProc

    if ($lhmRunning) {
        $lhmPid = ($lhmProc | Select-Object -First 1).Id
        Push-LogMessage -State $State `
            -Message "  LibreHardwareMonitor.exe: running (PID ${lhmPid})." -Type "info"
    } else {
        Push-LogMessage -State $State `
            -Message "  LibreHardwareMonitor.exe: not running." -Type "info"
    }
    if ($ohmRunning) {
        $ohmPid = ($ohmProc | Select-Object -First 1).Id
        Push-LogMessage -State $State `
            -Message "  OpenHardwareMonitor.exe: running (PID ${ohmPid})." -Type "info"
    } else {
        Push-LogMessage -State $State `
            -Message "  OpenHardwareMonitor.exe: not running." -Type "info"
    }

    # Store for Analyze phase — used to tailor sensor-unavailable advisory message
    $Result.Data["LhmRunning"] = $lhmRunning
    $Result.Data["OhmRunning"] = $ohmRunning

    # --- Namespace and sensor queries (two-path per namespace) ---------------
    $nsCandidates = [ordered]@{
        "root\LibreHardwareMonitor" = $lhmRunning
        "root\OpenHardwareMonitor"  = $ohmRunning
    }

    foreach ($nsEntry in $nsCandidates.GetEnumerator()) {
        $ns         = $nsEntry.Key
        $procActive = $nsEntry.Value   # bool: matching process is running
        $shortNs    = $ns.Split('\')[-1]
        $nsLeaf     = $shortNs

        Push-LogMessage -State $State `
            -Message "  Testing WMI namespace: ${ns}" -Type "info"

        # Informational __NAMESPACE check — NOT a gate.
        # Dynamic providers may not appear here; we always try the query.
        try {
            $rootChildren = Get-CimInstance -Namespace "root" `
                -ClassName "__NAMESPACE" -ErrorAction Stop
            if ($rootChildren) {
                $nsInList = [bool]($rootChildren | Where-Object { $_.Name -eq $nsLeaf })
                Push-LogMessage -State $State `
                    -Message "  ${ns}: in root\__NAMESPACE = ${nsInList} (informational; dynamic providers may not appear here — query attempted regardless)." `
                    -Type "info"
            }
        } catch { }

        # --- Path 1: Get-CimInstance  (WS-Management / WinRM) ---------------
        $allSensors     = $null
        $allSensorCount = 0
        $cimError       = $null
        try {
            $allSensors     = Get-CimInstance -Namespace $ns -ClassName "Sensor" -ErrorAction Stop
            $allSensorCount = @($allSensors).Count
            Push-LogMessage -State $State `
                -Message "  ${shortNs} CimInstance (WS-Man): OK — ${allSensorCount} sensors." -Type "info"
        } catch {
            $cimError = $_.Exception.Message
            Push-LogMessage -State $State `
                -Message "  ${shortNs} CimInstance (WS-Man) failed: ${cimError}" -Type "info"
        }

        # --- Path 2: Get-WmiObject  (DCOM / RPC) — fallback when CimInstance
        #     failed or returned 0.  DCOM reaches dynamic providers that WS-Man
        #     cannot — notably LHM when WinRM is restricted or misconfigured. ----
        if ($allSensorCount -eq 0) {
            $wmiError = $null
            try {
                $wmiRaw = Get-WmiObject -Namespace $ns -Class "Sensor" -ErrorAction Stop
                if ($wmiRaw) {
                    $allSensors     = @($wmiRaw)
                    $allSensorCount = $allSensors.Count
                    Push-LogMessage -State $State `
                        -Message "  ${shortNs} WmiObject (DCOM): OK — ${allSensorCount} sensors." -Type "info"
                } else {
                    Push-LogMessage -State $State `
                        -Message "  ${shortNs} WmiObject (DCOM): query returned no objects." -Type "info"
                }
            } catch {
                $wmiError = $_.Exception.Message
                Push-LogMessage -State $State `
                    -Message "  ${shortNs} WmiObject (DCOM) failed: ${wmiError}" -Type "info"
            }
        }

        # --- Evaluate combined result ----------------------------------------
        if ($allSensorCount -eq 0) {
            if ($procActive) {
                $bothFailed = $null -ne $cimError -and ($null -ne $wmiError -or $allSensorCount -eq 0)
                if ($bothFailed) {
                    Push-LogMessage -State $State `
                        -Message "  WARN: ${shortNs} process IS running but both WMI access paths returned no sensor data. LHM requires Administrator privileges to register its WMI provider. Re-launch LibreHardwareMonitor as Administrator to enable the WMI bridge." `
                        -Type "warn"
                } else {
                    Push-LogMessage -State $State `
                        -Message "  WARN: ${shortNs} query succeeded but returned 0 sensors. LHM may still be initialising hardware monitoring." `
                        -Type "warn"
                }
            } else {
                Push-LogMessage -State $State `
                    -Message "  ${shortNs}: no sensors returned and process not running — skipping." `
                    -Type "info"
            }
            continue
        }

        # --- Filter by SensorType in PowerShell (never WQL on LHM bridge) ----
        $ohmNamespace = $ns

        $tempSensors  = @($allSensors | Where-Object { $_.SensorType -eq "Temperature" })
        $fanSensors   = @($allSensors | Where-Object { $_.SensorType -eq "Fan"         })
        $levelSensors = @($allSensors | Where-Object { $_.SensorType -eq "Level"       })
        $rawTempCount = $tempSensors.Count

        foreach ($s in $tempSensors) {
            if ($null -ne $s.Value -and $s.Value -gt 0 -and $s.Value -le 120) {
                $ohmTemps.Add([ordered]@{
                    Name         = if ($s.Name)         { $s.Name         } else { "Unknown" }
                    HardwareName = if ($s.HardwareName) { $s.HardwareName } else { "" }
                    TempC        = [math]::Round($s.Value, 1)
                })
            }
        }

        foreach ($f in $fanSensors) {
            if ($null -ne $f.Value) {
                $ohmFans.Add([ordered]@{
                    Name         = if ($f.Name)         { $f.Name         } else { "Fan" }
                    HardwareName = if ($f.HardwareName) { $f.HardwareName } else { "" }
                    RPM          = [math]::Round($f.Value, 0)
                })
            }
        }

        $ohmLevelSensors = $levelSensors

        Push-LogMessage -State $State `
            -Message "  Sensor source: ${shortNs} | Temp: $($ohmTemps.Count) (raw: ${rawTempCount}) | Fan: $($ohmFans.Count) | Level: $($ohmLevelSensors.Count)" `
            -Type "info"

        break  # stop after first successful namespace
    }

    if (-not $ohmNamespace) {
        $anyProcRunning = $lhmRunning -or $ohmRunning
        if ($anyProcRunning) {
            Push-LogMessage -State $State `
                -Message "  No LHM/OHM sensor source available despite monitor process running. WMI bridge requires Administrator privileges. ACPI thermal zones: $($acpiTemps.Count)." `
                -Type "warn"
        } else {
            Push-LogMessage -State $State `
                -Message "  No LHM/OHM sensor source available. ACPI thermal zones: $($acpiTemps.Count)." `
                -Type "info"
        }
    }

    $Result.Data["OhmTemps"]        = $ohmTemps
    $Result.Data["OhmFans"]         = $ohmFans
    $Result.Data["OhmNamespace"]    = $ohmNamespace
    $Result.Data["OhmLevelSensors"] = $ohmLevelSensors

    # ============================================================
    #  SENSOR DATA — TIER 3: Drive temperatures
    #  MSFT_StorageReliabilityCounter exposes NVMe/SATA temps on Win 10 1903+.
    #  Uses CIM associations from already-collected physical disk objects.
    # ============================================================
    $driveTemps = [System.Collections.Generic.List[object]]::new()
    if ($physDisks) {
        foreach ($pd in $physDisks) {
            try {
                $rc = $pd | Get-CimAssociatedInstance `
                    -ResultClassName "MSFT_StorageReliabilityCounter" `
                    -ErrorAction SilentlyContinue
                if ($rc -and $null -ne $rc.Temperature -and `
                    $rc.Temperature -gt 0 -and $rc.Temperature -lt 100) {
                    $driveTemps.Add([ordered]@{
                        Name  = if ($pd.FriendlyName) { $pd.FriendlyName } else { "Drive" }
                        Type  = if ($pd.MediaType)    { $pd.MediaType    } else { "Unknown" }
                        TempC = $rc.Temperature
                    })
                }
            } catch { }
        }
    }
    $Result.Data["DriveTemps"] = $driveTemps

    # ============================================================
    #  DERIVE BEST CPU TEMPERATURE
    #  Multi-step priority selection covering LHM/OHM sensor naming
    #  conventions for Intel and AMD CPUs.  Each priority level is
    #  tried in order; first match wins.  The reason for any failure
    #  is logged explicitly.
    #
    #  Priority order:
    #    1. "CPU Package"         — standard name, Intel + modern AMD
    #    2. "Core Max"/"Core Avg" — LHM virtual derived aggregates
    #    3. "CPU Tdie/Tctl/CCD"   — AMD junction temps
    #    4. Any name starting with "CPU"
    #    5. HardwareName matches known CPU identifiers (not GPU names)
    # ============================================================
    $cpuTempC      = $null
    $cpuTempSource = "No sensor data available"

    if ($ohmTemps.Count -gt 0) {
        $shortNs    = $ohmNamespace.Split('\')[-1]
        $cpuTempSel = $null

        # Priority 1: "CPU Package" — universal best-practice reading
        $cpuTempSel = $ohmTemps | Where-Object { $_.Name -eq "CPU Package" } |
                      Select-Object -First 1

        # Priority 2: LHM virtual aggregate sensors (derived by LHM itself)
        if (-not $cpuTempSel) {
            $cpuTempSel = $ohmTemps | Where-Object {
                $_.Name -eq "Core Max" -or $_.Name -eq "Core Average"
            } | Sort-Object TempC -Descending | Select-Object -First 1
        }

        # Priority 3: AMD junction temperature sensors
        if (-not $cpuTempSel) {
            $cpuTempSel = $ohmTemps | Where-Object {
                $_.Name -match "^CPU (Tdie|Tctl|CCD|Temperature)"
            } | Sort-Object TempC -Descending | Select-Object -First 1
        }

        # Priority 4: Any sensor whose name starts with "CPU"
        if (-not $cpuTempSel) {
            $cpuTempSel = $ohmTemps | Where-Object {
                $_.Name -match "^CPU"
            } | Sort-Object TempC -Descending | Select-Object -First 1
        }

        # Priority 5: Sensor associated with CPU hardware by HardwareName.
        # Pattern deliberately excludes GPU entries ("AMD Radeon", "NVIDIA GeForce", etc.).
        if (-not $cpuTempSel) {
            $cpuTempSel = $ohmTemps | Where-Object {
                $_.HardwareName -match ("Intel Core|Intel Xeon|Intel Pentium|Intel Celeron|" +
                                        "AMD Ryzen|AMD EPYC|AMD Athlon|AMD Threadripper|AMD FX")
            } | Sort-Object TempC -Descending | Select-Object -First 1
        }

        if ($cpuTempSel) {
            $cpuTempC      = $cpuTempSel.TempC
            $hwCtx         = if ($cpuTempSel.HardwareName) { " ($($cpuTempSel.HardwareName))" } else { "" }
            $cpuTempSource = "$($cpuTempSel.Name)${hwCtx} via ${shortNs}"
            Push-LogMessage -State $State `
                -Message "  CPU temp selected: ${cpuTempSource} — ${cpuTempC}°C" `
                -Type "info"
        } else {
            # Sensors present but none matched any CPU priority rule — dump all names
            $seenNames = ($ohmTemps | Select-Object -First 20 | ForEach-Object {
                "'$($_.Name)' [$($_.HardwareName)]"
            }) -join "; "
            Push-LogMessage -State $State `
                -Message "  WARN: ${shortNs} has $($ohmTemps.Count) temp sensors but none matched any CPU priority rule. Full sensor dump: ${seenNames}" `
                -Type "warn"
            $Result.Data["CpuTempLhmNoMatch"] = $true
            $Result.Data["CpuTempLhmSensors"] = $seenNames
        }
    } elseif ($ohmNamespace) {
        # Bridge is active but temperature sensor list is empty after value filter
        Push-LogMessage -State $State `
            -Message "  WARN: ${ohmNamespace} bridge active but 0 temperature sensors passed the plausibility filter (value > 0 and <= 120 °C). Raw temp sensor count from query was $($ohmTemps.Count)." `
            -Type "warn"
    }

    # ACPI fallback
    if ($null -eq $cpuTempC -and $acpiTemps.Count -gt 0) {
        $maxZone       = $acpiTemps | Sort-Object TempC -Descending | Select-Object -First 1
        $cpuTempC      = $maxZone.TempC
        $cpuTempSource = "ACPI Thermal Zone (estimated — may not be CPU-specific)"
        Push-LogMessage -State $State `
            -Message "  CPU temp (ACPI fallback): $($maxZone.Name) — ${cpuTempC}°C" `
            -Type "info"
    }

    if ($null -eq $cpuTempC) {
        Push-LogMessage -State $State `
            -Message "  CPU temperature: not available — no sensor source produced a valid reading." `
            -Type "info"
    }

    $Result.Data["CpuTempC"]      = $cpuTempC
    $Result.Data["CpuTempSource"] = $cpuTempSource

    # Source classification consumed by Analyze/Export phases
    $sensorSource = if ($ohmNamespace)             { $ohmNamespace.Split('\')[-1].ToLower() } `
                    elseif ($acpiTemps.Count -gt 0) { "acpi_only" } `
                    else                             { "none" }

    $Result.Data["SensorSource"]    = $sensorSource
    $Result.Data["SensorAvailable"] = ($null -ne $cpuTempC -or $driveTemps.Count -gt 0)

    # ============================================================
    #  BATTERY — capacity, health, and charge status
    #  Targets laptops/UPS-attached systems. Read-only diagnostic.
    #  Graceful on desktops and AC-only machines (no battery present).
    #
    #  Sources attempted in order:
    #    1. Win32_Battery                    — charge %, status, basic identity
    #    2. Win32_PortableBattery            — capacity fields often populated
    #                                          when Win32_Battery returns zeros
    #    3. root\wmi\BatteryStaticData       — designed capacity (mWh), Win 7+
    #    4. root\wmi\BatteryFullChargedCapacity — current full-charge (mWh)
    #    5. LHM Level sensors               — "Degradation Level" / "Charge Level"
    #
    #  Health derivation priority:
    #    LHM Degradation Level  → health = 100 − degradation  (most accurate)
    #    WMI capacity ratio     → health = FullCharge / Designed × 100
    #    Neither available      → health logged as unknown with reason
    # ============================================================
    Push-LogMessage -State $State -Message "  Collecting battery information..." -Type "info"

    $batPresent     = $false
    $batName        = $null
    $batChargePct   = $null
    $batStatus      = $null
    $batDesignedMWh = $null
    $batFullMWh     = $null
    $batHealthPct   = $null

    # Method 1: Win32_Battery — charge level and basic identity
    $w32Bats = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if ($w32Bats) {
        $batPresent = $true
        $w32Bat     = $w32Bats | Select-Object -First 1
        $batName    = if ($w32Bat.Name) { $w32Bat.Name.Trim() } else { "Battery" }
        $batChargePct = $w32Bat.EstimatedChargeRemaining

        # BatteryStatus integer codes per MSDN Win32_Battery documentation
        $batStatus = switch ($w32Bat.BatteryStatus) {
            1  { "Discharging"           }
            2  { "On AC Power"           }
            3  { "Fully Charged"         }
            4  { "Discharging (Low)"     }
            5  { "Discharging (Critical)"}
            6  { "Charging"              }
            7  { "Charging (High)"       }
            8  { "Charging (Low)"        }
            9  { "Charging (Critical)"   }
            default { "Unknown"          }
        }

        if ($w32Bat.DesignedCapacity   -gt 0) { $batDesignedMWh = $w32Bat.DesignedCapacity   }
        if ($w32Bat.FullChargeCapacity -gt 0) { $batFullMWh     = $w32Bat.FullChargeCapacity }

        Push-LogMessage -State $State `
            -Message "  Battery (Win32_Battery): name='${batName}' charge=${batChargePct}% status=${batStatus} designedMWh=${batDesignedMWh} fullMWh=${batFullMWh}" `
            -Type "info"
    } else {
        Push-LogMessage -State $State `
            -Message "  Battery (Win32_Battery): no instance returned." -Type "info"
    }

    # Method 2: Win32_PortableBattery — often carries capacity data Win32_Battery omits
    try {
        $portBats = Get-CimInstance Win32_PortableBattery -ErrorAction SilentlyContinue
        if ($portBats) {
            $batPresent = $true
            $portBat    = $portBats | Select-Object -First 1
            if (-not $batName -and $portBat.Name) { $batName = $portBat.Name.Trim() }
            if ($null -eq $batDesignedMWh -and $portBat.DesignCapacity   -gt 0) {
                $batDesignedMWh = $portBat.DesignCapacity
            }
            if ($null -eq $batFullMWh     -and $portBat.FullChargeCapacity -gt 0) {
                $batFullMWh = $portBat.FullChargeCapacity
            }
            Push-LogMessage -State $State `
                -Message "  Battery (Win32_PortableBattery): designedMWh=${batDesignedMWh} fullMWh=${batFullMWh}" `
                -Type "info"
        } else {
            Push-LogMessage -State $State `
                -Message "  Battery (Win32_PortableBattery): no instance returned." -Type "info"
        }
    } catch {
        Push-LogMessage -State $State `
            -Message "  Battery (Win32_PortableBattery): query failed — $($_.Exception.Message)" -Type "info"
    }

    # Method 3: root\wmi battery classes — reliable capacity source on Win 7+
    try {
        $batStatic = Get-CimInstance -Namespace "root\wmi" `
            -ClassName "BatteryStaticData" -ErrorAction SilentlyContinue
        if ($batStatic) {
            $batPresent  = $true
            $firstStatic = $batStatic | Select-Object -First 1
            if ($null -eq $batDesignedMWh -and $firstStatic.DesignedCapacity -gt 0) {
                $batDesignedMWh = $firstStatic.DesignedCapacity
            }
            Push-LogMessage -State $State `
                -Message "  Battery (BatteryStaticData): DesignedCapacity=${batDesignedMWh} mWh" `
                -Type "info"
        }

        $batFullData = Get-CimInstance -Namespace "root\wmi" `
            -ClassName "BatteryFullChargedCapacity" -ErrorAction SilentlyContinue
        if ($batFullData) {
            $batPresent = $true
            $firstFull  = $batFullData | Select-Object -First 1
            if ($null -eq $batFullMWh -and $firstFull.FullChargedCapacity -gt 0) {
                $batFullMWh = $firstFull.FullChargedCapacity
            }
            Push-LogMessage -State $State `
                -Message "  Battery (BatteryFullChargedCapacity): FullChargedCapacity=${batFullMWh} mWh" `
                -Type "info"
        }
    } catch {
        Push-LogMessage -State $State `
            -Message "  Battery (root\wmi classes): query error — $($_.Exception.Message)" -Type "warn"
    }

    # Method 4: LHM Level sensors — primary health source on modern laptops.
    # LHM exposes SensorType='Level' sensors: "Charge Level" (%) and "Degradation Level" (%).
    # These are more accurate than WMI capacity fields, which return 0 on many ACPI batteries.
    if ($ohmLevelSensors.Count -gt 0) {
        $degradationSensor = $ohmLevelSensors |
            Where-Object { $_.Name -eq "Degradation Level" } | Select-Object -First 1
        $lhmChargeSensor   = $ohmLevelSensors |
            Where-Object { $_.Name -eq "Charge Level"      } | Select-Object -First 1

        $degVal = if ($degradationSensor) { $degradationSensor.Value } else { $null }
        $chgVal = if ($lhmChargeSensor)   { $lhmChargeSensor.Value   } else { $null }
        Push-LogMessage -State $State `
            -Message "  Battery (LHM Level sensors): count=$($ohmLevelSensors.Count) | DegradationLevel=$(if ($null -ne $degVal) { $degVal } else { 'n/a' }) | ChargeLevel=$(if ($null -ne $chgVal) { $chgVal } else { 'n/a' })" `
            -Type "info"

        if ($null -ne $degVal) {
            $degradationPct = [math]::Round([double]$degVal, 1)
            $batHealthPct   = [math]::Round([math]::Max(100.0 - $degradationPct, 0.0), 1)
            $batPresent     = $true
            Push-LogMessage -State $State `
                -Message "  Battery health (LHM Degradation Level): ${degradationPct}% degraded => Health ${batHealthPct}%" `
                -Type "info"
        }

        if ($null -eq $batChargePct -and $null -ne $chgVal) {
            $batChargePct = [math]::Round([double]$chgVal, 1)
            Push-LogMessage -State $State `
                -Message "  Battery charge (LHM Charge Level): ${batChargePct}%" -Type "info"
        }
    } else {
        $bridgeNote = if ($ohmNamespace) { " (bridge active but no Level sensors present)" } else { "" }
        Push-LogMessage -State $State `
            -Message "  Battery (LHM Level sensors): none available${bridgeNote}." -Type "info"
    }

    # Derive health from WMI capacity ratio only if LHM did not supply it
    if ($null -eq $batHealthPct -and $batDesignedMWh -gt 0 -and $batFullMWh -gt 0) {
        $rawHealth    = $batFullMWh / $batDesignedMWh * 100
        $batHealthPct = [math]::Round([math]::Min($rawHealth, 100.0), 1)
        Push-LogMessage -State $State `
            -Message "  Battery health (WMI capacity ratio): ${batFullMWh} / ${batDesignedMWh} mWh = ${batHealthPct}%" `
            -Type "info"
    }

    if ($batPresent -and $null -eq $batHealthPct) {
        Push-LogMessage -State $State `
            -Message "  Battery health: unknown — LHM bridge unavailable and WMI capacity fields returned 0 from all sources (Win32_Battery, Win32_PortableBattery, BatteryStaticData, BatteryFullChargedCapacity)." `
            -Type "warn"
    }

    $Result.Data["BatteryPresent"]     = $batPresent
    $Result.Data["BatteryName"]        = $batName
    $Result.Data["BatteryChargePct"]   = $batChargePct
    $Result.Data["BatteryStatus"]      = $batStatus
    $Result.Data["BatteryDesignedMWh"] = $batDesignedMWh
    $Result.Data["BatteryFullMWh"]     = $batFullMWh
    $Result.Data["BatteryHealthPct"]   = $batHealthPct

    if ($batPresent) {
        $hStr = if ($null -ne $batHealthPct) { " | Health: ${batHealthPct}%" } else { " | Health: unknown" }
        $cStr = if ($null -ne $batChargePct) { " | Charge: ${batChargePct}%" } else { "" }
        Push-LogMessage -State $State `
            -Message "  Battery: ${batName}${hStr}${cStr} | ${batStatus}" `
            -Type "info"
    } else {
        Push-LogMessage -State $State `
            -Message "  Battery: not detected (desktop or AC-only system)." `
            -Type "info"
    }
}
