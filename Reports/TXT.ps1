<#
.SYNOPSIS
    FixPC Toolkit — TXT Report Generator
    Plain text report for ticket systems, email, and log archives.

.VERSION 1.0
#>

function Export-TxtReport {
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Report,
        [Parameter(Mandatory)] [string]         $OutputPath
    )

    Write-LogInfo -Source "Reports.TXT" -Message "Generating TXT report: $OutputPath"

    $lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add("=" * 65)
    $lines.Add("  FIXPC TOOLKIT — DIAGNOSTIC REPORT")
    $lines.Add("  Session : $($Report.SessionId)")
    $lines.Add("  Date    : $(Format-Timestamp $Report.StartTime)")
    $lines.Add("  Computer: $($Report.Computer)   User: $($Report.User)")
    $lines.Add("  OS      : $($Report.OS)")
    $lines.Add("  Mode    : $($Report.ExecutionMode)")
    $lines.Add("  Duration: $($Report.TotalDuration)")
    $lines.Add("=" * 65)
    $lines.Add("")

    # Summary
    $lines.Add("SUMMARY")
    $lines.Add("-" * 40)
    $lines.Add("  Modules Run   : $($Report.TotalModules)")
    $lines.Add("  OK            : $($Report.OkCount)")
    $lines.Add("  Warnings      : $($Report.WarnCount)")
    $lines.Add("  Errors        : $($Report.ErrorCount)")
    $lines.Add("  Total Findings: $($Report.FindingsTotal)")
    $lines.Add("  Actions Taken : $($Report.ActionsTotal)")
    $lines.Add("")

    # Action Items
    if ($Report.AllWarnings.Count -gt 0) {
        $lines.Add("ACTION ITEMS / WARNINGS")
        $lines.Add("-" * 40)
        foreach ($w in $Report.AllWarnings) { $lines.Add("  $w") }
        $lines.Add("")
    } else {
        $lines.Add("No warnings — system appears healthy.")
        $lines.Add("")
    }

    # Module Details
    $lines.Add("MODULE RESULTS")
    $lines.Add("=" * 65)

    foreach ($r in $Report.ModuleResults) {
        $dur    = Format-Duration $r.DurationSeconds
        $status = if (-not $r.Success) {"ERROR"} else { (Convert-SeverityToUiStatus $r.Severity).ToUpper() }
        $lines.Add("")
        $lines.Add("  [$status] $($r.ModuleName)  ($dur)")
        $lines.Add("  " + ("-" * 45))

        foreach ($f in $r.Findings) {
            $sym = switch ($f.Severity.ToLower()) {
                "critical" { "[CRIT]" }
                "error"    { "[ERRO]" }
                "warn"     { "[WARN]" }
                "info"     { "[INFO]" }
                "ok"       { "[ OK ]" }
                default    { "[ OK ]" }
            }
            $lines.Add("  $sym $($f.Title): $($f.Description)")
        }

        if ($r.ActionsTaken.Count -gt 0) {
            $lines.Add("  Actions taken:")
            foreach ($a in $r.ActionsTaken) {
                $ok = if ($a.Success) { "OK" } else { "FAIL" }
                $lines.Add("    [$ok] $($a.Action) -> $($a.Target): $($a.Detail)")
            }
        }

        if ($r.Recommendations.Count -gt 0) {
            $lines.Add("  Recommendations:")
            foreach ($rec in $r.Recommendations) { $lines.Add("    > $rec") }
        }
    }

    $lines.Add("")
    $lines.Add("=" * 65)
    $lines.Add("  Log file: $(Get-LogFilePath)")
    $lines.Add("  Report generated: $(Format-Timestamp)")
    $lines.Add("=" * 65)

    ($lines -join "`n") | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-LogInfo -Source "Reports.TXT" -Message "TXT report written: $OutputPath"
}

Write-Verbose "[Reports.TXT] TXT report generator loaded."
