<#
.SYNOPSIS
    FixPC Toolkit — Network Module: Repair Phase
    Root-cause-targeted network repair actions.
    Scriptblock stored as $Script:Repair_Network.

    Action tiers (least invasive first):
        Tier 1 — DNS flush (ipconfig /flushdns)
                  Always safe.  Applied for all cause codes except NoAdapter,
                  AdapterDown, and StackCorrupted where DNS is irrelevant.

        Tier 2 — DHCP release + renew (ipconfig /release + /renew)
                  Applied when ProbableCauseCode is APIPA or NoIP and the
                  adapter is DHCP-configured.  Scoped globally; adapter-specific
                  syntax is unreliable across locales and adapter name formats.

        Tier 3 — Primary adapter restart (Disable-NetAdapter / Enable-NetAdapter)
                  Applied when APIPA, NoIP, GatewayUnreachable, or NoInternet.
                  Targets ONLY $d["AdapterName"] — the single adapter selected by
                  Collect based on gateway priority.  No blanket adapter cycling.

        Tier 4 — TCP/IP stack reset (netsh winsock reset + netsh int ip reset)
                  FullRepair only.  Applied when StackCorrupted, or as escalation
                  for persistent GatewayUnreachable / NoInternet after Tier 1-3.
                  Requires a system reboot to take effect.

    ProbableCauseCode → tiers applied:
        DNSFailure          → T1
        APIPA               → T1 + T2 + T3
        NoIP (DHCP)         → T1 + T2 + T3
        NoIP (static)       → T1 + T3 + advisory
        GatewayUnreachable  → T1 + T3; T4 in FullRepair
        NoInternet          → T1 + T3; T4 in FullRepair
        StackCorrupted      → T4 (FullRepair only)
        NoAdapter           → advisory only  (driver reinstall required)
        AdapterDown         → advisory only  (physical connection required)
        Healthy / IcmpBlocked → T1 only (maintenance flush)

    Rules:
        - Adapter restart targets only $d["AdapterName"] — not all adapters
        - No proxy, firewall, Wi-Fi profile, or registry changes
        - ipconfig /release and /renew are always global (adapter-specific form
          is locale-dependent and unreliable; adapter restart provides specificity)
        - ExecutionMode: DiagnoseOnly = no repair; SafeRepair = T1-T3; FullRepair = T1-T4

    Output:
        $Result.ActionsTaken            — repair records (New-ActionRecord)
        $Result.Data["RebootRequired"]  — bool: reboot needed after stack reset
        $Result.Data["RepairAttempted"] — bool: at least one action was executed

.VERSION 1.1
#>

