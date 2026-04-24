<#
.SYNOPSIS
    FixPC Toolkit — Network Module: Analyze Phase
    Evidence-weighted layered network diagnostic evaluation.
    Scriptblock stored as $Script:Analyze_Network.

    Diagnostic model:
        Layer 1  — Adapter presence
        Layer 2  — Active adapter (at least one Up)
        Layer 3  — TCP/IP stack integrity (loopback 127.0.0.1)
        Layer 4  — IP address on primary adapter (no APIPA, no missing IP)
        Layer 5  — Gateway configured; ICMP failure is non-fatal if DNS confirms connectivity
        Layer 6  — Internet reachable; DNS and TCP are stronger signals than ICMP alone
        Layer 7  — DNS name resolution working
        All pass — Network fully operational

    ICMP vs evidence-based classification:
        Gateway and internet ICMP ping failures are common in environments where
        routers and ISPs filter ICMP.  The analysis uses DNS resolution and TCP 443
        as stronger signals.  If DNS resolves, the gateway is reachable and the internet
        is accessible — ICMP failure in that context is classified as IcmpBlocked,
        not a true connectivity outage.

    ProbableCauseCode values (stored in Data["ProbableCauseCode"]):
        NoAdapter          — no network adapter found or driver missing
        AdapterDown        — adapter(s) present but none are Up / connected
        StackCorrupted     — loopback (127.0.0.1) unreachable, TCP/IP stack damaged
        APIPA              — primary adapter has 169.254.x.x; DHCP lease failed on that adapter
        NoIP               — primary adapter is Up but has no IPv4 address
        NoGateway          — IP assigned but no default gateway configured, no DNS evidence
        GatewayUnreachable — gateway configured, ICMP failed, no DNS/TCP evidence of connectivity
        NoInternet         — gateway OK, no ICMP/DNS/TCP evidence of internet access
        IcmpBlocked        — ICMP filtered but DNS/TCP confirm connectivity (informational)
        DNSFailure         — internet reachable but hostname resolution failing
        Healthy            — all layers passed (may include IcmpBlocked note)

    Severity string model: "ok" | "info" | "warn" | "error" | "critical"

.VERSION 1.2
#>

