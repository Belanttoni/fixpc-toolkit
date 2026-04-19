<#
.SYNOPSIS
    FixPC Toolkit — HTML Report Generator
    Produces a styled dark-theme HTML report from a ConsolidatedReport object.
    NO dependency on UI layer.

.VERSION 1.0
#>

function Export-HtmlReport {
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Report,
        [Parameter(Mandatory)] [string]         $OutputPath
    )

    Write-LogInfo -Source "Reports.HTML" -Message "Generating HTML report: $OutputPath"

    $ram   = $Report.RamPct
    $disk  = $Report.DiskPct
    $cpu   = $Report.CpuLoad

    $warnHtml = if ($Report.AllWarnings.Count -gt 0) {
        $items = ($Report.AllWarnings | ForEach-Object { "<li>$(Escape-Html $_)</li>" }) -join ""
        "<div class='warn-box'><h3>Action Items / Warnings</h3><ul>$items</ul></div>"
    } else {
        "<div class='ok-box'><h3>No warnings — system appears healthy</h3></div>"
    }

    $sectionsHtml = ($Report.ModuleResults | ForEach-Object { Build-ModuleHtmlSection -Result $_ }) -join "`n"

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>FixPC Report — $($Report.Computer)</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Segoe UI',Arial,sans-serif;background:#0d0d1a;color:#dde}
.header{background:linear-gradient(135deg,#0d1b2a,#1b2838,#0f3460);padding:28px 36px;border-bottom:3px solid #00d4ff}
.header h1{color:#00d4ff;font-size:1.8em;margin-bottom:5px}
.header .meta{color:#7788aa;font-size:.85em;margin-top:6px}
.header .meta span{margin-right:20px}
.container{max-width:1150px;margin:24px auto;padding:0 18px}
.perf-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:24px}
.perf-card{background:#131326;border:1px solid #2a2a4a;border-radius:10px;padding:18px;text-align:center}
.perf-card h3{font-size:.75em;color:#7788aa;text-transform:uppercase;letter-spacing:1px;margin-bottom:6px}
.perf-card .val{font-size:2em;font-weight:700}
.bar-bg{background:#1e1e3a;border-radius:20px;height:6px;margin-top:6px}
.bar-fill{height:6px;border-radius:20px}
.section{background:#131326;border:1px solid #1e1e3a;border-radius:10px;padding:22px;margin-bottom:16px}
.section h2{color:#fff;font-size:1em;margin-bottom:14px;display:flex;align-items:center;gap:10px}
.content{color:#b0b8cc;font-size:.86em;line-height:1.65}
table{width:100%;border-collapse:collapse;margin-top:10px;font-size:.82em}
th{background:#0f2040;color:#00c8ff;padding:8px 12px;text-align:left;font-weight:600}
td{padding:7px 12px;border-bottom:1px solid #1e1e3a}
tr:hover td{background:#1a1a35}
.ok{color:#28a745;font-weight:700}
.warn{color:#ffc107;font-weight:700}
.error{color:#ff4d6d;font-weight:700}
tr.warn td{background:rgba(255,193,7,.04)}
tr.error td{background:rgba(255,77,109,.06)}
.badge{font-size:.68em;padding:3px 9px;border-radius:20px;font-weight:700;letter-spacing:.5px}
.badge-ok   {background:#0d3320;color:#28a745;border:1px solid #28a745}
.badge-warn {background:#332a00;color:#ffc107;border:1px solid #ffc107}
.badge-error{background:#330a14;color:#ff4d6d;border:1px solid #ff4d6d}
.badge-info {background:#0a2233;color:#17a2b8;border:1px solid #17a2b8}
.warn-box{background:#1a1200;border:1px solid #ffc107;border-radius:8px;padding:16px;margin-bottom:22px}
.warn-box h3{color:#ffc107;margin-bottom:8px}
.warn-box ul{padding-left:18px}
.warn-box li{margin-bottom:5px;color:#ddc}
.ok-box{background:#0a1f10;border:1px solid #28a745;border-radius:8px;padding:16px;margin-bottom:22px}
.ok-box h3{color:#28a745}
.summary-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:22px}
.summary-card{background:#131326;border:1px solid #2a2a4a;border-radius:8px;padding:14px;text-align:center}
.summary-card .num{font-size:2em;font-weight:700}
.summary-card .lbl{font-size:.75em;color:#7788aa;text-transform:uppercase;margin-top:4px}
p{margin-bottom:6px}
ul{padding-left:18px;margin-top:4px}
li{margin-bottom:3px}
pre{background:#0a0a14;padding:12px;border-radius:6px;font-size:.75em;overflow:auto;max-height:180px;color:#aab;margin-top:8px}
.footer{text-align:center;padding:20px;color:#445;font-size:.75em;border-top:1px solid #1e1e3a;margin-top:28px}
</style>
</head>
<body>
<div class="header">
  <h1>FixPC Toolkit — Diagnostic Report</h1>
  <div class="meta">
    <span><strong>Computer:</strong> $($Report.Computer)</span>
    <span><strong>User:</strong> $($Report.User)</span>
    <span><strong>Mode:</strong> $($Report.ExecutionMode)</span>
    <span><strong>Date:</strong> $(Format-Timestamp $Report.StartTime)</span>
    <span><strong>Session:</strong> $($Report.SessionId)</span>
    <span><strong>Duration:</strong> $($Report.TotalDuration)</span>
  </div>
</div>

<div class="container">

  $warnHtml

  <!-- Summary Stats -->
  <div class="summary-grid">
    <div class="summary-card"><div class="num ok">$($Report.OkCount)</div><div class="lbl">Modules OK</div></div>
    <div class="summary-card"><div class="num warn">$($Report.WarnCount)</div><div class="lbl">Warnings</div></div>
    <div class="summary-card"><div class="num error">$($Report.ErrorCount)</div><div class="lbl">Errors</div></div>
    <div class="summary-card"><div class="num" style="color:#17a2b8">$($Report.FindingsTotal)</div><div class="lbl">Total Findings</div></div>
  </div>

  <!-- Performance Gauges -->
  <div class="perf-grid">
    <div class="perf-card">
      <h3>CPU Load</h3>
      <div class="val" style="color:$(Get-GaugeColor $cpu 60 80)">$cpu%</div>
      <div class="bar-bg"><div class="bar-fill" style="width:$cpu%;background:$(Get-GaugeColor $cpu 60 80)"></div></div>
    </div>
    <div class="perf-card">
      <h3>RAM Usage</h3>
      <div class="val" style="color:$(Get-GaugeColor $ram 70 85)">$ram%</div>
      <div class="bar-bg"><div class="bar-fill" style="width:$ram%;background:$(Get-GaugeColor $ram 70 85)"></div></div>
    </div>
    <div class="perf-card">
      <h3>Disk C: Used</h3>
      <div class="val" style="color:$(Get-GaugeColor $disk 80 90)">$disk%</div>
      <div class="bar-bg"><div class="bar-fill" style="width:$disk%;background:$(Get-GaugeColor $disk 80 90)"></div></div>
    </div>
  </div>

  $sectionsHtml

  <div class="footer">
    FixPC Toolkit v1.0 &nbsp;|&nbsp; $(Format-Timestamp) &nbsp;|&nbsp; $($Report.Computer) &nbsp;|&nbsp; Session $($Report.SessionId)
  </div>
</div>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-LogInfo -Source "Reports.HTML" -Message "HTML report written: $OutputPath"
}

# ============================================================
#  HELPERS
# ============================================================
function Get-GaugeColor {
    param([double]$Value, [double]$WarnAt, [double]$ErrorAt)
    if ($Value -ge $ErrorAt) { return '#ff4d6d' }
    if ($Value -ge $WarnAt)  { return '#ffc107' }
    return '#28a745'
}

function Get-SectionBadge {
    param([string]$Severity)
    switch ($Severity.ToLower()) {
        "critical" { return "<span class='badge badge-error'>CRITICAL</span>" }
        "error"    { return "<span class='badge badge-error'>ERROR</span>"    }
        "warn"     { return "<span class='badge badge-warn'>WARNING</span>"   }
        "info"     { return "<span class='badge badge-ok'>OK</span>"          }
        "ok"       { return "<span class='badge badge-ok'>OK</span>"          }
        default    { return "<span class='badge badge-info'>INFO</span>"      }
    }
}

function Get-SectionBorderColor {
    param([string]$Severity)
    switch ($Severity.ToLower()) {
        "critical" { return "#ff4d6d" }
        "error"    { return "#ff4d6d" }
        "warn"     { return "#ffc107" }
        "info"     { return "#28a745" }
        "ok"       { return "#28a745" }
        default    { return "#17a2b8" }
    }
}

function Build-ModuleHtmlSection {
    param([PSCustomObject]$Result)

    $badge      = Get-SectionBadge -Severity $Result.Severity
    $color      = Get-SectionBorderColor -Severity $Result.Severity
    $cssClass   = Convert-SeverityToHtmlClass -Severity $Result.Severity
    $durStr     = Format-Duration -Seconds $Result.DurationSeconds
    $innerHtml  = Build-ModuleSectionContent -Result $Result

    return @"
<div class='section'>
  <h2 style='border-left:5px solid $color;padding-left:12px'>
    $($Result.ModuleName) $badge
    <span style='font-weight:normal;font-size:.8em;color:#555;margin-left:auto'>$durStr</span>
  </h2>
  <div class='content'>$innerHtml</div>
</div>
"@
}

function Build-ModuleSectionContent {
    param([PSCustomObject]$Result)

    $ex = $Result.ExportData

    switch ($Result.ModuleName) {

        "System Information" {
            if (-not $ex["rows"]) { return "<p>No data collected.</p>" }
            $rows = ($ex["rows"] | ForEach-Object {
                $cls = if ($_.CssClass) { " class='$($_.CssClass)'" } else { "" }
                "<tr><td>$($_.Item)</td><td>$($_.Value)</td><td$cls>$($_.Status)</td></tr>"
            }) -join ""
            return "<table><tr><th>Item</th><th>Value</th><th>Status</th></tr>$rows</table>"
        }

        "SFC /scannow" {
            $summary    = if ($ex["summary"])    { Escape-Html $ex["summary"] } else { "No summary available." }
            $repaired   = $ex["repaired"] -eq $true
            $repairNote = if ($ex["repairNote"])  { "<p><small><em>$(Escape-Html $ex['repairNote'])</em></small></p>" } else { "" }
            $log        = if ($ex["logFile"])     { "<p><small>Log: $(Escape-Html $ex['logFile'])</small></p>" } else { "" }
            $badge      = if ($repaired) { "<span class='badge badge-ok'>REPAIRED</span>" } else { "" }
            return "<p>$summary $badge</p>$repairNote$log"
        }

        "DISM RestoreHealth" {
            $summary    = if ($ex["summary"])    { Escape-Html $ex["summary"] } else { "No summary available." }
            $repaired   = $ex["repaired"] -eq $true
            $repairNote = if ($ex["repairNote"])  { "<p><small><em>$(Escape-Html $ex['repairNote'])</em></small></p>" } else { "" }
            $log        = if ($ex["logFile"])     { "<p><small>Log: $(Escape-Html $ex['logFile'])</small></p>" } else { "" }
            $badge      = if ($repaired) { "<span class='badge badge-ok'>REPAIRED</span>" } else { "" }
            return "<p>$summary $badge</p>$repairNote$log"
        }

        "CHKDSK /scan+/spotfix" {
            $summary  = if ($ex["summary"])  { Escape-Html $ex["summary"] } else { "" }
            $repaired = $ex["repaired"] -eq $true
            $badge    = if ($repaired) { "<span class='badge badge-ok'>REPAIRED</span>" } else { "" }
            $method   = if ($ex["method"])   { "<p><small>Method: $(Escape-Html $ex['method'])</small></p>" } else { "" }
            return "<p>$summary $badge</p>$method"
        }

        "Clear Temp Files" {
            $freed = if ($null -ne $ex["totalFreedMB"]) { $ex["totalFreedMB"] } else { 0 }
            return "<p>Total space freed: <strong>$freed MB</strong></p>"
        }

        "Event Viewer" {
            $count = if ($null -ne $ex["count"]) { $ex["count"] } else { 0 }
            if ($count -eq 0) { return "<p>No critical events found in the last 24 hours.</p>" }
            $rows = if ($ex["rows"]) {
                ($ex["rows"] | ForEach-Object {
                    "<tr class='$($_.Class)'><td>$($_.Time)</td><td>$($_.Level)</td><td>$(Escape-Html $_.Source)</td><td>$($_.Id)</td><td>$(Escape-Html $_.Message)</td></tr>"
                }) -join ""
            } else { "" }
            return "<p>$count events found (showing latest 30):</p><table><tr><th>Time</th><th>Level</th><th>Source</th><th>ID</th><th>Message</th></tr>$rows</table>"
        }

        "Windows Update" {
            $cnt    = if ($null -ne $ex["pendingCount"])  { $ex["pendingCount"]  } else { 0 }
            $reboot = if ($null -ne $ex["rebootRequired"]) { $ex["rebootRequired"] } else { $false }
            if ($cnt -eq -1) { return "<p>Could not check Windows Update. Verify manually via Settings.</p>" }
            if ($cnt -eq 0)  { return "<p>System is fully up to date.</p>" }
            $installed  = $Result.ActionsTaken.Count -gt 0
            $statusLine = if ($installed) { "<p>$cnt updates installed.</p>" } else { "<p>$cnt updates pending (not installed — run in SafeRepair or FullRepair mode).</p>" }
            $list       = if ($ex["titles"]) { "<ul>" + (($ex["titles"] | Select-Object -First 15 | ForEach-Object { "<li>$(Escape-Html $_)</li>" }) -join "") + "</ul>" } else { "" }
            $rebootNote = if ($reboot) { "<p class='warn'><strong>Reboot required.</strong></p>" } else { "" }
            return "$statusLine$list$rebootNote"
        }

        "Startup Programs" {
            $count = if ($null -ne $ex["count"]) { $ex["count"] } else { 0 }
            if (-not $ex["items"]) { return "<p>$count startup items found.</p>" }
            $rows = ($ex["items"] | ForEach-Object {
                "<tr><td>$(Escape-Html $_.Name)</td><td>$(Escape-Html $_.Command)</td><td>$($_.Scope)</td></tr>"
            }) -join ""
            return "<p>$count startup items detected:</p><table><tr><th>Name</th><th>Command</th><th>Scope</th></tr>$rows</table>"
        }

        "Disk SMART Health" {
            if (-not $ex["drives"]) { return "<p>Could not retrieve disk health data.</p>" }
            $rows = ($ex["drives"] | ForEach-Object {
                "<tr class='$($_.Class)'><td>$(Escape-Html $_.Name)</td><td>$($_.Type)</td><td>$($_.SizeGB) GB</td><td>$($_.Health)</td></tr>"
            }) -join ""
            return "<table><tr><th>Drive</th><th>Type</th><th>Size</th><th>Health</th></tr>$rows</table>"
        }

        "RAM Health" {
            $errCount = if ($null -ne $ex["errorCount"]) { $ex["errorCount"] } else { 0 }
            $note = if ($errCount -gt 0) { "<p><strong>Memory Diagnostic has been scheduled for next reboot.</strong></p>" } else { "" }
            if (-not $ex["sticks"]) { return "<p>No RAM module data available.</p>$note" }
            $rows = ($ex["sticks"] | ForEach-Object {
                "<tr><td>$($_.Slot)</td><td>$($_.SizeGB) GB</td><td>$($_.Speed)</td><td>$(Escape-Html $_.Manufacturer)</td></tr>"
            }) -join ""
            return "$note<table><tr><th>Slot</th><th>Size</th><th>Speed</th><th>Manufacturer</th></tr>$rows</table>"
        }

        "Network Diagnostics" {
            # ── Primary adapter / IP summary ──────────────────
            $adapterLine = ""
            if ($ex["adapterName"]) {
                $ip      = if ($ex["localIP"])      { $ex["localIP"]                               } else { "—" }
                $prefix  = if ($ex["prefixLength"]) { "/$($ex['prefixLength'])"                     } else { "" }
                $gw      = if ($ex["gateway"])      { $ex["gateway"]                               } else { "—" }
                $dnsStr  = if ($ex["dnsServers"] -and @($ex["dnsServers"]).Count -gt 0) {
                    (Escape-Html ($ex["dnsServers"] -join ", "))
                } else { "—" }
                $adapterLine = "<p><strong>Adapter:</strong> $(Escape-Html $ex['adapterName']) &nbsp;|&nbsp; " +
                               "<strong>IP:</strong> $ip$prefix &nbsp;|&nbsp; " +
                               "<strong>Gateway:</strong> $gw &nbsp;|&nbsp; " +
                               "<strong>DNS:</strong> $dnsStr</p>"
            }

            # ── Connectivity matrix ───────────────────────────
            $conn  = $ex["connectivity"]
            $matrix = ""
            if ($conn) {
                $CHK  = "&#10004;"   # ✔
                $CROS = "&#10006;"   # ✖

                $rows = @(
                    @{ Check = "Loopback (127.0.0.1)";  Data = $conn["loopback"] },
                    @{ Check = "Gateway";                Data = $conn["gateway"]  },
                    @{ Check = "Internet (8.8.8.8)";    Data = $conn["internet"] },
                    @{ Check = "DNS Resolution";         Data = $conn["dns"]      }
                ) | ForEach-Object {
                    $label  = $_.Check
                    $item   = $_.Data
                    if ($item -and $item["target"]) { $label += " ($($item['target']))" }
                    $ok     = if ($item) { $item["ok"] } else { $false }
                    $detail = if ($item) { Escape-Html $item["detail"] } else { "" }
                    $cls    = if ($ok) { "ok" } else { "error" }
                    $sym    = if ($ok) { $CHK } else { $CROS }
                    "<tr><td>$label</td><td class='$cls'>$sym $(if($ok){'PASS'}else{'FAIL'})</td><td>$detail</td></tr>"
                }
                $matrix = "<table><tr><th>Check</th><th>Result</th><th>Detail</th></tr>" +
                          ($rows -join "") + "</table>"
            }

            # ── Adapter inventory (all adapters) ──────────────
            $adapterTable = ""
            if ($ex["adapters"] -and @($ex["adapters"]).Count -gt 0) {
                $aRows = ($ex["adapters"] | ForEach-Object {
                    $cls = if ($_.Class) { " class='$($_.Class)'" } else { "" }
                    "<tr$cls><td>$(Escape-Html $_.Name)</td><td>$(Escape-Html $_.Desc)</td><td>$($_.Status)</td><td>$(Escape-Html $_.Speed)</td></tr>"
                }) -join ""
                $adapterTable = "<p><strong>All adapters:</strong></p>" +
                    "<table><tr><th>Name</th><th>Description</th><th>Status</th><th>Speed</th></tr>$aRows</table>"
            }

            # ── Probable cause ────────────────────────────────
            $cause = if ($ex["probableCause"]) {
                "<p><strong>Diagnosis:</strong> $(Escape-Html $ex['probableCause'])</p>"
            } else { "" }

            # ── Reboot notice ─────────────────────────────────
            $reboot = if ($ex["rebootRequired"] -eq $true) {
                "<p class='warn'><strong>Reboot required</strong> to complete network stack repairs (Winsock / TCP/IP reset applied).</p>"
            } else { "" }

            return "$adapterLine$matrix$adapterTable$cause$reboot"
        }

        "Hardware Diagnostics" {
            $ex = $Result.ExportData

            # ── CPU / RAM / GPU summary line ─────────────────────
            $cpu     = $ex["cpu"]
            $ram     = $ex["ram"]
            $gpuName = if ($ex["gpuName"]) { $ex["gpuName"] } else { "N/A" }
            $cpuStr  = if ($cpu -and $cpu["name"] -ne "Unknown") {
                "$($cpu['name'])  ($($cpu['cores'])C / $($cpu['logical'])T @ $([math]::Round($cpu['maxMHz']/1000,2)) GHz)  Load: $($cpu['loadPct'])%"
            } else { "CPU data unavailable" }
            $ramStr  = if ($ram -and $ram["totalGB"] -gt 0) {
                "$($ram['usedPct'])% used — $($ram['usedGB']) GB / $($ram['totalGB']) GB  ($($ram['stickCount']) stick(s))"
            } else { "RAM data unavailable" }

            $summaryLine = "<table><tr><th>Component</th><th>Detail</th></tr>" +
                "<tr><td>CPU</td><td>$cpuStr</td></tr>" +
                "<tr><td>RAM</td><td>$ramStr</td></tr>" +
                "<tr><td>GPU</td><td>$gpuName</td></tr>" +
                "</table>"

            # ── BIOS / Motherboard ────────────────────────────────
            $bios = $ex["bios"]
            $mb   = $ex["mb"]
            $hwInfo = ""
            if ($mb -and $mb["manufacturer"] -ne "Unknown") {
                $hwInfo += "<p><strong>Motherboard:</strong> $($mb['manufacturer']) $($mb['product'])  &nbsp;|&nbsp; " +
                           "<strong>BIOS:</strong> $($bios['vendor']) $($bios['version'])  ($($bios['date']))</p>"
            }

            # ── Logical disk table ────────────────────────────────
            $diskTable = ""
            $diskRows  = $ex["disks"]
            if ($diskRows -and $diskRows.Count -gt 0) {
                $diskRows_html = ""
                foreach ($d in $diskRows) {
                    $cls    = $d["class"]
                    $lbl    = if ($d["label"]) { " ($($d['label']))" } else { "" }
                    $bar    = $d["usedPct"]
                    $barCol = switch ($cls) {
                        "critical" { "#dc3545" } "error" { "#fd7e14" }
                        "warn"     { "#ffc107" } default  { "#28a745" }
                    }
                    $diskRows_html += "<tr class='$cls'>" +
                        "<td><strong>$($d['drive'])</strong>$lbl</td>" +
                        "<td>$($d['totalGB']) GB</td>" +
                        "<td>$($d['freeGB']) GB</td>" +
                        "<td><div style='background:#333;border-radius:3px;height:12px;width:120px'>" +
                        "<div style='background:$barCol;height:12px;width:$($bar)%;border-radius:3px'></div></div> $bar%</td>" +
                        "</tr>"
                }
                $diskTable = "<h4>Logical Drives</h4><table>" +
                    "<tr><th>Drive</th><th>Total</th><th>Free</th><th>Used</th></tr>" +
                    $diskRows_html + "</table>"
            }

            # ── Physical disk (SMART) table ───────────────────────
            $smartTable = ""
            $physDisks  = $ex["physDisks"]
            if ($physDisks -and $physDisks.Count -gt 0) {
                $smartRows_html = ""
                foreach ($pd in $physDisks) {
                    $cls = $pd["class"]
                    $healthBadge = switch ($pd["health"]) {
                        "Healthy"   { "<span class='badge badge-ok'>Healthy</span>"       }
                        "Warning"   { "<span class='badge badge-warn'>Warning</span>"     }
                        "Unhealthy" { "<span class='badge badge-error'>Unhealthy</span>"  }
                        default     { "<span class='badge badge-info'>$($pd['health'])</span>" }
                    }
                    $smartRows_html += "<tr class='$cls'>" +
                        "<td>$($pd['name'])</td>" +
                        "<td>$($pd['type'])</td>" +
                        "<td>$($pd['sizeGB']) GB</td>" +
                        "<td>$healthBadge</td>" +
                        "</tr>"
                }
                $smartTable = "<h4>Physical Drives (SMART)</h4><table>" +
                    "<tr><th>Drive</th><th>Type</th><th>Size</th><th>Health</th></tr>" +
                    $smartRows_html + "</table>"
            }

            return "$summaryLine$hwInfo$diskTable$smartTable"
        }

        default {
            return "<p>Module: $($Result.ModuleName) | Findings: $($Result.Findings.Count) | Severity: $($Result.Severity)</p>"
        }
    }
}

Write-Verbose "[Reports.HTML] HTML report generator loaded."
