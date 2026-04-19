<#
.SYNOPSIS
    FixPC Toolkit — System Module: Repair Phase
    Repair scriptblocks for sub-modules that support automated remediation.
    Scriptblocks are stored as Script-scope variables and consumed by SystemModule.ps1.

    Naming convention: $Script:Repair_<SubModuleId>

    Sub-modules without a repair phase (sysinfo, events, startup, smart)
    are not listed here — they pass $null for RepairBlock in Invoke-ModuleLifecycle.

.VERSION 1.0
#>

# ============================================================
#  REPAIR — chkdsk  (SpotFix — no reboot required)
# ============================================================
$Script:Repair_ChkDsk = {
    param($Result, $State)
    $scan = $Result.Data["ScanOutput"]

    # Only apply SpotFix if errors were found AND no bad sectors
    if (($scan -match "found problems" -or $scan -match "errors found") -and $scan -notmatch "bad sector") {
        Push-LogMessage -State $State -Message "  Applying /spotfix (no reboot needed)..." -Type "info"
        $fixOut = & chkdsk C: /spotfix /x 2>&1 | Out-String
        $Result.Data["SpotFixOutput"] = $fixOut

        if ($fixOut -match "corrections" -or $fixOut -match "no further action") {
            $action = New-ActionRecord -Action "chkdsk /spotfix" -Target "C:" -Success $true `
                -Detail "File system errors repaired via SpotFix. No reboot required."
            $Result.ActionsTaken.Add($action)
            $Result.Findings[0].Repaired     = $true
            $Result.Findings[0].RepairAction = "chkdsk /spotfix applied successfully"
            Push-LogMessage -State $State -Message "  SpotFix applied — errors repaired, no reboot needed." -Type "ok"
        } else {
            $action = New-ActionRecord -Action "chkdsk /spotfix" -Target "C:" -Success $false `
                -Detail "SpotFix result inconclusive."
            $Result.ActionsTaken.Add($action)
            Push-LogMessage -State $State -Message "  SpotFix completed — verify results." -Type "warn"
        }
    }
}

