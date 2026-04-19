<#
.SYNOPSIS
    FixPC Toolkit — Main WinForms Window
    Pure UI layer. Contains ZERO business logic.
    Communicates with App layer only through:
      - Shared State hashtable (read-only from UI)
      - Background runspace (write-only from UI via RunspaceFactory)
      - Timer polling (UI updates driven by State)

.VERSION 1.0
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-MainForm {
    param(
        [Parameter(Mandatory)] [array]    $ModuleDefinitions,
        [Parameter(Mandatory)] [hashtable]$InitialState
    )

    $Script:State      = $InitialState
    $Script:StatusLabels = @{}

    # ── FORM ──────────────────────────────────────────────────
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text            = "FixPC Toolkit  v1.0"
    $Form.Size            = New-Object System.Drawing.Size(820, 700)
    $Form.MinimumSize     = New-Object System.Drawing.Size(820, 700)
    $Form.BackColor       = $Script:Theme.BgDark
    $Form.ForeColor       = $Script:Theme.White
    $Form.StartPosition   = "CenterScreen"
    $Form.Font            = $Script:Fonts.Sub
    $Form.FormBorderStyle = "FixedSingle"
    $Form.MaximizeBox     = $false

    # ── HEADER ────────────────────────────────────────────────
    $Header = New-HeaderPanel -Version "1.0"

    # ── MODULE PANEL ──────────────────────────────────────────
    $PanelModules           = New-Object System.Windows.Forms.Panel
    $PanelModules.Location  = New-Object System.Drawing.Point(10, 80)
    $PanelModules.Size      = New-Object System.Drawing.Size(790, 270)
    $PanelModules.BackColor = $Script:Theme.BgMid

    # Column headers
    $headerDefs = @(
        @{ X=32;  Txt="MODULE";      W=255 }
        @{ X=290; Txt="DESCRIPTION"; W=225 }
        @{ X=520; Txt="STATUS";      W=130 }
        @{ X=655; Txt="TIME";        W=100 }
    )
    foreach ($hd in $headerDefs) {
        $h           = New-Object System.Windows.Forms.Label
        $h.Text      = $hd.Txt
        $h.Location  = New-Object System.Drawing.Point($hd.X, 5)
        $h.Size      = New-Object System.Drawing.Size($hd.W, 18)
        $h.Font      = $Script:Fonts.Tiny
        $h.ForeColor = $Script:Theme.Gray
        $PanelModules.Controls.Add($h)
    }

    # Module rows
    $y = 27; $idx = 0
    foreach ($mod in $ModuleDefinitions) {
        $row = New-ModuleRow -ModuleDef $mod -YOffset $y -RowIndex $idx -LabelStore $Script:StatusLabels
        $PanelModules.Controls.Add($row)
        $y += 25; $idx++
    }

    # ── PROGRESS ──────────────────────────────────────────────
    $Prog = New-ProgressSection -Location (New-Object System.Drawing.Point(10, 358))
    $ProgressBar  = $Prog.Bar
    $LblProgress  = $Prog.Label

    # ── LOG HEADER ────────────────────────────────────────────
    $LblLog           = New-Object System.Windows.Forms.Label
    $LblLog.Text      = "  LIVE LOG"
    $LblLog.Location  = New-Object System.Drawing.Point(10, 402)
    $LblLog.Size      = New-Object System.Drawing.Size(200, 16)
    $LblLog.Font      = $Script:Fonts.Tiny
    $LblLog.ForeColor = $Script:Theme.Gray

    # ── LOG BOX ───────────────────────────────────────────────
    $LogBox = New-LogBox `
        -Location (New-Object System.Drawing.Point(10, 420)) `
        -Size     (New-Object System.Drawing.Size(790, 170))

    # ── EXECUTION MODE SELECTOR ───────────────────────────────
    $LblMode           = New-Object System.Windows.Forms.Label
    $LblMode.Text      = "Mode:"
    $LblMode.Location  = New-Object System.Drawing.Point(10, 598)
    $LblMode.Size      = New-Object System.Drawing.Size(40, 20)
    $LblMode.Font      = $Script:Fonts.Small
    $LblMode.ForeColor = $Script:Theme.Gray

    $CmbMode           = New-Object System.Windows.Forms.ComboBox
    $CmbMode.Location  = New-Object System.Drawing.Point(52, 595)
    $CmbMode.Size      = New-Object System.Drawing.Size(140, 24)
    $CmbMode.Font      = $Script:Fonts.Small
    $CmbMode.FlatStyle = "Flat"
    $CmbMode.BackColor = $Script:Theme.BgCard
    $CmbMode.ForeColor = $Script:Theme.White
    $CmbMode.DropDownStyle = "DropDownList"
    @("DiagnoseOnly", "SafeRepair", "FullRepair") | ForEach-Object { $CmbMode.Items.Add($_) | Out-Null }
    $CmbMode.SelectedIndex = 1   # Default: SafeRepair

    # ── BUTTONS ───────────────────────────────────────────────
    $BtnRun = New-ActionButton `
        -Text       "> Run Diagnostic" `
        -Location   (New-Object System.Drawing.Point(205, 593)) `
        -Size       (New-Object System.Drawing.Size(175, 34)) `
        -BackColor  $Script:Theme.Accent `
        -ForeColor  $Script:Theme.BgDark `
        -BorderColor $Script:Theme.Accent

    $BtnReport = New-ActionButton `
        -Text        "  View Report" `
        -Location    (New-Object System.Drawing.Point(392, 593)) `
        -Size        (New-Object System.Drawing.Size(145, 34)) `
        -BackColor   [System.Drawing.Color]::FromArgb(30, 50, 30) `
        -ForeColor   $Script:Theme.Green `
        -BorderColor $Script:Theme.Green `
        -Enabled     $false

    $BtnJson = New-ActionButton `
        -Text        "  JSON" `
        -Location    (New-Object System.Drawing.Point(548, 593)) `
        -Size        (New-Object System.Drawing.Size(80, 34)) `
        -BackColor   [System.Drawing.Color]::FromArgb(10, 20, 40) `
        -ForeColor   $Script:Theme.Accent `
        -BorderColor $Script:Theme.Accent `
        -Enabled     $false

    $BtnExit = New-ActionButton `
        -Text        "X  Exit" `
        -Location    (New-Object System.Drawing.Point(650, 593)) `
        -Size        (New-Object System.Drawing.Size(150, 34)) `
        -BackColor   [System.Drawing.Color]::FromArgb(40, 15, 20) `
        -ForeColor   $Script:Theme.Red `
        -BorderColor $Script:Theme.Red

    $Sep           = New-Object System.Windows.Forms.Panel
    $Sep.Location  = New-Object System.Drawing.Point(0, 590)
    $Sep.Size      = New-Object System.Drawing.Size(820, 1)
    $Sep.BackColor = $Script:Theme.Separator

    # ── ASSEMBLE ──────────────────────────────────────────────
    $Form.Controls.AddRange(@(
        $Header, $PanelModules, $Prog.Panel,
        $LblLog, $LogBox, $Sep,
        $LblMode, $CmbMode,
        $BtnRun, $BtnReport, $BtnJson, $BtnExit
    ))

    # ── TIMER ─────────────────────────────────────────────────
    $Timer          = New-Object System.Windows.Forms.Timer
    $Timer.Interval = 300

    $Timer.Add_Tick({
        # Progress bar
        if ($Script:State.Progress -gt $ProgressBar.Value) {
            $ProgressBar.Value = [Math]::Min($Script:State.Progress, 100)
        }
        $LblProgress.Text = $Script:State.StatusMsg

        # Module status badges
        foreach ($mod in $ModuleDefinitions) {
            $id  = $mod.Id
            $st  = $Script:State.ModuleStatus[$id]
            $tm  = $Script:State.ModuleTimes[$id]
            if ($st -and $st -ne "pending") {
                Update-StatusBadge -Id $id -Status $st -TimeStr $tm
            }
        }

        # Drain log buffer
        if ($Script:State.LogBuffer -ne "") {
            $lines = $Script:State.LogBuffer -split "`n"
            $Script:State.LogBuffer = ""
            foreach ($line in $lines) {
                if ($line -match "^\[(\w+)\](.+)$") {
                    Append-LogLine -Box $LogBox -Text $Matches[2] -Type $Matches[1]
                } elseif ($line.Trim() -ne "") {
                    Append-LogLine -Box $LogBox -Text $line -Type "normal"
                }
            }
        }

        # Completion
        if ($Script:State.IsDone) {
            $Timer.Stop()
            $BtnRun.Enabled       = $true
            $BtnRun.Text          = "> Run Again"
            $BtnReport.Enabled    = $true
            $BtnJson.Enabled      = $true
            $ProgressBar.Value    = 100
            $LblProgress.Text     = "$([char]0x2714) Complete!  Reports saved to: $($Script:State.ReportFolder)"
            $LblProgress.ForeColor= $Script:Theme.Green
            Append-LogLine -Box $LogBox -Text "" -Type "ok"
            Append-LogLine -Box $LogBox -Text ("=" * 50) -Type "ok"
            Append-LogLine -Box $LogBox -Text "  COMPLETE  |  Click 'View Report' to open HTML report" -Type "ok"
            Append-LogLine -Box $LogBox -Text ("=" * 50) -Type "ok"
        }
    })

    # ── BUTTON EVENTS ─────────────────────────────────────────
    $BtnRun.Add_Click({
        $selectedMode = [ExecutionMode]$CmbMode.SelectedItem

        Reset-UI -LogBox $LogBox -ProgressBar $ProgressBar -LblProgress $LblProgress `
                 -ModuleDefinitions $ModuleDefinitions -BtnRun $BtnRun `
                 -BtnReport $BtnReport -BtnJson $BtnJson

        Append-LogLine -Box $LogBox -Text "FixPC Toolkit v1.0  |  Mode: $selectedMode" -Type "step"
        Append-LogLine -Box $LogBox -Text "Computer: $env:COMPUTERNAME  |  $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -Type "info"
        Append-LogLine -Box $LogBox -Text ("-" * 50) -Type "info"

        Start-BackgroundWorkflow -Mode $selectedMode -State $Script:State -ModuleDefinitions $ModuleDefinitions
        $Timer.Start()
    })

    $BtnReport.Add_Click({
        if (Test-Path $Script:State.ReportHTML) { Start-Process $Script:State.ReportHTML }
        else { [System.Windows.Forms.MessageBox]::Show("Report not found. Run the diagnostic first.", "FixPC Toolkit", "OK", "Warning") }
    })

    $BtnJson.Add_Click({
        if (Test-Path $Script:State.ReportJSON) { Start-Process $Script:State.ReportJSON }
        else { [System.Windows.Forms.MessageBox]::Show("JSON report not found.", "FixPC Toolkit", "OK", "Warning") }
    })

    $BtnExit.Add_Click({ $Timer.Stop(); $Form.Close() })

    [System.Windows.Forms.Application]::EnableVisualStyles()
    $Form.Add_Shown({ $Form.Activate() })
    [System.Windows.Forms.Application]::Run($Form)
}

