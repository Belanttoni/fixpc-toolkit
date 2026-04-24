<#
.SYNOPSIS
    FixPC Toolkit — Network Module: Export Phase
    Structures collected and analyzed data for the reporting pipeline.
    Scriptblock stored as $Script:Export_Network.

    ExportData keys consumed by Reports/HTML.ps1 ("Network Diagnostics" section):
        summary           — one-line overall status (first finding description)
        probableCauseCode — structured code: Healthy | NoAdapter | AdapterDown |
                            StackCorrupted | APIPA | NoIP | NoGateway |
                            GatewayUnreachable | NoInternet | DNSFailure
        adapterName       — primary active adapter alias
        adapterType       — "Ethernet" | "Wi-Fi" | "Unknown"
        ssid              — SSID string if Wi-Fi, else $null
        localIP           — assigned IPv4 address
        prefixLength      — subnet prefix (e.g. 24)
        gateway           — default gateway IP
        dnsServers        — array of DNS server IP strings
        isDhcp            — bool: true if address was DHCP-assigned
        apipaDetected     — bool: true if 169.254.x.x found
        connectivity      — ordered hashtable: loopback/localIP/gateway/internet/dns/port443
        adapters          — array of all adapters (name, desc, status, speed)
        rebootRequired    — bool: true if stack reset was applied by Repair phase

.VERSION 1.1
#>