# ============================================================
#  REPAIR — temp  (Delete temp folder contents)
# ============================================================
$Script:Repair_Temp = {
    param($Result, $State)
    $inventory  = $Result.Data["PathInventory"]
    $totalFreed = 0L

    foreach ($path in $inventory.Keys) {
        $isWuPath = ($path -like "*SoftwareDistribution*")

        if ($isWuPath) {
            try { Stop-Service wuauserv -Force -ErrorAction SilentlyContinue } catch {}
        }

        try {
            $freed = Remove-FolderContents -Path $path
            $totalFreed += $freed
            $freedMB = [math]::Round($freed / 1MB, 1)
            if ($freedMB -gt 0) {
                Push-LogMessage -State $State -Message "  Cleared: $path ($freedMB MB)" -Type "ok"
                $Result.ActionsTaken.Add((New-ActionRecord -Action "Remove-FolderContents" -Target $path `
                    -Success $true -Detail "$freedMB MB freed"))
            }
        } catch {
            Push-LogMessage -State $State -Message "  Skipped: $path" -Type "info"
            $Result.ActionsTaken.Add((New-ActionRecord -Action "Remove-FolderContents" -Target $path `
                -Success $false -ErrorDetail $_))
        } finally {
            if ($isWuPath) {
                try { Start-Service wuauserv -ErrorAction SilentlyContinue } catch {}
            }
        }
    }

    $totalFreedMB = [math]::Round($totalFreed / 1MB, 1)
    $Result.Data["FreedBytes"] = $totalFreed
    Push-LogMessage -State $State -Message "  Total freed: $totalFreedMB MB" -Type "ok"
}

# ============================================================
#  REPAIR — winupdate  (Install pending updates)
# ============================================================
$Script:Repair_WinUpdate = {
    param($Result, $State)
    $cnt = $Result.Data["PendingCount"]
    if ($cnt -le 0) { return }

    Push-LogMessage -State $State -Message "  Installing $cnt updates..." -Type "info"
    try {
        $sess         = $Result.Data["Session"]
        $res          = $Result.Data["SearchResult"]
        $col          = New-Object -ComObject Microsoft.Update.UpdateColl
        for ($i = 0; $i -lt $cnt; $i++) { $col.Add($res.Updates.Item($i)) | Out-Null }
        $inst         = $sess.CreateUpdateInstaller()
        $inst.Updates = $col
        $r            = $inst.Install()

        $action = New-ActionRecord -Action "Install-WindowsUpdates" -Target "Windows Update" `
            -Success $true -Detail "$cnt updates installed. Result code: $($r.ResultCode)"
        $Result.ActionsTaken.Add($action)

        if ($r.RebootRequired) {
            $Result.Warnings.Add("Reboot required after Windows Update installation.")
            Push-LogMessage -State $State -Message "  Updates installed. REBOOT REQUIRED." -Type "warn"
        } else {
            Push-LogMessage -State $State -Message "  $cnt updates installed successfully." -Type "ok"
        }
        $Result.Data["RebootRequired"] = $r.RebootRequired
    } catch {
        $Result.Errors.Add("Update installation failed: $_")
        Push-LogMessage -State $State -Message "  Update installation failed: $_" -Type "error"
    } finally {
        # Release COM objects — they are apartment-threaded and must not persist
        # in $State.Results after the workflow runspace completes.
        $Result.Data["Session"]      = $null
        $Result.Data["SearchResult"] = $null
    }
}

# ============================================================
#  REPAIR — ram  (Schedule Windows Memory Diagnostic)
# ============================================================
$Script:Repair_Ram = {
    param($Result, $State)
    # Schedule memory diagnostic if errors found — does NOT reboot immediately
    if ($Result.Data["ErrorCount"] -gt 0) {
        try {
            & mdsched /f 2>&1 | Out-Null
            $action = New-ActionRecord -Action "mdsched /f" -Target "RAM" -Success $true `
                -Detail "Windows Memory Diagnostic scheduled for next reboot."
            $Result.ActionsTaken.Add($action)
            $Result.Warnings.Add("Memory Diagnostic scheduled — will run at next reboot.")
            Push-LogMessage -State $State -Message "  Memory Diagnostic scheduled for next reboot." -Type "warn"
        } catch {
            $Result.Errors.Add("Failed to schedule mdsched: $_")
        }
    }
}

# ============================================================
#  REPAIR — sfc  (sfc /scannow — repairs corrupted system files)
#  Triggered: SafeRepair and FullRepair only.
#  Skipped:   DiagnoseOnly (enforced by Invoke-ModuleLifecycle).
#  Condition: Only runs scannow if verifyonly detected issues.
# ============================================================
$Script:Repair_SFC = {
    param($Result, $State)
    $verifyOut = $Result.Data["VerifyOutput"]

    # Skip if verifyonly confirmed no violations — nothing to repair
    if ($verifyOut -match "did not find any integrity violations") {
        Push-LogMessage -State $State -Message "  sfc /scannow skipped — verifyonly found no violations." -Type "info"
        return
    }

    # Run repair scan
    Push-LogMessage -State $State -Message "  Running sfc /scannow (repair scan — this may take several minutes)..." -Type "info"
    $output = & sfc /scannow 2>&1 | Out-String
    $Result.Data["ScanOutput"] = $output

    if ($output -match "successfully repaired") {
        $action = New-ActionRecord -Action "sfc /scannow" -Target "System Files" -Success $true `
            -Detail "Corrupted system files were repaired."
        $Result.ActionsTaken.Add($action)
        if ($Result.Findings.Count -gt 0) {
            $Result.Findings[0].Repaired     = $true
            $Result.Findings[0].RepairAction = "sfc /scannow: corrupted files repaired"
        }
        Push-LogMessage -State $State -Message "  sfc /scannow: corrupted files repaired successfully." -Type "ok"
    } elseif ($output -match "did not find any integrity violations") {
        Push-LogMessage -State $State -Message "  sfc /scannow: no integrity violations found during repair scan." -Type "ok"
    } elseif ($output -match "unable to fix") {
        $action = New-ActionRecord -Action "sfc /scannow" -Target "System Files" -Success $false `
            -Detail "SFC could not repair all corrupted files. DISM /RestoreHealth may resolve remaining issues."
        $Result.ActionsTaken.Add($action)
        $Result.Warnings.Add("SFC could not repair all files. Run DISM /RestoreHealth (FullRepair mode).")
        Push-LogMessage -State $State -Message "  sfc /scannow: some files could not be repaired — DISM /RestoreHealth recommended." -Type "warn"
    } else {
        Push-LogMessage -State $State -Message "  sfc /scannow: completed — check CBS.log for details." -Type "warn"
    }
}