# ============================================================
#  UI HELPER FUNCTIONS
# ============================================================
function Update-StatusBadge {
    param([string]$Id, [string]$Status, [string]$TimeStr = "")

    $badge = $Script:StatusLabels[$Id]
    $dot   = $Script:StatusLabels[$Id + "_dot"]
    $time  = $Script:StatusLabels[$Id + "_time"]
    if (-not $badge) { return }

    $CHK  = [char]0x2714
    $WARN = [char]0x26A0
    $CROS = [char]0x2716
    $DASH = [char]0x2014

    $color = Get-StatusColor -Status $Status
    $text  = switch ($Status) {
        "running" { "> RUNNING..."       }
        "ok"      { "$CHK  OK"           }
        "warn"    { "$WARN  WARNING"     }
        "error"   { "$CROS  ERROR"       }
        "skipped" { "$DASH  SKIPPED"     }
        default   { "$DASH PENDING $DASH"}
    }

    $badge.Text      = $text
    $badge.ForeColor = $color
    $dot.ForeColor   = $color
    if ($TimeStr -and $time) { $time.Text = $TimeStr; $time.ForeColor = $Script:Theme.Gray }
}

function Append-LogLine {
    param([System.Windows.Forms.RichTextBox]$Box, [string]$Text, [string]$Type = "normal")
    $col = Get-LogColor -Type $Type
    $Box.SelectionStart  = $Box.TextLength
    $Box.SelectionLength = 0
    $Box.SelectionColor  = $col
    $Box.AppendText("$Text`n")
    $Box.ScrollToCaret()
}

