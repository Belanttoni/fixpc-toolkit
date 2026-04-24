<#
.SYNOPSIS
    FixPC Toolkit — Network Module: Collect Phase
    Non-mutating collection of all network diagnostic data.
    Scriptblock stored as $Script:Collect_Network.

    Rule: Collect must NEVER repair or mutate. All read-only.

    Data keys set:
        Adapters            — all net adapters (Get-NetAdapter)
        AdapterCount        — total count
        ActiveAdapters      — adapters with Status = Up
        IPConfigs           — all Get-NetIPConfiguration results
        PrimaryConfig       — best interface: Up + gateway first, then Up + any IP
        AdapterName         — primary adapter alias (InterfaceAlias)
        AdapterType         — "Ethernet" | "Wi-Fi" | "Unknown"
        SSID                — SSID string if Wi-Fi, else $null
        LocalIP             — primary IPv4 address string, or $null
        PrefixLength        — subnet prefix (e.g. 24), or $null
        Gateway             — default gateway IP string, or $null
        DNSServers          — array of DNS server IP strings
        IsDhcp              — bool: IP obtained via DHCP
        ApipaOnPrimary      — bool: primary/selected adapter has a 169.254.x.x address
        ApipaDetected       — bool: ANY non-loopback adapter has a 169.254.x.x address
                              (includes VPN, Bluetooth, disconnected NICs — informational only)
        AllIPv4s            — all non-loopback IPv4 address objects
        LoopbackOk          — bool: 127.0.0.1 ping
        LocalIPOk           — bool: local IP self-ping ($null if no IP)
        GatewayOk           — bool: gateway ICMP ping
        GatewayLatencyMs    — gateway avg response ms, or $null
        InternetOk          — bool: public IP ICMP ping (8.8.8.8 / 1.1.1.1)
        InternetLatencyMs   — internet avg response ms, or $null
        InternetTarget      — which public IP responded
        DnsOk               — bool: DNS hostname resolution result
        DnsResolved         — which hostname resolved, or $null
        Port443Ok           — bool: TCP 443 to 1.1.1.1 (Cloudflare HTTPS, best-effort)
        RebootRequired      — bool: populated by Repair phase if stack reset ran

    Notes on APIPA detection:
        ApipaOnPrimary is the diagnostic signal — it reflects whether the adapter
        actually selected for routing has a self-assigned address.
        ApipaDetected is informational — VPN tap adapters, Bluetooth PAN, and
        disconnected secondary NICs commonly hold 169.254.x.x addresses; they
        must not contaminate the diagnosis of the primary connection.

