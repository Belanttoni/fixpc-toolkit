<#
.SYNOPSIS
    FixPC Toolkit — Network Module: Analyze Phase
    Layered network diagnostic evaluation.
    Scriptblock stored as $Script:Analyze_Network.

    Diagnostic model (evaluated in order, stops at first root cause):
        Layer 1  — Adapter presence
        Layer 2  — Active adapter
        Layer 3  — TCP/IP stack (loopback)
        Layer 4  — Local IP / DHCP
        Layer 5  — Gateway reachability
        Layer 6  — Internet reachability (IP-level)
        Layer 7  — DNS name resolution
        All pass — Network healthy

    Severity string model: "ok" | "info" | "warn" | "error" | "critical"

.VERSION 1.0
#>

$Script:Analyze_Network = {
    param($Result, $State)

    $d              = $Result.Data
    $adapterCount   = $d["AdapterCount"]
    $activeAdapters = @($d["ActiveAdapters"])
    $loopback       = $d["LoopbackOk"]
    $localIP        = $d["LocalIP"]
    $apipa          = $d["ApipaDetected"]
    $gwOk           = $d["GatewayOk"]
    $gwLatency      = $d["GatewayLatencyMs"]
    $gateway        = $d["Gateway"]
    $intOk          = $d["InternetOk"]
    $intLatency     = $d["InternetLatencyMs"]
    $dnsOk          = $d["DnsOk"]
    $dns            = @($d["DNSServers"])

    # Tracks whether each layer passed; lower layers are skipped
    # on first failure to avoid cascading false findings.
    $layerOk = $true

    # ============================================================
    #  LAYER 1 — Adapter presence
    # ============================================================
    if ($adapterCount -eq 0) {
        $Result.Findings.Add((New-Finding -Title "No Network Adapter Detected" -Severity "critical" `
            -Description "No network adapters found. Check Device Manager for missing or failed drivers."))
        $Result.Warnings.Add("No network adapters detected — driver missing or hardware failure.")
        $Result.Recommendations.Add("Check Device Manager. Reinstall network drivers if adapter is missing.")
        $d["ProbableCause"] = "No network adapter present or driver is missing."
        Push-LogMessage -State $State -Message "  CRITICAL: No network adapter found." -Type "error"
        return   # No point testing anything further
    }

    # ============================================================
    #  LAYER 2 — Active adapter
    # ============================================================
    if ($activeAdapters.Count -eq 0) {
        $names = ($d["Adapters"] | ForEach-Object { $_.Name }) -join ", "
        $Result.Findings.Add((New-Finding -Title "No Active Adapter" -Severity "error" `
            -Description "Adapters present ($names) but none are Up. Check cables, Wi-Fi switch, or adapter enable state."))
        $Result.Warnings.Add("No adapter is Up — all are disconnected or disabled.")
        $Result.Recommendations.Add("Check network cable, Wi-Fi toggle, or enable the adapter in Network Connections.")
        $d["ProbableCause"] = "All adapters are disabled, unplugged, or disconnected."
        Push-LogMessage -State $State -Message "  ERROR: No adapter is Up ($names)." -Type "error"
        return
    }

    $adapterInfo = "$($activeAdapters[0].Name) ($($activeAdapters[0].InterfaceDescription))"
    Push-LogMessage -State $State -Message "  Adapter: $adapterInfo [$($activeAdapters.Count) active]" -Type "ok"

    # ============================================================
    #  LAYER 3 — TCP/IP stack (loopback 127.0.0.1)
    # ============================================================
    if (-not $loopback) {
        $Result.Findings.Add((New-Finding -Title "Loopback Unreachable" -Severity "critical" `
            -Description "127.0.0.1 does not respond. The TCP/IP stack is likely corrupted. A Winsock and TCP/IP stack reset is required (FullRepair mode)."))
        $Result.Warnings.Add("Loopback (127.0.0.1) failed — TCP/IP stack corruption detected.")
        $Result.Recommendations.Add("Run in FullRepair mode to execute netsh winsock reset and netsh int ip reset.")
        $d["ProbableCause"] = "TCP/IP stack corrupted — Winsock/TCP reset required (FullRepair)."
        Push-LogMessage -State $State -Message "  CRITICAL: 127.0.0.1 unreachable — TCP/IP stack issue." -Type "error"
        return
    }

    Push-LogMessage -State $State -Message "  Loopback OK" -Type "ok"

    # ============================================================
    #  LAYER 4 — Local IP / DHCP
    # ============================================================
    if ($apipa) {
        $Result.Findings.Add((New-Finding -Title "APIPA Address Detected" -Severity "warn" `
            -Description "Adapter has a 169.254.x.x self-assigned address. DHCP server is unreachable or the adapter failed to obtain a lease."))
        $Result.Warnings.Add("APIPA (169.254.x.x) detected — DHCP lease failure.")
        $Result.Recommendations.Add("Run SafeRepair to attempt ipconfig /release and /renew. Check DHCP server and network cable.")
        $d["ProbableCause"] = "DHCP failure — adapter is using a self-assigned APIPA address."
        Push-LogMessage -State $State -Message "  WARN: APIPA 169.254.x.x detected — DHCP not responding." -Type "warn"
        $layerOk = $false
    } elseif (-not $localIP) {
        $Result.Findings.Add((New-Finding -Title "No IP Address Assigned" -Severity "error" `
            -Description "The active adapter has no IPv4 address. DHCP may be failing or the adapter is misconfigured."))
        $Result.Warnings.Add("No IPv4 address on active adapter.")
        $Result.Recommendations.Add("Run SafeRepair to attempt ipconfig /renew. Check DHCP server connectivity.")
        $d["ProbableCause"] = "No IP address assigned — DHCP or adapter configuration issue."
        Push-LogMessage -State $State -Message "  ERROR: No IP address on active adapter." -Type "error"
        $layerOk = $false
    } else {
        $prefixStr = if ($d["PrefixLength"]) { "/$($d['PrefixLength'])" } else { "" }
        Push-LogMessage -State $State -Message "  IP: $localIP$prefixStr  |  GW: $gateway" -Type "ok"
    }

    # ============================================================
    #  LAYER 5 — Gateway reachability
    # ============================================================
    if ($layerOk) {
        if (-not $gateway) {
            $Result.Findings.Add((New-Finding -Title "No Default Gateway Configured" -Severity "warn" `
                -Description "No default gateway is set. Internet access is not possible without a gateway."))
            $Result.Warnings.Add("No default gateway configured.")
            $Result.Recommendations.Add("Set a default gateway via DHCP or static IP configuration.")
            $d["ProbableCause"] = "No default gateway — DHCP or manual configuration required."
            Push-LogMessage -State $State -Message "  WARN: No default gateway configured." -Type "warn"
            $layerOk = $false
        } elseif (-not $gwOk) {
            $Result.Findings.Add((New-Finding -Title "Gateway Unreachable" -Severity "error" `
                -Description "Default gateway ($gateway) does not respond to ping. Likely a local network issue: faulty cable, router offline, or VLAN mismatch."))
            $Result.Warnings.Add("Gateway $gateway is unreachable.")
            $Result.Recommendations.Add("Check physical cable / Wi-Fi signal, verify router is powered on, and check LAN switch status.")
            $d["ProbableCause"] = "Gateway unreachable — local network issue (cable, router, or switch)."
            Push-LogMessage -State $State -Message "  ERROR: Gateway $gateway unreachable." -Type "error"
            $layerOk = $false
        } else {
            $latStr = if ($gwLatency -ne $null) { " (${gwLatency}ms)" } else { "" }
            Push-LogMessage -State $State -Message "  Gateway $gateway reachable$latStr" -Type "ok"
        }
    }

    # ============================================================
    #  LAYER 6 — Internet reachability (IP-level)
    # ============================================================
    if ($layerOk) {
        if (-not $intOk) {
            $Result.Findings.Add((New-Finding -Title "No Internet Connectivity" -Severity "error" `
                -Description "Gateway is reachable but public internet (8.8.8.8 / 1.1.1.1) is not responding. Likely an ISP or modem/router WAN issue."))
            $Result.Warnings.Add("Internet unreachable — gateway responds but 8.8.8.8 / 1.1.1.1 do not.")
            $Result.Recommendations.Add("Check modem/router WAN light. Power-cycle the modem. Contact ISP if persistent.")
            $d["ProbableCause"] = "ISP or upstream routing issue — local network OK but internet not reachable."
            Push-LogMessage -State $State -Message "  ERROR: Internet unreachable (8.8.8.8 / 1.1.1.1 timed out)." -Type "error"
            $layerOk = $false
        } else {
            $latStr = if ($intLatency -ne $null) { " (${intLatency}ms)" } else { "" }
            Push-LogMessage -State $State -Message "  Internet OK$latStr via $($d['InternetTarget'])" -Type "ok"
        }
    }

    # ============================================================
    #  LAYER 7 — DNS name resolution
    # ============================================================
    if ($layerOk) {
        if (-not $dnsOk) {
            $dnsStr = if ($dns.Count -gt 0) { $dns -join ", " } else { "none configured" }
            $Result.Findings.Add((New-Finding -Title "DNS Resolution Failing" -Severity "warn" `
                -Description "Internet is reachable by IP but hostname resolution is failing. DNS servers ($dnsStr) are not responding correctly."))
            $Result.Warnings.Add("DNS resolution failed — internet reachable by IP, names do not resolve.")
            $Result.Recommendations.Add("Run SafeRepair to flush DNS cache. Consider switching to a public DNS (8.8.8.8 / 1.1.1.1).")
            $d["ProbableCause"] = "DNS server issue — internet OK by IP but name resolution is broken."
            Push-LogMessage -State $State -Message "  WARN: DNS resolution failed (servers: $dnsStr)." -Type "warn"
        } else {
            Push-LogMessage -State $State -Message "  DNS OK — resolved $($d['DnsResolved'])" -Type "ok"
        }
    }

    # ============================================================
    #  OVERALL — all layers passed
    # ============================================================
    if ($Result.Findings.Count -eq 0) {
        $latStr = if ($intLatency -ne $null) { " — internet latency: ${intLatency}ms" } else { "" }
        $Result.Findings.Add((New-Finding -Title "Network Fully Operational" -Severity "ok" `
            -Description "All diagnostic layers passed: adapter active, IP assigned, gateway reachable, internet connected, DNS resolving$latStr."))
        $d["ProbableCause"] = "None — network is fully operational."
        Push-LogMessage -State $State -Message "  All network layers: OK" -Type "ok"
    }

    # DNS server summary
    if ($dns.Count -gt 0) {
        Push-LogMessage -State $State -Message "  DNS servers: $($dns -join ', ')" -Type "info"
    }
}