# ============================================================
#  REPAIR — dism
#  SafeRepair  → DISM /ScanHealth  (deep scan, non-mutating, confirms repairability)
#  FullRepair  → DISM /RestoreHealth (full repair via Windows Update — may take 15-45 min)
#  Triggered: SafeRepair and FullRepair only.
#  Skipped:   DiagnoseOnly (enforced by Invoke-ModuleLifecycle).
# ============================================================
$Script:Repair_DISM = {
    param($Result, $State)
    $mode = $Result.ExecutionMode

    if ($mode -eq [ExecutionMode]::SafeRepair) {
        # /ScanHealth is non-mutating but performs a thorough component store scan.
        # Placed here because it is time-intensive and users opt in via SafeRepair mode.
        Push-LogMessage -State $State -Message "  Running DISM /ScanHealth (deep scan — non-mutating)..." -Type "info"
        $out = & DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Out-String
        $Result.Data["ScanOutput"] = $out

        if ($out -match "No component store corruption detected") {
            # Update finding to reflect deeper confirmation
            if ($Result.Findings.Count -gt 0) {
                $Result.Findings[0].Description += " (confirmed by /ScanHealth)"
            }
            Push-LogMessage -State $State -Message "  DISM /ScanHealth: no corruption confirmed." -Type "ok"
        } elseif ($out -match "repairable" -or $out -match "Repairable") {
            $Result.Warnings.Add("DISM /ScanHealth confirmed repairable corruption. Run FullRepair to restore.")
            Push-LogMessage -State $State -Message "  DISM /ScanHealth: repairable corruption confirmed — run FullRepair for /RestoreHealth." -Type "warn"
        } else {
            Push-LogMessage -State $State -Message "  DISM /ScanHealth: completed — check dism.log." -Type "warn"
        }

    } elseif ($mode -eq [ExecutionMode]::FullRepair) {
        # /RestoreHealth sources replacement files from Windows Update — may take 15-45 min.
        # Appearing stuck at 62% is normal behaviour.
        Push-LogMessage -State $State -Message "  Running DISM /RestoreHealth (may take 15-45 min — normal to pause at 62%)..." -Type "info"
        $out = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
        $Result.Data["RestoreOutput"] = $out

        if ($out -match "completed successfully" -or $out -match "No component store corruption") {
            $action = New-ActionRecord -Action "DISM /RestoreHealth" -Target "Component Store" `
                -Success $true -Detail "Component store restored successfully."
            $Result.ActionsTaken.Add($action)
            if ($Result.Findings.Count -gt 0) {
                $Result.Findings[0].Repaired     = $true
                $Result.Findings[0].RepairAction = "DISM /RestoreHealth: component store restored"
            }
            Push-LogMessage -State $State -Message "  DISM /RestoreHealth: component store restored." -Type "ok"
        } elseif ($out -match "Error" -or $out -match "failed") {
            $action = New-ActionRecord -Action "DISM /RestoreHealth" -Target "Component Store" `
                -Success $false -Detail "DISM encountered errors during restoration. Check dism.log."
            $Result.ActionsTaken.Add($action)
            $Result.Warnings.Add("DISM /RestoreHealth encountered errors. Review dism.log.")
            Push-LogMessage -State $State -Message "  DISM /RestoreHealth: errors encountered — check dism.log." -Type "error"
        } else {
            Push-LogMessage -State $State -Message "  DISM /RestoreHealth: completed — check dism.log for details." -Type "warn"
        }
    }
}

Write-Verbose "[System.Repair] Repair phase scriptblocks loaded."