$Script:Export_Network = {
    param($Result, $State)

    $d = $Result.Data
    $f = if ($Result.Findings.Count -gt 0) { $Result.Findings[0] } else { $null }

    # ── Overall summary ───────────────────────────────────────
    $Result.ExportData["summary"]           = if ($f) { $f.Description } else { "No findings recorded." }
    $Result.ExportData["probableCauseCode"] = if ($d["ProbableCauseCode"]) { $d["ProbableCauseCode"] } else { "Undetermined" }

    # ── Primary adapter / IP info ─────────────────────────────
    $Result.ExportData["adapterName"]   = $d["AdapterName"]
    $Result.ExportData["adapterType"]   = if ($d["AdapterType"]) { $d["AdapterType"] } else { "Unknown" }
    $Result.ExportData["ssid"]          = $d["SSID"]
    $Result.ExportData["localIP"]       = $d["LocalIP"]
    $Result.ExportData["prefixLength"]  = $d["PrefixLength"]
    $Result.ExportData["gateway"]       = $d["Gateway"]
    $Result.ExportData["dnsServers"]    = @($d["DNSServers"])
    $Result.ExportData["isDhcp"]         = if ($null -ne $d["IsDhcp"])          { $d["IsDhcp"]          } else { $false }
    $Result.ExportData["apipaOnPrimary"] = if ($null -ne $d["ApipaOnPrimary"])  { $d["ApipaOnPrimary"]  } else { $false }
    $Result.ExportData["apipaDetected"]  = if ($null -ne $d["ApipaDetected"])   { $d["ApipaDetected"]   } else { $false }

    # ── Connectivity matrix ───────────────────────────────────
    # Gateway and Internet rows use INTERPRETED status so that ICMP-blocked-but-
    # healthy networks render as pass (amber "OK (ICMP filtered)"), not red FAIL.
    #
    # Interpretation is derived two ways (whichever is available):
    #   a) Keys written by Analyze — GatewayIcmpBlocked / GatewayInterpretedOk
    #   b) Fallback in Export — when Analyze keys are $null, derive from ProbableCauseCode:
    #      if the network is Healthy/IcmpBlocked but ICMP failed, ICMP was merely filtered.
    #
    # This fallback is essential because [bool]$null = $false, meaning missing Analyze keys
    # would silently revert to raw ICMP and show FAIL for a healthy ICMP-blocked network.
    $gwLatStr  = if ($null -ne $d["GatewayLatencyMs"])  { "$($d['GatewayLatencyMs'])ms" }  else { "N/A" }
    $intLatStr = if ($null -ne $d["InternetLatencyMs"]) { "$($d['InternetLatencyMs'])ms" } else { "N/A" }

    # Authoritative health verdict from Analyze
    $netHealthy = $d["ProbableCauseCode"] -in @("Healthy", "IcmpBlocked")

    # Gateway: prefer Analyze keys; fall back to ProbableCauseCode-based derivation
    $gwRawOk = [bool]$d["GatewayOk"]
    $gwIcmpBlocked = if ($null -ne $d["GatewayIcmpBlocked"]) {
        [bool]$d["GatewayIcmpBlocked"]
    } else {
        (-not $gwRawOk) -and [bool]$d["Gateway"] -and $netHealthy
    }
    $gwInterpOk = if ($null -ne $d["GatewayInterpretedOk"]) {
        [bool]$d["GatewayInterpretedOk"]
    } else {
        $gwRawOk -or $gwIcmpBlocked
    }
    $gwDetail = if ($gwRawOk) {
        "Gateway reachable ($gwLatStr)"
    } elseif ($gwIcmpBlocked) {
        "ICMP ping filtered — gateway path confirmed via DNS/TCP"
    } else {
        "Gateway unreachable"
    }

    # Internet: same two-source approach
    $intRawOk = [bool]$d["InternetOk"]
    $intIcmpBlocked = if ($null -ne $d["InternetIcmpBlocked"]) {
        [bool]$d["InternetIcmpBlocked"]
    } else {
        (-not $intRawOk) -and $netHealthy
    }
    $intInterpOk = if ($null -ne $d["InternetInterpretedOk"]) {
        [bool]$d["InternetInterpretedOk"]
    } else {
        $intRawOk -or $intIcmpBlocked
    }
    $dnsNote   = if ($d["DnsResolved"]) { ", DNS resolved $($d['DnsResolved'])" } else { "" }
    $intDetail = if ($intRawOk) {
        "Internet reachable ($intLatStr)"
    } elseif ($intIcmpBlocked) {
        "ICMP ping filtered — internet confirmed via DNS$dnsNote$(if ($d['Port443Ok']) { ' and TCP 443' })"
    } else {
        "Internet unreachable"
    }

    $localIPOk  = $d["LocalIPOk"]
    $localIPStr = if ($null -ne $localIPOk) {
        if ($localIPOk) { "Self-ping OK" } else { "Self-ping failed — adapter or routing issue" }
    } else { "Skipped (no IP)" }

    $port443Ok = $d["Port443Ok"]
    $p443Str   = if ($port443Ok -eq $true) {
        "TCP 443 reachable — HTTPS connectivity confirmed"
    } elseif ($port443Ok -eq $false -and ($intRawOk -or $intIcmpBlocked)) {
        "TCP 443 no response — HTTPS may be filtered"
    } else {
        "Not tested"
    }

    $Result.ExportData["connectivity"] = [ordered]@{
        loopback = [ordered]@{
            ok          = $d["LoopbackOk"]
            icmpBlocked = $false
            detail      = if ($d["LoopbackOk"]) { "TCP/IP stack OK" } else { "TCP/IP stack unreachable — Winsock reset needed" }
        }
        localIP  = [ordered]@{
            ok          = $localIPOk
            icmpBlocked = $false
            target      = $d["LocalIP"]
            detail      = $localIPStr
        }
        gateway  = [ordered]@{
            ok          = $gwInterpOk      # interpreted: true if ICMP OK or ICMP-blocked-with-evidence
            icmpBlocked = $gwIcmpBlocked   # true = ICMP filtered, connectivity confirmed another way
            target      = $d["Gateway"]
            latencyMs   = $d["GatewayLatencyMs"]
            latencyStr  = $gwLatStr
            detail      = $gwDetail
        }
        internet = [ordered]@{
            ok          = $intInterpOk     # interpreted
            icmpBlocked = $intIcmpBlocked
            target      = $d["InternetTarget"]
            latencyMs   = $d["InternetLatencyMs"]
            latencyStr  = $intLatStr
            detail      = $intDetail
        }
        dns      = [ordered]@{
            ok          = $d["DnsOk"]
            icmpBlocked = $false
            resolved    = $d["DnsResolved"]
            servers     = @($d["DNSServers"])
            detail      = if ($d["DnsOk"]) { "Resolved $($d['DnsResolved'])" } else { "Name resolution failing" }
        }
        port443  = [ordered]@{
            ok          = $port443Ok
            icmpBlocked = $false
            target      = "1.1.1.1:443"
            detail      = $p443Str
        }
    }

    # ── Adapter inventory (all adapters for the report table) ─
    $Result.ExportData["adapters"] = if ($d["Adapters"]) {
        @($d["Adapters"] | ForEach-Object {
            [ordered]@{
                Name   = $_.Name
                Desc   = $_.InterfaceDescription
                Status = $_.Status
                Speed  = if ($_.LinkSpeed) { $_.LinkSpeed } else { "N/A" }
                Class  = switch ($_.Status) {
                    "Up"           { "ok"   }
                    "Disconnected" { "warn" }
                    default        { ""     }
                }
            }
        })
    } else { @() }

    # ── Reboot flag ───────────────────────────────────────────
    $Result.ExportData["rebootRequired"]  = if ($null -ne $d["RebootRequired"])  { $d["RebootRequired"]  } else { $false }
    $Result.ExportData["repairAttempted"] = if ($null -ne $d["RepairAttempted"]) { $d["RepairAttempted"] } else { $false }

    # ── Repair summary (populated after Repair phase runs) ────
    # Builds a structured view of all ActionsTaken for HTML rendering.
    $actions = $Result.ActionsTaken
    if ($actions -and $actions.Count -gt 0) {
        $succeeded = @($actions | Where-Object { $_.Success }).Count
        $failed    = $actions.Count - $succeeded

        $Result.ExportData["repairSummary"] = [ordered]@{
            attempted = $actions.Count
            succeeded = $succeeded
            failed    = $failed
            actions   = @($actions | ForEach-Object {
                $detailText = if ($_.Success) {
                    if ($_.Detail)      { "$($_.Detail)" }      else { "" }
                } else {
                    if ($_.ErrorDetail) { "$($_.ErrorDetail)" } else { "Failed" }
                }
                [ordered]@{
                    action  = "$($_.Action)"
                    target  = "$($_.Target)"
                    success = $_.Success
                    detail  = $detailText
                }
            })
        }
    } else {
        $Result.ExportData["repairSummary"] = $null
    }
}