$Script:Analyze_Network = {
    param($Result, $State)

    $d              = $Result.Data
    $adapterCount   = $d["AdapterCount"]
    $activeAdapters = @($d["ActiveAdapters"])
    $loopback       = $d["LoopbackOk"]
    $localIP        = $d["LocalIP"]
    $localIPOk      = $d["LocalIPOk"]
    $apipaOnPrimary = [bool]$d["ApipaOnPrimary"]   # APIPA on the selected adapter
    $apipaAny       = [bool]$d["ApipaDetected"]    # APIPA on any adapter (informational)
    $isDhcp         = $d["IsDhcp"]
    $gwOk           = $d["GatewayOk"]
    $gwLatency      = $d["GatewayLatencyMs"]
    $gateway        = $d["Gateway"]
    $intOk          = $d["InternetOk"]
    $intLatency     = $d["InternetLatencyMs"]
    $port443Ok      = $d["Port443Ok"]
    $dnsOk          = $d["DnsOk"]
    $dns            = @($d["DNSServers"])
    $adapterType    = if ($d["AdapterType"]) { $d["AdapterType"] } else { "adapter" }
    $ssid           = $d["SSID"]

    # Connectivity evidence signals — used to prevent ICMP false positives.
    # DNS resolution and TCP 443 are stronger than ICMP because they require
    # a complete end-to-end path including the gateway and an upstream DNS resolver.
    $dnsEvidence  = $dnsOk
    $tcpEvidence  = $port443Ok -eq $true
    $icmpEvidence = $gwOk -or $intOk
    $anyEvidence  = $dnsEvidence -or $tcpEvidence -or $icmpEvidence

    # Will be set to $true if ICMP is the only failing signal while DNS/TCP work
    $icmpBlocked = $false

    # Helper: friendly adapter label for findings text
    $adapterLabel = if ($d["AdapterName"]) {
        $lbl = $d["AdapterName"]
        if ($ssid)                      { "$lbl (Wi-Fi — SSID: $ssid)" }
        elseif ($adapterType -eq "Wi-Fi")      { "$lbl (Wi-Fi)"       }
        elseif ($adapterType -eq "Ethernet")   { "$lbl (Ethernet)"    }
        else                                   { $lbl                  }
    } else { $adapterType }

    $layerOk = $true

    # ============================================================
    #  LAYER 1 — Adapter presence
    # ============================================================
    if ($adapterCount -eq 0) {
        $Result.Findings.Add((New-Finding -Title "No Network Adapter Detected" -Severity "critical" `
            -Description "No network adapters were found on this system. The network driver may be missing, disabled in Device Manager, or the hardware has failed."))
        $Result.Warnings.Add("No network adapters detected — driver missing or hardware failure.")
        $Result.Recommendations.Add("Open Device Manager (devmgmt.msc) and check for Network Adapters. Reinstall drivers if the adapter is absent or shows an error.")
        $d["ProbableCauseCode"] = "NoAdapter"
        Push-LogMessage -State $State -Message "  CRITICAL: No network adapter found." -Type "error"
        return
    }

    # ============================================================
    #  LAYER 2 — Active adapter
    # ============================================================
    if ($activeAdapters.Count -eq 0) {
        $names = (@($d["Adapters"]) | ForEach-Object { $_.Name }) -join ", "
        $connectionHint = if ($adapterType -eq "Wi-Fi") {
            "Ensure Wi-Fi is enabled (keyboard toggle or Windows Settings > Network) and that a network is selected."
        } else {
            "Check the network cable connection. Verify the adapter is enabled in Network Connections."
        }
        $Result.Findings.Add((New-Finding -Title "Adapter Disconnected" -Severity "error" `
            -Description "Network adapters are installed ($names) but none are in an Up state. $connectionHint"))
        $Result.Warnings.Add("No adapter is Up — all are disconnected or disabled.")
        $Result.Recommendations.Add($connectionHint)
        $d["ProbableCauseCode"] = "AdapterDown"
        Push-LogMessage -State $State -Message "  ERROR: No adapter is Up ($names)." -Type "error"
        return
    }

    $adapterInfo = "$($activeAdapters[0].Name) ($($activeAdapters[0].InterfaceDescription))"
    $typeStr     = if ($ssid) { " | Wi-Fi SSID: $ssid" } else { "" }
    Push-LogMessage -State $State `
        -Message "  Adapter: $adapterInfo | Type: $adapterType$typeStr | Active: $($activeAdapters.Count)" `
        -Type "ok"

    # ============================================================
    #  LAYER 3 — TCP/IP stack integrity (loopback 127.0.0.1)
    # ============================================================
    if (-not $loopback) {
        $Result.Findings.Add((New-Finding -Title "TCP/IP Stack Corrupted" -Severity "critical" `
            -Description "Loopback address 127.0.0.1 is not responding. The TCP/IP stack is likely corrupted — Winsock catalog reset and TCP/IP stack reset are required. Run in FullRepair mode to apply these fixes (requires reboot)."))
        $Result.Warnings.Add("Loopback (127.0.0.1) unreachable — TCP/IP stack corruption detected.")
        $Result.Recommendations.Add("Run in FullRepair mode to execute: netsh winsock reset + netsh int ip reset. A reboot will be required to complete repairs.")
        $d["ProbableCauseCode"] = "StackCorrupted"
        Push-LogMessage -State $State -Message "  CRITICAL: Loopback 127.0.0.1 unreachable — TCP/IP stack damaged." -Type "error"
        return
    }
    Push-LogMessage -State $State -Message "  Loopback: OK" -Type "ok"

    # ── Local IP self-ping (informational) ────────────────────
    if ($null -ne $localIPOk) {
        Push-LogMessage -State $State `
            -Message "  Local IP self-ping ($localIP): $(if ($localIPOk) { 'OK' } else { 'FAIL — routing or adapter issue' })" `
            -Type $(if ($localIPOk) { "ok" } else { "warn" })
    }

    # ============================================================
    #  LAYER 4 — IP address on primary adapter
    #
    #  APIPA check is scoped to the PRIMARY adapter only.
    #  VPN tap adapters, Bluetooth PAN, and disconnected secondary NICs
    #  commonly carry 169.254.x.x addresses and must not be used to
    #  diagnose the primary connection as failing DHCP.
    # ============================================================
    if ($apipaOnPrimary) {
        $Result.Findings.Add((New-Finding -Title "APIPA Address Detected (DHCP Failure)" -Severity "warn" `
            -Description "The $adapterLabel has a self-assigned address ($localIP). DHCP failed — the adapter could not obtain a lease from the DHCP server. Check the cable/Wi-Fi connection and verify the router is online."))
        $Result.Warnings.Add("APIPA (169.254.x.x) on $adapterLabel — DHCP lease failed on the primary connection.")
        $Result.Recommendations.Add("Run SafeRepair to attempt: ipconfig /release + /renew + adapter restart. Check network cable, Wi-Fi signal, and whether the router/DHCP server is powered on.")
        $d["ProbableCauseCode"] = "APIPA"
        Push-LogMessage -State $State -Message "  WARN: APIPA $localIP on primary adapter — DHCP not responding." -Type "warn"
        $layerOk = $false
    } elseif (-not $localIP) {
        $ipDetail = if ($isDhcp) {
            "DHCP is enabled but no lease was obtained. The DHCP server may be offline or the adapter may need to be restarted."
        } else {
            "No static IP has been configured on this adapter."
        }
        $Result.Findings.Add((New-Finding -Title "No IP Address Assigned" -Severity "error" `
            -Description "The $adapterLabel is Up but has no IPv4 address. $ipDetail"))
        $Result.Warnings.Add("No IPv4 address on $adapterLabel.")
        $Result.Recommendations.Add("$(if ($isDhcp) { 'Run SafeRepair to attempt ipconfig /renew and adapter restart. Verify the router/DHCP server is reachable.' } else { 'Assign a static IP address via Network Connections or contact your network administrator.' })")
        $d["ProbableCauseCode"] = "NoIP"
        Push-LogMessage -State $State -Message "  ERROR: No IP on $adapterLabel (DHCP: $isDhcp)." -Type "error"
        $layerOk = $false
    } else {
        $prefixStr = if ($d["PrefixLength"]) { "/$($d['PrefixLength'])" } else { "" }
        $dhcpStr   = if ($isDhcp) { "DHCP" } else { "Static" }
        Push-LogMessage -State $State `
            -Message "  IP: $localIP$prefixStr [$dhcpStr]  |  GW: $(if ($gateway) { $gateway } else { 'none' })  |  DNS: $(if ($dns.Count -gt 0) { $dns -join ', ' } else { 'none' })" `
            -Type "ok"

        # Informational note: non-primary adapters have APIPA but primary is fine
        if ($apipaAny -and -not $apipaOnPrimary) {
            Push-LogMessage -State $State `
                -Message "  INFO: APIPA addresses exist on non-primary adapters — primary connection unaffected." `
                -Type "info"
        }
    }

    # ============================================================
    #  LAYER 5 — Gateway configured and reachable
    #
    #  Gateway ICMP failure is treated as non-fatal when DNS or TCP
    #  evidence confirms the network path is working.  Many routers
    #  block inbound ICMP from LAN clients (a common security setting).
    # ============================================================
    if ($layerOk) {
        if (-not $gateway) {
            # No gateway configured — non-fatal only if DNS somehow works anyway
            if ($dnsEvidence) {
                Push-LogMessage -State $State `
                    -Message "  INFO: No default gateway in adapter config, but DNS is resolving — unusual routing configuration. Noting but not blocking." `
                    -Type "info"
            } else {
                $Result.Findings.Add((New-Finding -Title "No Default Gateway Configured" -Severity "warn" `
                    -Description "The $adapterLabel has an IP address but no default gateway is set. Internet access requires a gateway. This may indicate a DHCP misconfiguration or incomplete static IP setup."))
                $Result.Warnings.Add("No default gateway on $adapterLabel.")
                $Result.Recommendations.Add("$(if ($isDhcp) { 'Check that the DHCP server is configured to provide a gateway (Option 3). Try ipconfig /renew.' } else { 'Add the default gateway address in the static IP configuration for this adapter.' })")
                $d["ProbableCauseCode"] = "NoGateway"
                Push-LogMessage -State $State -Message "  WARN: No default gateway on $adapterLabel, no DNS evidence." -Type "warn"
                $layerOk = $false
            }
        } elseif (-not $gwOk) {
            # Gateway ICMP failed — use DNS/TCP to decide whether this is a real outage
            if ($dnsEvidence -or $tcpEvidence) {
                # DNS or TCP confirms the network path works — ICMP is just filtered
                $icmpBlocked = $true
                $evidenceList = @(
                    if ($dnsEvidence)  { "DNS resolved $($d['DnsResolved'])" }
                    if ($tcpEvidence)  { "TCP 443 OK to 1.1.1.1" }
                ) -join ", "
                Push-LogMessage -State $State `
                    -Message "  INFO: Gateway $gateway does not respond to ICMP, but connectivity is confirmed ($evidenceList). Gateway ICMP is filtered/blocked — not a connectivity failure." `
                    -Type "info"
                # $layerOk remains $true — continue chain
            } else {
                # No DNS, no TCP — gateway may truly be unreachable
                $mediaHint = if ($adapterType -eq "Wi-Fi") {
                    "Check Wi-Fi signal strength and try reconnecting to the network."
                } else {
                    "Check the network cable, verify the router/switch is powered on, and check for a LAN link light."
                }
                $Result.Findings.Add((New-Finding -Title "Gateway Unreachable" -Severity "error" `
                    -Description "Default gateway ($gateway) does not respond to ICMP ping, and no DNS or TCP evidence of connectivity was found. $mediaHint"))
                $Result.Warnings.Add("Gateway $gateway unreachable — no connectivity evidence from DNS or TCP.")
                $Result.Recommendations.Add("$mediaHint Restart the router/switch if necessary.")
                $d["ProbableCauseCode"] = "GatewayUnreachable"
                Push-LogMessage -State $State -Message "  ERROR: Gateway $gateway unreachable — no DNS/TCP fallback evidence." -Type "error"
                $layerOk = $false
            }
        } else {
            $latStr = if ($null -ne $gwLatency) { " (${gwLatency}ms)" } else { "" }
            Push-LogMessage -State $State -Message "  Gateway ${gateway}: OK$latStr" -Type "ok"
        }
    }

    # ============================================================
    #  LAYER 6 — Internet reachability
    #
    #  Evidence hierarchy (strongest first):
    #    1. DNS resolution — requires full path to an internet DNS resolver
    #    2. TCP 443 — requires TCP path to a public HTTPS endpoint
    #    3. ICMP to 8.8.8.8 / 1.1.1.1 — often blocked; confirms IP routing only
    #
    #  If DNS or TCP confirms internet, ICMP failure is marked as IcmpBlocked.
    # ============================================================
    if ($layerOk) {
        $internetConfirmed = $dnsEvidence -or $tcpEvidence -or $intOk

        if (-not $internetConfirmed) {
            $Result.Findings.Add((New-Finding -Title "No Internet Connectivity" -Severity "error" `
                -Description "Gateway is reachable but no internet access could be confirmed: ICMP to 8.8.8.8/1.1.1.1 failed, DNS resolution failed, and TCP port 443 failed. This points to an ISP or modem/router WAN issue — local network may be functional."))
            $Result.Warnings.Add("Internet unreachable — ICMP, DNS, and TCP 443 all failed.")
            $Result.Recommendations.Add("Check the modem WAN light (should be solid). Power-cycle the modem (wait 30 seconds after power-off). Contact your ISP if the problem persists.")
            $d["ProbableCauseCode"] = "NoInternet"
            Push-LogMessage -State $State -Message "  ERROR: No internet — ICMP, DNS, and TCP 443 all failed." -Type "error"
            $layerOk = $false
        } else {
            if (-not $intOk -and ($dnsEvidence -or $tcpEvidence)) {
                # ICMP blocked but real connectivity confirmed
                $icmpBlocked = $true
                $evidenceList = @(
                    if ($dnsEvidence) { "DNS resolved $($d['DnsResolved'])" }
                    if ($tcpEvidence) { "TCP 443 OK to 1.1.1.1" }
                ) -join ", "
                Push-LogMessage -State $State `
                    -Message "  INFO: Internet ICMP blocked (8.8.8.8/1.1.1.1 did not respond), but connectivity confirmed: $evidenceList. ICMP filtering by ISP or firewall — not a real outage." `
                    -Type "info"
            } else {
                $latStr  = if ($null -ne $intLatency) { " (${intLatency}ms)" } else { "" }
                $p443Str = if ($port443Ok -eq $true) { " | TCP 443: OK" } `
                           elseif ($port443Ok -eq $false -and $intOk) { " | TCP 443: no response" } `
                           else { "" }
                Push-LogMessage -State $State `
                    -Message "  Internet: OK$latStr via $($d['InternetTarget'])$p443Str" -Type "ok"
            }
        }
    }

    # ============================================================
    #  LAYER 7 — DNS name resolution
    # ============================================================
    if ($layerOk) {
        if (-not $dnsOk) {
            $dnsStr = if ($dns.Count -gt 0) { $dns -join ", " } else { "none configured" }
            $Result.Findings.Add((New-Finding -Title "DNS Resolution Failing" -Severity "warn" `
                -Description "Internet is reachable (ICMP or TCP confirmed) but hostname resolution is failing. Configured DNS servers ($dnsStr) are not responding correctly or the DNS cache is stale."))
            $Result.Warnings.Add("DNS resolution failed — internet reachable but name resolution is broken.")
            $Result.Recommendations.Add("Run SafeRepair to flush the DNS cache (ipconfig /flushdns). If that fails, manually configure a public DNS: 8.8.8.8 (Google) or 1.1.1.1 (Cloudflare).")
            $d["ProbableCauseCode"] = "DNSFailure"
            Push-LogMessage -State $State -Message "  WARN: DNS resolution failed (servers: $dnsStr)." -Type "warn"
        } else {
            Push-LogMessage -State $State -Message "  DNS: OK — resolved $($d['DnsResolved'])" -Type "ok"
        }
    }

    # ============================================================
    #  OVERALL — all layers passed (or ICMP was the only failure)
    # ============================================================
    if ($Result.Findings.Count -eq 0) {
        $latStr     = if ($null -ne $intLatency)  { " — internet latency: ${intLatency}ms" } else { "" }
        $icmpNote   = if ($icmpBlocked)            { " ICMP ping to gateway/internet is filtered — connectivity confirmed via DNS/TCP." } else { "" }
        $ipMethod   = if ($isDhcp) { "via DHCP" } else { "(static)" }
        $Result.Findings.Add((New-Finding -Title "Network Fully Operational" -Severity "ok" `
            -Description "All diagnostic layers passed: $adapterLabel is active, IP assigned $ipMethod, gateway configured, internet connected, DNS resolving$latStr.$icmpNote"))
        $d["ProbableCauseCode"] = "Healthy"
        $icmpNote2 = if ($icmpBlocked) { " (ICMP filtered — confirmed via DNS/TCP)" } else { "" }
        Push-LogMessage -State $State -Message "  All network layers: OK$icmpNote2" -Type "ok"
    } elseif ($icmpBlocked -and -not $d["ProbableCauseCode"]) {
        # ICMP blocked was noted but no real problem found — still healthy
        $d["ProbableCauseCode"] = "IcmpBlocked"
    }

    # Ensure ProbableCauseCode is always set
    if (-not $d["ProbableCauseCode"]) { $d["ProbableCauseCode"] = "Healthy" }

    # Final summary log
    Push-LogMessage -State $State `
        -Message "  Probable cause: $($d['ProbableCauseCode'])" -Type "info"
    if ($dns.Count -gt 0) {
        Push-LogMessage -State $State -Message "  DNS servers: $($dns -join ', ')" -Type "info"
    }
}
