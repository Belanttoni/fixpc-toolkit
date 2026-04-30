<#
.SYNOPSIS
    FixPC Toolkit — Hardware Module: Repair Phase
    Advisory-only — no hardware state is modified.
    Scriptblock stored as $Script:Repair_Hardware.

    Hardware repair policy:
        DiagnoseOnly — Invoke-ModuleLifecycle does not call this block.
        SafeRepair   — Advisory records + PawnIO driver install if needed.
        FullRepair   — Same as SafeRepair.

    Rationale:
        Hardware-level changes (firmware updates, BIOS configuration,
        fan control, drive replacement) require physical access or
        manufacturer tools and must never be automated without explicit
        user confirmation and vendor procedures. V1 generates clear
        actionable guidance instead.

    PawnIO install:
        If SensorBridge ran but returned 0 CPU temperature sensors and
        Tools\PawnIO\PawnIO_setup.exe is present, the installer is run
        silently with -install -silent.  Requires Administrator privileges.
        SensorBridge is retried after a successful install.  All failures
        are non-fatal — the module continues and reports the outcome.

    Output:
        ActionsTaken records describe what was done or advise the technician.
        Advisory records: Action="Advisory", Success=$true, Detail=recommendation.
        PawnIO records:   Action="PawnIO-Install", Success=<bool>, Detail=outcome.

.VERSION 1.1
#>

