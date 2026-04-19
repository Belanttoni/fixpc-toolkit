<#
.SYNOPSIS
    FixPC Toolkit — JSON Report Generator
    Machine-readable export for integrations, dashboards, and audit systems.

.VERSION 1.0
#>

function Export-JsonReport {
    param(
        [Parameter(Mandatory)] [PSCustomObject]$Report,
        [Parameter(Mandatory)] [string]         $OutputPath
    )

    Write-LogInfo -Source "Reports.JSON" -Message "Generating JSON report: $OutputPath"

    $obj = [ordered]@{
        meta = [ordered]@{
            tool          = "FixPC Toolkit"
            version       = "1.0"
            sessionId     = $Report.SessionId
            computer      = $Report.Computer
            user          = $Report.User
            os            = $Report.OS
            executionMode = $Report.ExecutionMode.ToString()
            startTime     = $Report.StartTime.ToString("o")
            endTime       = $Report.EndTime.ToString("o")
            totalDuration = $Report.TotalDuration
            reportFolder  = $Report.ReportFolder
        }
        summary = [ordered]@{
            overallSeverity = $Report.OverallSeverity.ToString()
            totalModules    = $Report.TotalModules
            okCount         = $Report.OkCount
            warnCount       = $Report.WarnCount
            errorCount      = $Report.ErrorCount
            findingsTotal   = $Report.FindingsTotal
            actionsTotal    = $Report.ActionsTotal
            warnings        = @($Report.AllWarnings)
        }
        performance = [ordered]@{
            cpuLoad  = $Report.CpuLoad
            ramPct   = $Report.RamPct
            diskPct  = $Report.DiskPct
        }
        modules = @($Report.ModuleResults | ForEach-Object {
            [ordered]@{
                moduleName      = $_.ModuleName
                success         = $_.Success
                executionMode   = $_.ExecutionMode.ToString()
                severity        = $_.Severity.ToString()
                durationSeconds = $_.DurationSeconds
                findings        = @($_.Findings | ForEach-Object {
                    [ordered]@{
                        title        = $_.Title
                        severity     = $_.Severity.ToString()
                        description  = $_.Description
                        repaired     = $_.Repaired
                        repairAction = $_.RepairAction
                    }
                })
                actionsTaken    = @($_.ActionsTaken | ForEach-Object {
                    [ordered]@{
                        action      = $_.Action
                        target      = $_.Target
                        success     = $_.Success
                        detail      = $_.Detail
                        errorDetail = $_.ErrorDetail
                    }
                })
                warnings        = @($_.Warnings)
                errors          = @($_.Errors)
                recommendations = @($_.Recommendations)
                exportData      = $_.ExportData
            }
        })
    }

    $json = $obj | ConvertTo-Json -Depth 10 -Compress:$false
    $json | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-LogInfo -Source "Reports.JSON" -Message "JSON report written: $OutputPath"
}

Write-Verbose "[Reports.JSON] JSON report generator loaded."
