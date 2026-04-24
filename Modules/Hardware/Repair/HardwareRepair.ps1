<#
.SYNOPSIS
    FixPC Toolkit — Hardware Module: Repair Phase
    Advisory-only — no hardware state is modified.
    Scriptblock stored as $Script:Repair_Hardware.

    Hardware V1 repair policy:
        DiagnoseOnly — Invoke-ModuleLifecycle does not call this block.
        SafeRepair   — Advisory records only. No hardware changes.
        FullRepair   — Advisory records only. No firmware or invasive actions.

    Rationale:
        Hardware-level changes (firmware updates, BIOS configuration,
        fan control, drive replacement) require physical access or
        manufacturer tools and must never be automated without explicit
        user confirmation and vendor procedures. V1 generates clear
        actionable guidance instead.

    Output:
        ActionsTaken records describe what a technician or user should do.
        Each record Action="Advisory", Success=$true, Detail=recommendation.

.VERSION 1.0
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
}