$Script:Repair_Hardware = {
    param($Result, $State)

    Push-LogMessage -State $State `
        -Message "  Hardware module is advisory-only — no hardware changes are performed." `
        -Type "info"

    # Generate one advisory ActionsTaken record per actionable finding.
    # Findings with severity warn/error/critical produce a concrete recommendation.
    $advisoryMap = @{
        "SMART FAILURE"                      = "URGENT: Back up all data immediately and replace the failing drive. Do not delay."
        "SMART Warning"                      = "Back up all data from this drive and plan replacement. Monitor health daily."
        "Critical: Drive"                    = "Immediately free space: run Temp Cleanup, uninstall unused software, or extend the volume."
        "Low Disk Space"                     = "Free space: clean temp files (run Temp Cleanup module), empty Recycle Bin, or remove unused applications."
        "Disk Space Warning"                 = "Monitor disk space and schedule a cleanup. Aim to keep drives below 70% usage."
        "Critical RAM Usage"                 = "Close unused applications now. If persistent, consider upgrading installed RAM."
        "High RAM Usage"                     = "Close unused background applications. Check Task Manager > Processes sorted by Memory."
        "High CPU Load"                      = "Open Task Manager > Processes sorted by CPU. Identify and address high-load processes."
        "CPU Information"                    = "Check Device Manager for CPU driver errors. Run a Windows repair scan (SFC module)."
        "RAM Usage Data"                     = "Run the SFC and DISM modules to check OS integrity. Verify WMI service is running."
        "Disk Inventory"                     = "Run chkdsk (CHKDSK module) and verify disk drivers are healthy in Device Manager."
        # Temperature advisories
        "Critical CPU Temperature"           = "Power off and allow the system to cool. Inspect CPU cooler mounting pressure, thermal paste condition, and case airflow before restarting. Clean dust from heatsink and fan."
        "High CPU Temperature"               = "Check CPU cooler seating and thermal paste (replace if over 3–4 years old). Ensure case fans are working and that airflow paths are unobstructed."
        "Elevated CPU Temperature"           = "Clean dust from CPU heatsink fins and fan. Verify the CPU cooler fan is spinning at rated speed. Consider adding a case exhaust fan."
        "Critical Drive Temperature"         = "Ensure the drive has direct airflow from a case fan. If temperature does not improve, consider relocating or replacing the drive."
        "High Drive Temperature"             = "Improve airflow across storage drives. Check that a case fan is directed toward the drive bay."
        "Low Fan Speed"                      = "Check that the fan cable is firmly seated. Inspect fan blades for obstructions. Replace fan if consistently below rated RPM."
        "Temperature Sensor Data"            = "Install LibreHardwareMonitor (free, https://github.com/LibreHardwareMonitor) for detailed CPU, GPU, and drive temperature monitoring."
        "CPU Temperature Sensor Not Matched" = "Open LibreHardwareMonitor and confirm that CPU temperature sensors are listed and showing valid values. Ensure LHM is running with Administrator rights. If sensors still do not appear, check for LHM updates that add support for your CPU model."
        # Battery advisories
        "Battery Severely Degraded"          = "Replace the battery as soon as practical. A battery retaining less than 60% capacity risks sudden power loss. Contact your device manufacturer or a reputable repair shop for a compatible replacement."
        "Battery Degraded"                   = "Monitor battery run time. If portable use is important, plan for battery replacement. Look up the battery model for your device and obtain a replacement from the manufacturer or a trusted supplier."
    }

    $advisoriesAdded = 0

    foreach ($finding in $Result.Findings) {
        $sev = $finding.Severity.ToLower()
        if ($sev -notin @("warn", "error", "critical")) { continue }

        # Match the finding title against advisory patterns
        $advice = $null
        foreach ($pattern in $advisoryMap.Keys) {
            if ($finding.Title -like "*$pattern*") {
                $advice = $advisoryMap[$pattern]
                break
            }
        }
        # Fall back to the finding's own recommendation if no pattern matched
        if (-not $advice) { $advice = $finding.Description }

        $Result.ActionsTaken.Add((New-ActionRecord `
            -Action  "Advisory" `
            -Target  $finding.Title `
            -Success $true `
            -Detail  $advice))

        Push-LogMessage -State $State -Message "  Advisory: $advice" -Type "info"
        $advisoriesAdded++
    }

    if ($advisoriesAdded -eq 0) {
        $Result.ActionsTaken.Add((New-ActionRecord `
            -Action  "Advisory" `
            -Target  "Hardware" `
            -Success $true `
            -Detail  "No hardware concerns detected. No action required at this time."))
        Push-LogMessage -State $State -Message "  No hardware advisories — all checks passed." -Type "ok"
    }

    # ============================================================
    #  PAWNIO DRIVER INSTALL  (SafeRepair / FullRepair only)
    #  Installs PawnIO when SensorBridge ran but returned no CPU temps.
    #  Lifecycle guarantees this block is never reached in DiagnoseOnly.
    #  Admin check is explicit because kernel driver install requires it.
    # ============================================================
    $d = $Result.Data

    $sbRanOk     = [bool]$d["SensorBridgeRanOk"]
    $sbTempCount = [int]$d["SensorBridgeTempCount"]
    $pawnDetected = [bool]$d["PawnIODetected"]
    $setupPath    = $d["PawnIOSetupPath"]
    $bridgePath   = $d["SensorBridgePath"]

    $pawnInstallAttempted = $false
    $pawnInstallSuccess   = $false
    $pawnInstallResult    = $null

    # Condition: bridge ran cleanly, returned 0 CPU temps, PawnIO not already present
    $needsPawnIO = $sbRanOk -and ($sbTempCount -eq 0) -and (-not $pawnDetected)

    if ($needsPawnIO -and $setupPath -and (Test-Path $setupPath -PathType Leaf -ErrorAction SilentlyContinue)) {

        # Kernel driver installation requires Administrator privileges
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            Push-LogMessage -State $State `
                -Message "  PawnIO: install skipped — Administrator privileges required for kernel driver installation." `
                -Type "info"
            $pawnInstallResult = "Skipped — not running as Administrator."
        } else {
            Push-LogMessage -State $State `
                -Message "  PawnIO: installing from '$setupPath' (-install -silent)..." -Type "info"
            $pawnInstallAttempted = $true

            try {
                $installProc = [System.Diagnostics.Process]::new()
                $installProc.StartInfo.FileName               = $setupPath
                $installProc.StartInfo.Arguments              = "-install -silent"
                $installProc.StartInfo.UseShellExecute        = $false
                $installProc.StartInfo.CreateNoWindow         = $true
                $installProc.StartInfo.RedirectStandardOutput = $true
                $installProc.StartInfo.RedirectStandardError  = $true
                [void]$installProc.Start()
                [void]$installProc.StandardOutput.ReadToEnd()
                [void]$installProc.StandardError.ReadToEnd()
                $timedOut = -not $installProc.WaitForExit(30000)   # 30 s hard limit

                if ($timedOut) {
                    try { $installProc.Kill() } catch { }
                    $pawnInstallResult = "Install timed out after 30 seconds."
                    Push-LogMessage -State $State -Message "  PawnIO: install timed out." -Type "warn"
                } else {
                    $exitCode = $installProc.ExitCode
                    if ($exitCode -eq 0) {
                        $pawnInstallSuccess = $true
                        $pawnInstallResult  = "Installed successfully (exit 0)."
                        Push-LogMessage -State $State -Message "  PawnIO: install succeeded." -Type "ok"
                    } else {
                        $pawnInstallResult = "Install failed — exit code ${exitCode}."
                        Push-LogMessage -State $State `
                            -Message "  PawnIO: install failed (exit ${exitCode})." -Type "warn"
                    }
                }
            } catch {
                $pawnInstallResult = "Install exception: $($_.Exception.Message)"
                Push-LogMessage -State $State `
                    -Message "  PawnIO: install exception — $($_.Exception.Message)" -Type "warn"
            }

            # ── Retry SensorBridge after successful PawnIO install ────────────
            if ($pawnInstallSuccess -and $bridgePath -and (Test-Path $bridgePath -PathType Leaf -ErrorAction SilentlyContinue)) {
                Push-LogMessage -State $State `
                    -Message "  PawnIO: retrying SensorBridge to confirm CPU sensor access..." -Type "info"
                try {
                    $retryProc = [System.Diagnostics.Process]::new()
                    $retryProc.StartInfo.FileName               = $bridgePath
                    $retryProc.StartInfo.RedirectStandardOutput = $true
                    $retryProc.StartInfo.RedirectStandardError  = $true
                    $retryProc.StartInfo.UseShellExecute        = $false
                    $retryProc.StartInfo.CreateNoWindow         = $true
                    $retryProc.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
                    [void]$retryProc.Start()
                    $retryJson = $retryProc.StandardOutput.ReadToEnd()
                    [void]$retryProc.StandardError.ReadToEnd()
                    $retryTO = -not $retryProc.WaitForExit(8000)

                    if (-not $retryTO -and $retryProc.ExitCode -eq 0 -and $retryJson) {
                        $retryData = $retryJson | ConvertFrom-Json -ErrorAction SilentlyContinue
                        if ($retryData -and -not $retryData.error) {
                            $retryCpuCount = @($retryData.temperatures | Where-Object {
                                "$($_.name)" -match "CPU|Core|Package|Tdie|Tctl"
                            }).Count

                            if ($retryCpuCount -gt 0) {
                                Push-LogMessage -State $State `
                                    -Message "  PawnIO: SensorBridge retry found ${retryCpuCount} CPU sensor(s) — driver active." `
                                    -Type "ok"
                                $pawnInstallResult += " Retry: ${retryCpuCount} CPU sensor(s) now available."
                                # Update Data so Export/HTML reflect the improved state
                                $d["SensorBridgeRanOk"]          = $true
                                $d["SensorBridgeTempCount"]       = $retryCpuCount
                                $d["CpuTempUnavailableReason"]    = $null
                            } else {
                                Push-LogMessage -State $State `
                                    -Message "  PawnIO: SensorBridge retry still returned 0 CPU sensors — reboot may be required." `
                                    -Type "info"
                                $pawnInstallResult += " Retry: 0 CPU sensors — reboot may be required to activate driver."
                            }
                        }
                    }
                } catch {
                    Push-LogMessage -State $State `
                        -Message "  PawnIO: SensorBridge retry failed — $($_.Exception.Message)" -Type "info"
                }
            }
        }

    } elseif ($needsPawnIO -and $setupPath) {
        Push-LogMessage -State $State `
            -Message "  PawnIO: setup not found at '$setupPath' — install skipped." -Type "info"
        $pawnInstallResult = "Setup not found at expected path."
    } else {
        Push-LogMessage -State $State -Message "  PawnIO: install not required." -Type "info"
    }

    if ($pawnInstallAttempted) {
        $Result.ActionsTaken.Add((New-ActionRecord `
            -Action  "PawnIO-Install" `
            -Target  "PawnIO_setup.exe" `
            -Success $pawnInstallSuccess `
            -Detail  $pawnInstallResult))
    }

    # Store outcomes for Export phase
    $d["PawnIOInstallAttempted"] = $pawnInstallAttempted
    $d["PawnIOInstallSuccess"]   = $pawnInstallSuccess
    $d["PawnIOInstallResult"]    = $pawnInstallResult
}
