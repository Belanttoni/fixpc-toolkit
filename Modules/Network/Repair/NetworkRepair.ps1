<#
.SYNOPSIS
    FixPC Toolkit — Network Module: Repair Phase
    Mode-gated network repair actions.
    Scriptblock stored as $Script:Repair_Network.

    SafeRepair:
        - DNS cache flush       (ipconfig /flushdns)
        - IP lease renewal      (ipconfig /release + /renew) — only on DHCP failure
        - Adapter restart       (Disable-NetAdapter + Enable-NetAdapter) — only on DHCP failure

    FullRepair:
        All SafeRepair actions, plus:
        - Winsock catalog reset (netsh winsock reset) — requires reboot
        - TCP/IP stack reset    (netsh int ip reset)  — requires reboot

    Execution mode is read from $Result.ExecutionMode (set by Invoke-ModuleLifecycle).
    DiagnoseOnly: Invoke-ModuleLifecycle never calls this block.

.VERSION 1.0
#>

$Script:Repair_Network = {
    param($Result, $State)

    $mode      = $Result.ExecutionMode
    $d         = $Result.Data
    $apipa     = $d["ApipaDetected"]
    $noIP      = (-not $d["LocalIP"]) -or $apipa
    $loopFail  = -not $d["LoopbackOk"]
    $adapter   = $d["AdapterName"]

    # ============================================================
    #  SAFE REPAIR
    # ============================================================

    # ── DNS cache flush ───────────────────────────────────────
    # Always safe — clears stale DNS entries, costs nothing.
    Push-LogMessage -State $State -Message "  Flushing DNS cache..." -Type "info"
    try {
        & ipconfig /flushdns 2>&1 | Out-Null
        $Result.ActionsTaken.Add((New-ActionRecord -Action "ipconfig /flushdns" -Target "DNS Cache" `
            -Success $true -Detail "DNS resolver cache cleared."))
        Push-LogMessage -State $State -Message "  DNS cache flushed." -Type "ok"
    } catch {
        $Result.ActionsTaken.Add((New-ActionRecord -Action "ipconfig /flushdns" -Target "DNS Cache" `
            -Success $false -ErrorDetail $_))
        Push-LogMessage -State $State -Message "  DNS flush failed: $_" -Type "warn"
    }

    # ── IP lease renewal ─────────────────────────────────────
    # Only attempt if DHCP issue detected (APIPA or no IP).
    if ($noIP -and $adapter) {
        Push-LogMessage -State $State -Message "  DHCP issue detected — attempting IP lease renewal..." -Type "info"
        try {
            & ipconfig /release 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            & ipconfig /renew 2>&1 | Out-Null
            $Result.ActionsTaken.Add((New-ActionRecord -Action "ipconfig /release+/renew" -Target $adapter `
                -Success $true -Detail "DHCP lease renewal attempted on '$adapter'."))
            Push-LogMessage -State $State -Message "  IP lease renewal completed on '$adapter'." -Type "ok"
        } catch {
            $Result.ActionsTaken.Add((New-ActionRecord -Action "ipconfig /release+/renew" -Target $adapter `
                -Success $false -ErrorDetail $_))
            Push-LogMessage -State $State -Message "  IP renewal failed: $_" -Type "warn"
        }
    }

    # ── Adapter restart ───────────────────────────────────────
    # Cycle the adapter if DHCP issue persists and adapter name is known.
    # Disable-NetAdapter / Enable-NetAdapter require admin — which we have.
    if ($noIP -and $adapter) {
        Push-LogMessage -State $State -Message "  Restarting adapter '$adapter'..." -Type "info"
        try {
            Disable-NetAdapter -Name $adapter -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 3
            Enable-NetAdapter  -Name $adapter -Confirm:$false -ErrorAction Stop
            $Result.ActionsTaken.Add((New-ActionRecord -Action "Restart-NetAdapter" -Target $adapter `
                -Success $true -Detail "Adapter disabled and re-enabled to force DHCP re-negotiation."))
            Push-LogMessage -State $State -Message "  Adapter '$adapter' restarted." -Type "ok"
        } catch {
            $Result.ActionsTaken.Add((New-ActionRecord -Action "Restart-NetAdapter" -Target $adapter `
                -Success $false -ErrorDetail $_))
            Push-LogMessage -State $State -Message "  Adapter restart failed: $_" -Type "warn"
        }
    }

    # ============================================================
    #  FULL REPAIR
    # ============================================================
    if ($mode -eq [ExecutionMode]::FullRepair) {

        # ── Winsock catalog reset ─────────────────────────────
        # Restores the Winsock LSP catalog to default state.
        # Required when loopback fails or sockets are corrupted.
        Push-LogMessage -State $State -Message "  Resetting Winsock catalog (netsh winsock reset)..." -Type "info"
        try {
            $out = & netsh winsock reset 2>&1 | Out-String
            $ok  = $out -match "successfully reset" -or $out -match "The Winsock Catalog"
            $Result.ActionsTaken.Add((New-ActionRecord -Action "netsh winsock reset" `
                -Target "Winsock Catalog" -Success $ok `
                -Detail "Winsock catalog reset. Reboot required to complete."))
            $Result.Data["RebootRequired"] = $true
            Push-LogMessage -State $State -Message "  Winsock reset complete — REBOOT REQUIRED." -Type "warn"
        } catch {
            $Result.ActionsTaken.Add((New-ActionRecord -Action "netsh winsock reset" `
                -Target "Winsock Catalog" -Success $false -ErrorDetail $_))
            Push-LogMessage -State $State -Message "  Winsock reset failed: $_" -Type "warn"
        }

        # ── TCP/IP stack reset ────────────────────────────────
        # Rewrites TCP/IP registry keys from scratch.
        # Resolves persistent IP assignment and stack corruption issues.
        Push-LogMessage -State $State -Message "  Resetting TCP/IP stack (netsh int ip reset)..." -Type "info"
        try {
            $logPath = "$env:TEMP\netsh_ipreset.log"
            $out = & netsh int ip reset $logPath 2>&1 | Out-String
            $ok  = $out -notmatch "Access is denied" -and ($out -match "Resetting" -or $out -match "OK")
            $Result.ActionsTaken.Add((New-ActionRecord -Action "netsh int ip reset" `
                -Target "TCP/IP Stack" -Success $ok `
                -Detail "TCP/IP stack reset. Log: $logPath. Reboot required to complete."))
            $Result.Data["RebootRequired"] = $true
            Push-LogMessage -State $State -Message "  TCP/IP stack reset complete — REBOOT REQUIRED." -Type "warn"
        } catch {
            $Result.ActionsTaken.Add((New-ActionRecord -Action "netsh int ip reset" `
                -Target "TCP/IP Stack" -Success $false -ErrorDetail $_))
            Push-LogMessage -State $State -Message "  TCP/IP reset failed: $_" -Type "warn"
        }

        # ── Update findings if stack reset ran ────────────────
        if ($loopFail -and $Result.Findings.Count -gt 0) {
            $Result.Findings[0].Repaired     = $true
            $Result.Findings[0].RepairAction = "netsh winsock reset + netsh int ip reset applied. Reboot to confirm."
        }

        if ($Result.Data["RebootRequired"]) {
            $Result.Warnings.Add("A system reboot is required to complete network stack repairs.")
            Push-LogMessage -State $State -Message "  REBOOT REQUIRED to finalise network repairs." -Type "warn"
        }
    }
}