$Script:Repair_Network = {
    param($Result, $State)

    $mode         = $Result.ExecutionMode
    $d            = $Result.Data
    $causeCode    = $d["ProbableCauseCode"]
    $adapter      = $d["AdapterName"]          # primary selected adapter (Collect's choice)
    $isDhcp       = [bool]$d["IsDhcp"]
    $apipaOnPrim  = [bool]$d["ApipaOnPrimary"] # APIPA only on the selected primary adapter
    $loopFail     = -not [bool]$d["LoopbackOk"]

    Push-LogMessage -State $State `
        -Message "  Network Repair — ProbableCause: $causeCode | Adapter: $(if ($adapter) { $adapter } else { 'none' })" `
        -Type "info"

    # Derived condition flags based on authoritative ProbableCauseCode
    $hasDnsIssue     = $causeCode -eq "DNSFailure"
    $hasDhcpIssue    = $causeCode -in @("APIPA", "NoIP") -and $isDhcp
    $hasNoIpStatic   = $causeCode -eq "NoIP" -and -not $isDhcp
    $hasNoIpAny      = $causeCode -in @("APIPA", "NoIP")
    $hasGwIssue      = $causeCode -eq "GatewayUnreachable"
    $hasInternetIssue= $causeCode -eq "NoInternet"
    $hasStackIssue   = $causeCode -eq "StackCorrupted"
    $hasAdapterIssue = $causeCode -eq "AdapterDown"

    # Repair tiers that apply to this run
    $doTier1 = $causeCode -notin @("NoAdapter", "AdapterDown", "StackCorrupted")
    $doTier2 = $hasDhcpIssue -and $adapter
    $doTier3 = ($hasNoIpAny -or $hasGwIssue -or $hasInternetIssue) -and $adapter
    # Tier 4 is evaluated inside the FullRepair block below

    $repairAttempted = $false

    # ============================================================
    #  TIER 1 — DNS resolver cache flush
    #  Always safe.  Clears stale records that can cause DNS failures,
    #  negative caching of expired entries, and connectivity confusion
    #  after network reconfiguration.
    # ============================================================
    if ($doTier1) {
        Push-LogMessage -State $State -Message "  [T1] Flushing DNS resolver cache..." -Type "info"
        try {
            & ipconfig /flushdns 2>&1 | Out-Null
            $Result.ActionsTaken.Add((New-ActionRecord `
                -Action  "ipconfig /flushdns" `
                -Target  "DNS Cache" `
                -Success $true `
                -Detail  "DNS resolver cache flushed successfully."))
            Push-LogMessage -State $State -Message "  DNS cache flushed." -Type "ok"
            $repairAttempted = $true
        } catch {
            $Result.ActionsTaken.Add((New-ActionRecord `
                -Action     "ipconfig /flushdns" `
                -Target     "DNS Cache" `
                -Success    $false `
                -ErrorDetail $_))
            Push-LogMessage -State $State -Message "  DNS flush failed: $_" -Type "warn"
        }
    }

    # ============================================================
    #  TIER 2 — DHCP release + renew
    #  Applied when the primary adapter is DHCP-configured and has
    #  no valid lease (APIPA or missing IP).  Uses global release/renew
    #  (not adapter-specific) for locale and name-format compatibility.
    # ============================================================
    if ($doTier2) {
        Push-LogMessage -State $State `
            -Message "  [T2] DHCP issue detected — releasing and renewing lease..." -Type "info"
        try {
            & ipconfig /release 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            & ipconfig /renew  2>&1 | Out-Null
            $Result.ActionsTaken.Add((New-ActionRecord `
                -Action  "ipconfig /release+renew" `
                -Target  $adapter `
                -Success $true `
                -Detail  "DHCP lease released and renewal requested (global). Adapter: '$adapter'."))
            Push-LogMessage -State $State `
                -Message "  DHCP lease renewal completed." -Type "ok"
            $repairAttempted = $true
        } catch {
            $Result.ActionsTaken.Add((New-ActionRecord `
                -Action     "ipconfig /release+renew" `
                -Target     $adapter `
                -Success    $false `
                -ErrorDetail $_))
            Push-LogMessage -State $State -Message "  DHCP renew failed: $_" -Type "warn"
        }
    }

    # Static IP with no address — advisory, no automated fix
    if ($hasNoIpStatic -and $adapter) {
        $Result.ActionsTaken.Add((New-ActionRecord `
            -Action  "Advisory" `
            -Target  $adapter `
            -Success $true `
            -Detail  "No static IP is configured on '$adapter'. Assign an IPv4 address via Network Connections or contact your network administrator."))
        Push-LogMessage -State $State `
            -Message "  Advisory: no static IP on '$adapter' — manual configuration required." `
            -Type "info"
    }

    # ============================================================
    #  TIER 3 — Primary adapter restart
    #  Cycles the single selected primary adapter to force hardware
    #  re-negotiation, a fresh DHCP request, and link re-establishment.
    #  Targeting is explicit: only $d["AdapterName"] is touched.
    #  All other adapters (TAP, VPN, secondary NICs) are left alone.
    # ============================================================
    if ($doTier3) {
        Push-LogMessage -State $State `
            -Message "  [T3] Restarting primary adapter '$adapter'..." -Type "info"
        try {
            Disable-NetAdapter -Name $adapter -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 4
            Enable-NetAdapter  -Name $adapter -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 3   # brief settle time for DHCP negotiation to begin
            $Result.ActionsTaken.Add((New-ActionRecord `
                -Action  "Restart-NetAdapter" `
                -Target  $adapter `
                -Success $true `
                -Detail  "Adapter '$adapter' disabled and re-enabled to force hardware re-negotiation."))
            Push-LogMessage -State $State `
                -Message "  Adapter '$adapter' restarted successfully." -Type "ok"
            $repairAttempted = $true
        } catch {
            $Result.ActionsTaken.Add((New-ActionRecord `
                -Action     "Restart-NetAdapter" `
                -Target     $adapter `
                -Success    $false `
                -ErrorDetail $_))
            Push-LogMessage -State $State `
                -Message "  Adapter restart failed: $_" -Type "warn"
        }
    }

    # ============================================================
    #  ADVISORY ONLY — AdapterDown  (physical fix required)
    # ============================================================
    if ($hasAdapterIssue) {
        $Result.ActionsTaken.Add((New-ActionRecord `
            -Action  "Advisory" `
            -Target  "Network Adapter" `
            -Success $true `
            -Detail  "No active adapter found. Check the physical cable or Wi-Fi connection and verify the adapter is enabled in Network Connections."))
        Push-LogMessage -State $State `
            -Message "  Advisory: adapter down — physical connection or driver fix required." `
            -Type "info"
    }

    # ============================================================
    #  TIER 4 — TCP/IP stack reset  (FullRepair only)
    #  Applied for StackCorrupted, or as escalation when GW/Internet
    #  issues persist after Tiers 1–3 have already run.
    #  Both Winsock catalog reset and TCP/IP stack reset require reboot.
    # ============================================================
    if ($mode -eq [ExecutionMode]::FullRepair) {

        $doTier4 = $hasStackIssue -or
                   (($hasGwIssue -or $hasInternetIssue) -and $repairAttempted)

        if ($doTier4) {

            # ── Winsock catalog reset ─────────────────────────
            Push-LogMessage -State $State `
                -Message "  [T4] Resetting Winsock catalog (netsh winsock reset)..." -Type "info"
            try {
                $wsOut = & netsh winsock reset 2>&1 | Out-String
                $wsOk  = $wsOut -match "successfully reset" -or `
                         $wsOut -match "Winsock" -or `
                         $wsOut -match "completato"   # Italian locale
                $Result.ActionsTaken.Add((New-ActionRecord `
                    -Action  "netsh winsock reset" `
                    -Target  "Winsock Catalog" `
                    -Success $wsOk `
                    -Detail  "Winsock LSP catalog reset to defaults. Reboot required to complete."))
                $d["RebootRequired"] = $true
                Push-LogMessage -State $State `
                    -Message "  Winsock reset complete — REBOOT REQUIRED." -Type "warn"
                $repairAttempted = $true
            } catch {
                $Result.ActionsTaken.Add((New-ActionRecord `
                    -Action     "netsh winsock reset" `
                    -Target     "Winsock Catalog" `
                    -Success    $false `
                    -ErrorDetail $_))
                Push-LogMessage -State $State -Message "  Winsock reset failed: $_" -Type "warn"
            }

            # ── TCP/IP stack reset ────────────────────────────
            Push-LogMessage -State $State `
                -Message "  [T4] Resetting TCP/IP stack (netsh int ip reset)..." -Type "info"
            try {
                $logPath = "$env:TEMP\netsh_ipreset.log"
                $ipOut   = & netsh int ip reset $logPath 2>&1 | Out-String
                $ipOk    = $ipOut -notmatch "Access is denied" -and `
                           ($ipOut -match "Resetting" -or $ipOut -match "OK" -or `
                            $ipOut -match "Reimpostazione")   # Italian locale
                $Result.ActionsTaken.Add((New-ActionRecord `
                    -Action  "netsh int ip reset" `
                    -Target  "TCP/IP Stack" `
                    -Success $ipOk `
                    -Detail  "TCP/IP stack reset. Log written to: $logPath. Reboot required."))
                $d["RebootRequired"] = $true
                Push-LogMessage -State $State `
                    -Message "  TCP/IP stack reset complete — REBOOT REQUIRED." -Type "warn"
            } catch {
                $Result.ActionsTaken.Add((New-ActionRecord `
                    -Action     "netsh int ip reset" `
                    -Target     "TCP/IP Stack" `
                    -Success    $false `
                    -ErrorDetail $_))
                Push-LogMessage -State $State -Message "  TCP/IP reset failed: $_" -Type "warn"
            }

            # Mark StackCorrupted finding as repaired
            if ($hasStackIssue -and $Result.Findings.Count -gt 0) {
                $Result.Findings[0].Repaired     = $true
                $Result.Findings[0].RepairAction = "netsh winsock reset + netsh int ip reset applied. Reboot to confirm."
            }
        }

        if ($d["RebootRequired"]) {
            $Result.Warnings.Add("A system reboot is required to complete network stack repairs.")
            Push-LogMessage -State $State `
                -Message "  REBOOT REQUIRED to finalise all network repairs." -Type "warn"
        }
    }

    # ============================================================
    #  RECORD REPAIR STATE
    # ============================================================
    $d["RepairAttempted"] = $repairAttempted

    $actionCount = $Result.ActionsTaken.Count
    if ($repairAttempted) {
        Push-LogMessage -State $State `
            -Message "  Repair complete — $actionCount action(s) recorded." -Type "ok"
    } else {
        Push-LogMessage -State $State `
            -Message "  No automated repair actions apply for cause: $causeCode" -Type "info"
    }
}
