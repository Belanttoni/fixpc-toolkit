<#
.SYNOPSIS
    FixPC Toolkit — Network Module: Collect Phase
    Non-mutating collection of all network diagnostic data.
    Scriptblock stored as $Script:Collect_Network.

    Rule: Collect must NEVER repair or mutate. All read-only.

.VERSION 1.0
#>

$Script:Collect_Network = {
    param($Result, $State)

    Push-LogMessage -State $State -Message "  Inventorying network adapters..." -Type "info"

    # ============================================================
    #  ADAPTER INVENTORY
    # ============================================================
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
    $Result.Data["Adapters"]       = $adapters
    $Result.Data["AdapterCount"]   = if ($adapters) { @($adapters).Count } else { 0 }
    $Result.Data["ActiveAdapters"] = if ($adapters) {
        @($adapters | Where-Object { $_.Status -eq "Up" })
    } else { @() }

    # ============================================================
    #  IP CONFIGURATION
    # ============================================================
    $ipConfigs = Get-NetIPConfiguration -ErrorAction SilentlyContinue
    $Result.Data["IPConfigs"] = $ipConfigs

    # Primary config = first interface with a default IPv4 gateway
    $primary = $ipConfigs | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
    $Result.Data["PrimaryConfig"] = $primary

    if ($primary) {
        $ipEntry                     = $primary.IPv4Address | Select-Object -First 1
        $Result.Data["LocalIP"]      = if ($ipEntry) { $ipEntry.IPAddress    } else { $null }
        $Result.Data["PrefixLength"] = if ($ipEntry) { $ipEntry.PrefixLength } else { $null }
        $Result.Data["Gateway"]      = $primary.IPv4DefaultGateway.NextHop
        $Result.Data["DNSServers"]   = @($primary.DNSServer.ServerAddresses)
        $Result.Data["AdapterName"]  = $primary.InterfaceAlias
    } else {
        $Result.Data["LocalIP"]      = $null
        $Result.Data["PrefixLength"] = $null
        $Result.Data["Gateway"]      = $null
        $Result.Data["DNSServers"]   = @()
        $Result.Data["AdapterName"]  = $null
    }

    # ── APIPA detection (169.254.x.x = DHCP failure) ─────────
    # Check all non-loopback IPv4 addresses across all adapters
    $allIPv4 = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
               Where-Object { $_.InterfaceAlias -notmatch "Loopback" }
    $apipa   = @($allIPv4 | Where-Object { $_.IPAddress -like "169.254.*" })

    $Result.Data["AllIPv4s"]      = $allIPv4
    $Result.Data["ApipaDetected"] = ($apipa.Count -gt 0)

    # ============================================================
    #  CONNECTIVITY TESTS  (all read-only — ping / DNS lookup)
    # ============================================================
    Push-LogMessage -State $State -Message "  Running connectivity tests..." -Type "info"

    # ── Layer 1: Loopback — tests TCP/IP stack health ─────────
    # -Quiet returns $true/$false; single packet is enough to verify stack
    $Result.Data["LoopbackOk"] = Test-Connection -ComputerName "127.0.0.1" `
        -Count 1 -Quiet -ErrorAction SilentlyContinue

    # ── Layer 2: Gateway reachability ─────────────────────────
    $gwOk = $false; $gwLatencyMs = $null
    $gateway = $Result.Data["Gateway"]

    if ($gateway) {
        try {
            $pings = Test-Connection -ComputerName $gateway -Count 2 -ErrorAction SilentlyContinue
            if ($pings) {
                $ok = @($pings | Where-Object { $_.StatusCode -eq 0 })
                $gwOk = $ok.Count -gt 0
                if ($gwOk -and $ok) {
                    $avg = ($ok | Measure-Object -Property ResponseTime -Average).Average
                    $gwLatencyMs = [math]::Round($avg, 0)
                }
            }
        } catch { $gwOk = $false }
    }
    $Result.Data["GatewayOk"]        = $gwOk
    $Result.Data["GatewayLatencyMs"] = $gwLatencyMs

    # ── Layer 3: Internet reachability ────────────────────────
    # Try two well-known public IPs; first success wins
    $intOk = $false; $intLatencyMs = $null; $intTarget = $null

    foreach ($target in @("8.8.8.8", "1.1.1.1")) {
        try {
            $pings = Test-Connection -ComputerName $target -Count 2 -ErrorAction SilentlyContinue
            if ($pings) {
                $ok = @($pings | Where-Object { $_.StatusCode -eq 0 })
                if ($ok.Count -gt 0) {
                    $intOk     = $true
                    $intTarget = $target
                    $avg = ($ok | Measure-Object -Property ResponseTime -Average).Average
                    $intLatencyMs = [math]::Round($avg, 0)
                    break
                }
            }
        } catch { }
    }
    $Result.Data["InternetOk"]        = $intOk
    $Result.Data["InternetLatencyMs"] = $intLatencyMs
    $Result.Data["InternetTarget"]    = $intTarget

    # ── Layer 4: DNS name resolution ──────────────────────────
    # Try two hostnames; .NET fallback if Resolve-DnsName unavailable
    $dnsOk = $false; $dnsResolved = $null

    foreach ($name in @("google.com", "microsoft.com")) {
        try {
            $res = Resolve-DnsName -Name $name -Type A -ErrorAction SilentlyContinue
            if ($res) { $dnsOk = $true; $dnsResolved = $name; break }
        } catch {
            try {
                $ips = [System.Net.Dns]::GetHostAddresses($name)
                if ($ips) { $dnsOk = $true; $dnsResolved = $name; break }
            } catch { }
        }
    }
    $Result.Data["DnsOk"]       = $dnsOk
    $Result.Data["DnsResolved"] = $dnsResolved

    # ── Reboot flag (populated by Repair_Network if needed) ───
    $Result.Data["RebootRequired"] = $false
}
