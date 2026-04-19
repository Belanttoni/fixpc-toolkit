<#
.SYNOPSIS
    FixPC Toolkit — Network Module: Export Phase
    Structures collected and analyzed data for the reporting pipeline.
    Scriptblock stored as $Script:Export_Network.

    ExportData keys consumed by Reports/HTML.ps1 ("Network Diagnostics" section):
        summary       — one-line overall status
        probableCause — root-cause classification string
        adapterName   — primary active adapter
        localIP       — assigned IPv4 address
        prefixLength  — subnet prefix (e.g. 24)
        gateway       — default gateway IP
        dnsServers    — array of DNS server IP strings
        connectivity  — ordered hashtable: loopback/gateway/internet/dns results
        adapters      — array of all adapters (name, status, speed)
        rebootRequired — bool: true if stack reset was applied

.VERSION 1.0
#>

$Script:Export_Network = {
    param($Result, $State)

    $d = $Result.Data
    $f = if ($Result.Findings.Count -gt 0) { $Result.Findings[0] } else { $null }

    # ── Overall summary ───────────────────────────────────────
    $Result.ExportData["summary"]       = if ($f) { $f.Description } else { "No findings recorded." }
    $Result.ExportData["probableCause"] = if ($d["ProbableCause"]) { $d["ProbableCause"] } else { "Undetermined." }

    # ── Primary adapter / IP info ─────────────────────────────
    $Result.ExportData["adapterName"]  = $d["AdapterName"]
    $Result.ExportData["localIP"]      = $d["LocalIP"]
    $Result.ExportData["prefixLength"] = $d["PrefixLength"]
    $Result.ExportData["gateway"]      = $d["Gateway"]
    $Result.ExportData["dnsServers"]   = @($d["DNSServers"])
    $Result.ExportData["apipaDetected"]= $d["ApipaDetected"]

    # ── Connectivity matrix ───────────────────────────────────
    $gwLatStr  = if ($null -ne $d["GatewayLatencyMs"])  { "$($d['GatewayLatencyMs'])ms" }  else { "N/A" }
    $intLatStr = if ($null -ne $d["InternetLatencyMs"]) { "$($d['InternetLatencyMs'])ms" } else { "N/A" }

    $Result.ExportData["connectivity"] = [ordered]@{
        loopback = [ordered]@{
            ok     = $d["LoopbackOk"]
            detail = if ($d["LoopbackOk"]) { "TCP/IP stack OK" } else { "TCP/IP stack unreachable — Winsock reset needed" }
        }
        gateway  = [ordered]@{
            ok        = $d["GatewayOk"]
            target    = $d["Gateway"]
            latencyMs = $d["GatewayLatencyMs"]
            latencyStr= $gwLatStr
            detail    = if ($d["GatewayOk"]) { "Gateway reachable ($gwLatStr)" } else { "Gateway unreachable" }
        }
        internet = [ordered]@{
            ok        = $d["InternetOk"]
            target    = $d["InternetTarget"]
            latencyMs = $d["InternetLatencyMs"]
            latencyStr= $intLatStr
            detail    = if ($d["InternetOk"]) { "Internet reachable ($intLatStr)" } else { "Internet unreachable" }
        }
        dns      = [ordered]@{
            ok       = $d["DnsOk"]
            resolved = $d["DnsResolved"]
            servers  = @($d["DNSServers"])
            detail   = if ($d["DnsOk"]) { "Resolved $($d['DnsResolved'])" } else { "Name resolution failing" }
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
    $Result.ExportData["rebootRequired"] = if ($null -ne $d["RebootRequired"]) {
        $d["RebootRequired"]
    } else { $false }
}