function Reset-UI {
    param($LogBox, $ProgressBar, $LblProgress, $ModuleDefinitions, $BtnRun, $BtnReport, $BtnJson)

    $BtnRun.Enabled       = $false
    $BtnReport.Enabled    = $false
    $BtnJson.Enabled      = $false
    $LogBox.Clear()
    $ProgressBar.Value    = 0
    $LblProgress.ForeColor= $Script:Theme.Gray
    $LblProgress.Text     = "Starting..."

    $Script:State.IsDone      = $false
    $Script:State.IsRunning   = $false
    $Script:State.Progress    = 0
    $Script:State.LogBuffer   = ""
    $Script:State.StatusMsg   = "Starting..."
    $Script:State.ReportReady = $false
    $Script:State.Warnings.Clear()

    foreach ($mod in $ModuleDefinitions) {
        $Script:State.ModuleStatus[$mod.Id] = "pending"
        $Script:State.ModuleTimes[$mod.Id]  = ""
        Update-StatusBadge -Id $mod.Id -Status "pending"
    }
}

function Start-BackgroundWorkflow {
    param([ExecutionMode]$Mode, [hashtable]$State, [array]$ModuleDefinitions)

    $toolkitRoot = $PSScriptRoot | Split-Path -Parent

    $RS = [RunspaceFactory]::CreateRunspace()
    $RS.ApartmentState = "STA"
    $RS.ThreadOptions  = "ReuseThread"
    $RS.Open()
    $RS.SessionStateProxy.SetVariable("State",             $State)
    $RS.SessionStateProxy.SetVariable("SelectedMode",      $Mode)
    $RS.SessionStateProxy.SetVariable("ModuleDefinitions", $ModuleDefinitions)
    $RS.SessionStateProxy.SetVariable("ToolkitRoot",       $toolkitRoot)

    $WorkerScript = {
        # Load all toolkit layers
        . "$ToolkitRoot\Core\Contracts.ps1"
        . "$ToolkitRoot\Core\Utilities.ps1"
        . "$ToolkitRoot\Core\Logging.ps1"
        . "$ToolkitRoot\Core\State.ps1"
        . "$ToolkitRoot\Core\Validation.ps1"
        . "$ToolkitRoot\Core\Execution.ps1"
        . "$ToolkitRoot\App\Bootstrap.ps1"
        . "$ToolkitRoot\App\ExecutionContext.ps1"
        . "$ToolkitRoot\App\ResultConsolidator.ps1"
        . "$ToolkitRoot\App\WorkflowCoordinator.ps1"
        . "$ToolkitRoot\Modules\System\SystemModule.ps1"
        . "$ToolkitRoot\Reports\HTML.ps1"
        . "$ToolkitRoot\Reports\TXT.ps1"
        . "$ToolkitRoot\Reports\JSON.ps1"

        # Bootstrap with the shared state as log sync buffer
        $ctx = Initialize-FixPCToolkit -Mode $SelectedMode -SyncBuffer $State

        # Update state with report paths
        $State.ReportFolder = $ctx.ReportFolder
        $State.ReportHTML   = Join-Path $ctx.ReportFolder "Report_$($ctx.SessionId).html"
        $State.ReportTXT    = Join-Path $ctx.ReportFolder "Report_$($ctx.SessionId).txt"
        $State.ReportJSON   = Join-Path $ctx.ReportFolder "Report_$($ctx.SessionId).json"

        # Run the workflow
        Start-DiagnosticWorkflow -Context $ctx -State $State -ModuleDefinitions $ModuleDefinitions
    }

    $PS = [PowerShell]::Create()
    $PS.Runspace = $RS
    $PS.AddScript($WorkerScript) | Out-Null
    $PS.BeginInvoke() | Out-Null
}

Write-Verbose "[MainForm] Main form loaded."