.VERSION 1.2
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
    $activeAdapters = if ($adapters) { @($adapters | Where-Object { $_.Status -eq "Up" }) } else { @() }
    $Result.Data["ActiveAdapters"] = $activeAdapters

    if ($adapters) {
        $adapterSummary = (@($adapters) | ForEach-Object { "$($_.Name) [$($_.Status)]" }) -join ", "
        Push-LogMessage -State $State `
            -Message "  Adapters found: $(@($adapters).Count) total | Active: $($activeAdapters.Count) | $adapterSummary" `
            -Type "info"
    } else {
        Push-LogMessage -State $State -Message "  No network adapters detected." -Type "warn"
    }

    # ============================================================
    #  IP CONFIGURATION  — select best primary interface
    #  Priority 1: Up adapter with a default IPv4 gateway
    #  Priority 2: Up adapter with any IPv4 address (no gateway)
    # ============================================================
    $ipConfigs = Get-NetIPConfiguration -ErrorAction SilentlyContinue
    $Result.Data["IPConfigs"] = $ipConfigs

    $upAliases = @($activeAdapters | Select-Object -ExpandProperty Name)

    # Physical-adapter alias set: exclude virtual/VPN/tunnel adapters from the
    # top-priority selection.  TAP (OpenVPN), Hyper-V, Bluetooth PAN, WAN Miniport,
    # and similar virtual adapters frequently carry default routes that would
    # otherwise win Priority 1, masking the real physical connection.
    $virtualDescPattern = "TAP-Windows|TAP Adapter|Hyper-V|Bluetooth|WAN Miniport|" +
                          "Tunnel|Pseudo Interface|Loopback|VPN|tun|tap"
    $physicalUpAliases  = @($activeAdapters | Where-Object {
        $_.InterfaceDescription -notmatch $virtualDescPattern
    } | Select-Object -ExpandProperty Name)

    $primary = $null
    if ($ipConfigs) {
        # Priority 1 — physical Up adapter with a default IPv4 gateway
        $primary = @($ipConfigs | Where-Object {
            $_.IPv4DefaultGateway -and ($physicalUpAliases -contains $_.InterfaceAlias)
        }) | Select-Object -First 1

        # Priority 2 — any Up adapter with a default IPv4 gateway (includes virtual)
        if (-not $primary) {
            $primary = @($ipConfigs | Where-Object {
                $_.IPv4DefaultGateway -and ($upAliases -contains $_.InterfaceAlias)
            }) | Select-Object -First 1
        }

        # Priority 3 — physical Up adapter with any IPv4 (no gateway)
        if (-not $primary) {
            $primary = @($ipConfigs | Where-Object {
                $_.IPv4Address -and ($physicalUpAliases -contains $_.InterfaceAlias)
            }) | Select-Object -First 1
        }

        # Priority 4 — any Up adapter with any IPv4
        if (-not $primary) {
            $primary = @($ipConfigs | Where-Object {
                $_.IPv4Address -and ($upAliases -contains $_.InterfaceAlias)
            }) | Select-Object -First 1
        }

        # Last resort — any config that has an IP
        if (-not $primary) {
            $primary = @($ipConfigs | Where-Object { $_.IPv4Address }) | Select-Object -First 1
        }
    }
    $Result.Data["PrimaryConfig"] = $primary

    if ($primary) {
        $ipEntry                     = $primary.IPv4Address | Select-Object -First 1
        $Result.Data["LocalIP"]      = if ($ipEntry)                    { $ipEntry.IPAddress    } else { $null }
        $Result.Data["PrefixLength"] = if ($ipEntry)                    { $ipEntry.PrefixLength } else { $null }
        $Result.Data["Gateway"]      = if ($primary.IPv4DefaultGateway) { $primary.IPv4DefaultGateway.NextHop } else { $null }
        $Result.Data["DNSServers"]   = if ($primary.DNSServer -and $primary.DNSServer.ServerAddresses) {
            @($primary.DNSServer.ServerAddresses)
        } else { @() }
        $Result.Data["AdapterName"]  = $primary.InterfaceAlias
    } else {
        $Result.Data["LocalIP"]      = $null
        $Result.Data["PrefixLength"] = $null
        $Result.Data["Gateway"]      = $null
        $Result.Data["DNSServers"]   = @()
        $Result.Data["AdapterName"]  = $null
    }

    # ============================================================
    #  ADAPTER TYPE (Ethernet / Wi-Fi) AND SSID
    # ============================================================
    $adapterType = "Unknown"
    $ssid        = $null

    $primaryAdapter = $null
    if ($primary -and $adapters) {
        $primaryAdapter = $adapters | Where-Object { $_.Name -eq $primary.InterfaceAlias } | Select-Object -First 1
    }
    if (-not $primaryAdapter -and $activeAdapters.Count -gt 0) {
        $primaryAdapter = $activeAdapters[0]
    }

    if ($primaryAdapter) {
        $mediaType = "$($primaryAdapter.PhysicalMediaType)"
        $desc      = "$($primaryAdapter.InterfaceDescription)"
        if ($mediaType -match "802\.11" -or $mediaType -eq "Native 802.11" -or
            $desc -match "Wi-Fi|Wireless|WLAN|802\.11") {
            $adapterType = "Wi-Fi"
        } elseif ($mediaType -match "802\.3" -or $desc -match "Ethernet|Gigabit|LAN|RJ-?45") {
            $adapterType = "Ethernet"
        } elseif ($primaryAdapter.Status -eq "Up") {
            $adapterType = "Ethernet"
        }

        if ($adapterType -eq "Wi-Fi") {
            try {
                $profile = Get-NetConnectionProfile -InterfaceAlias $primaryAdapter.Name -ErrorAction SilentlyContinue
                if ($profile -and $profile.Name) { $ssid = $profile.Name }
            } catch { }
            if (-not $ssid) {
                try {
                    $wlanLines = @(& netsh wlan show interfaces 2>&1)
                    $ssidLine  = $wlanLines | Where-Object { $_ -match "^\s+SSID\s+:" -and $_ -notmatch "BSSID" } |
                                 Select-Object -First 1
                    if ($ssidLine -match ":\s+(.+)$") { $ssid = $Matches[1].Trim() }
                } catch { }
            }
        }
    }

    $Result.Data["AdapterType"] = $adapterType
    $Result.Data["SSID"]        = $ssid

    # ============================================================
    #  DHCP DETECTION
    # ============================================================
    $isDhcp = $false
    if ($primary) {
        try {
            $ipAddrObj = Get-NetIPAddress -InterfaceIndex $primary.InterfaceIndex `
                -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ipAddrObj) { $isDhcp = ($ipAddrObj.PrefixOrigin -eq "Dhcp") }
        } catch { }
    }
    $Result.Data["IsDhcp"] = $isDhcp

    # ============================================================
    #  APIPA DETECTION
    #  ApipaOnPrimary — the diagnostic flag: true only when the selected
    #  primary adapter's own IP is 169.254.x.x.
    #  ApipaDetected  — informational flag: true if ANY adapter has APIPA
    #  (VPN taps, Bluetooth, disconnected NICs frequently self-assign 169.254.x.x
    #  and must not be confused with a DHCP failure on the primary connection).
    # ============================================================
    $allIPv4 = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
               Where-Object { $_.InterfaceAlias -notmatch "Loopback" }

    $apipaAll  = @($allIPv4 | Where-Object { $_.IPAddress -like "169.254.*" })
    $localIP   = $Result.Data["LocalIP"]
    $primAlias = $Result.Data["AdapterName"]

    # APIPA on primary: primary adapter's own IP is self-assigned
    $apipaOnPrimary = $localIP -like "169.254.*"

    $Result.Data["AllIPv4s"]       = $allIPv4
    $Result.Data["ApipaOnPrimary"] = $apipaOnPrimary
    $Result.Data["ApipaDetected"]  = ($apipaAll.Count -gt 0)

    # ── IP configuration summary log ──────────────────────────
    $gateway      = $Result.Data["Gateway"]
    $prefixLength = $Result.Data["PrefixLength"]
    $dnsServers   = @($Result.Data["DNSServers"])
    $adapterName  = $Result.Data["AdapterName"]

    $ssidStr   = if ($ssid) { " (SSID: $ssid)" } else { "" }
    $prefixStr = if ($prefixLength) { "/$prefixLength" } else { "" }
    $dhcpStr   = if ($isDhcp) { "DHCP" } else { "Static" }
    $dnsStr    = if ($dnsServers.Count -gt 0) { $dnsServers -join ", " } else { "none" }

    if ($adapterName) {
        Push-LogMessage -State $State `
            -Message "  Primary adapter: $adapterName ($adapterType)$ssidStr" -Type "info"
        Push-LogMessage -State $State `
            -Message "  IP: $(if ($localIP) { "$localIP$prefixStr" } else { 'none' })  [$dhcpStr]  |  GW: $(if ($gateway) { $gateway } else { 'none' })  |  DNS: $dnsStr" `
            -Type "info"
    }

    # Log APIPA context with clear scope attribution
    if ($apipaOnPrimary) {
        Push-LogMessage -State $State `
            -Message "  APIPA on primary adapter ($adapterName): $localIP — DHCP lease failed on the selected connection." `
            -Type "warn"
    } elseif ($apipaAll.Count -gt 0) {
        $otherApipaAdapters = ($apipaAll | Select-Object -ExpandProperty InterfaceAlias -Unique) -join ", "
        $otherApipaIPs      = ($apipaAll | Select-Object -ExpandProperty IPAddress) -join ", "
        Push-LogMessage -State $State `
            -Message "  APIPA ($otherApipaIPs) on non-primary adapter(s): $otherApipaAdapters — does NOT affect primary connection." `
            -Type "info"
    }

    # ============================================================
    #  CONNECTIVITY TESTS  (all read-only — ping / DNS / TCP)
    # ============================================================
    Push-LogMessage -State $State -Message "  Running connectivity tests..." -Type "info"

    # ── Test 1: Loopback — verifies TCP/IP stack is functional ─
    $loopbackOk = $false
    try {
        $loopbackOk = [bool](Test-Connection -ComputerName "127.0.0.1" `
            -Count 1 -Quiet -ErrorAction SilentlyContinue)
    } catch { }
    $Result.Data["LoopbackOk"] = $loopbackOk
    Push-LogMessage -State $State `
        -Message "  Loopback (127.0.0.1): $(if ($loopbackOk) { 'OK' } else { 'FAIL' })" `
        -Type $(if ($loopbackOk) { "ok" } else { "error" })

    # ── Test 2: Local IP self-ping ────────────────────────────
    $localIPOk = $null
    if ($localIP) {
        try {
            $localIPOk = [bool](Test-Connection -ComputerName $localIP `
                -Count 1 -Quiet -ErrorAction SilentlyContinue)
        } catch { $localIPOk = $false }
        Push-LogMessage -State $State `
            -Message "  Local IP ping ($localIP): $(if ($localIPOk) { 'OK' } else { 'FAIL' })" `
            -Type $(if ($localIPOk) { "ok" } else { "warn" })
    } else {
        Push-LogMessage -State $State `
            -Message "  Local IP ping: skipped (no IP assigned)." -Type "info"
    }
    $Result.Data["LocalIPOk"] = $localIPOk

    # ── Test 3: Gateway ICMP ping ─────────────────────────────
    $gwOk = $false; $gwLatencyMs = $null

    if ($gateway) {
        try {
            $pings = Test-Connection -ComputerName $gateway -Count 2 -ErrorAction SilentlyContinue
            if ($pings) {
                $ok = @($pings | Where-Object { $_.StatusCode -eq 0 })
                $gwOk = $ok.Count -gt 0
                if ($gwOk) {
                    $gwLatencyMs = [math]::Round(($ok | Measure-Object -Property ResponseTime -Average).Average, 0)
                }
            }
        } catch { $gwOk = $false }
        $latStr = if ($null -ne $gwLatencyMs) { " (${gwLatencyMs}ms)" } else { "" }
        Push-LogMessage -State $State `
            -Message "  Gateway ICMP ($gateway): $(if ($gwOk) { "OK$latStr" } else { 'no response (ICMP may be filtered)' })" `
            -Type $(if ($gwOk) { "ok" } else { "info" })
    } else {
        Push-LogMessage -State $State `
            -Message "  Gateway ICMP: skipped (no gateway configured)." -Type "info"
    }
    $Result.Data["GatewayOk"]        = $gwOk
    $Result.Data["GatewayLatencyMs"] = $gwLatencyMs

    # ── Test 4: Internet ICMP (best-effort — commonly blocked) ─
    # Note: ICMP to public IPs is frequently filtered by ISPs and corporate
    # firewalls.  DNS resolution (Test 5) is a stronger connectivity signal.
    $intOk = $false; $intLatencyMs = $null; $intTarget = $null

    foreach ($target in @("8.8.8.8", "1.1.1.1")) {
        try {
            $pings = Test-Connection -ComputerName $target -Count 2 -ErrorAction SilentlyContinue
            if ($pings) {
                $ok = @($pings | Where-Object { $_.StatusCode -eq 0 })
                if ($ok.Count -gt 0) {
                    $intOk        = $true
                    $intTarget    = $target
                    $intLatencyMs = [math]::Round(($ok | Measure-Object -Property ResponseTime -Average).Average, 0)
                    break
                }
            }
        } catch { }
    }
    $intLatStr = if ($null -ne $intLatencyMs) { " (${intLatencyMs}ms)" } else { "" }
    Push-LogMessage -State $State `
        -Message "  Internet ICMP ($(if ($intTarget) { $intTarget } else { '8.8.8.8/1.1.1.1' })): $(if ($intOk) { "OK$intLatStr" } else { 'no response (ICMP may be filtered)' })" `
        -Type $(if ($intOk) { "ok" } else { "info" })
    $Result.Data["InternetOk"]        = $intOk
    $Result.Data["InternetLatencyMs"] = $intLatencyMs
    $Result.Data["InternetTarget"]    = $intTarget

    # ── Test 5: DNS name resolution (primary connectivity signal) ─
    # DNS resolution success is stronger evidence of internet access than ICMP,
    # because DNS queries traverse the full network path (gateway → ISP → resolver).
    $dnsOk = $false; $dnsResolved = $null

    foreach ($name in @("google.com", "microsoft.com")) {
        try {
            $res = Resolve-DnsName -Name $name -Type A -ErrorAction SilentlyContinue
            if ($res) { $dnsOk = $true; $dnsResolved = $name; break }
        } catch {
            try {
                $ips = [System.Net.Dns]::GetHostAddresses($name)
                if ($ips -and $ips.Count -gt 0) { $dnsOk = $true; $dnsResolved = $name; break }
            } catch { }
        }
    }
    Push-LogMessage -State $State `
        -Message "  DNS resolution ($(if ($dnsResolved) { $dnsResolved } else { 'google.com' })): $(if ($dnsOk) { 'OK' } else { 'FAIL' })" `
        -Type $(if ($dnsOk) { "ok" } else { "warn" })
    $Result.Data["DnsOk"]       = $dnsOk
    $Result.Data["DnsResolved"] = $dnsResolved

    # ── Test 6: TCP port 443 to 1.1.1.1 (Cloudflare HTTPS) ───
    # Tests real TCP connectivity independent of ICMP.
    # Target: 1.1.1.1:443 — Cloudflare serves HTTPS on this address.
    # Attempted whenever any connectivity evidence exists (ICMP or DNS).
    $port443Ok = $false
    $hasAnyConnectivity = $intOk -or $dnsOk
    if ($hasAnyConnectivity) {
        try {
            $nc = Test-NetConnection -ComputerName "1.1.1.1" -Port 443 `
                -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            $port443Ok = ($null -ne $nc -and $nc.TcpTestSucceeded -eq $true)
            Push-LogMessage -State $State `
                -Message "  TCP 443 (1.1.1.1:443 — Cloudflare HTTPS): $(if ($port443Ok) { 'OK' } else { 'no response' })" `
                -Type $(if ($port443Ok) { "ok" } else { "info" })
        } catch {
            Push-LogMessage -State $State `
                -Message "  TCP 443: test skipped ($($_.Exception.Message))" -Type "info"
        }
    } else {
        Push-LogMessage -State $State `
            -Message "  TCP 443: skipped (no connectivity evidence — ICMP and DNS both failed)." -Type "info"
    }
    $Result.Data["Port443Ok"] = $port443Ok

    # ── Reboot flag (populated by Repair_Network if needed) ───
    $Result.Data["RebootRequired"] = $false
}
