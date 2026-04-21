<#
.SYNOPSIS
    FixPC Toolkit — Main WinForms Window
    Pure UI layer. Contains ZERO business logic.
    Communicates with App layer only through:
      - Shared State hashtable (read-only from UI)
      - Background runspace (write-only from UI via RunspaceFactory)
      - Timer polling (UI updates driven by State)

.VERSION 1.1
    + Module selection checkboxes on each row
    + Preset strip: Quick Scan | Full Diagnose | Safe Repair | Custom
    + Execution filtered to selected modules only
    + Unselected modules shown as SKIPPED
    + Form height expanded to show all 12 module rows
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-MainForm {
    param(
        [Parameter(Mandatory)] [array]    $ModuleDefinitions,
        [Parameter(Mandatory)] [hashtable]$InitialState
    )

    $Script:State         = $InitialState
    $Script:StatusLabels  = @{}
    $Script:PresetBtns    = @{}
    $Script:ActivePreset  = "Full Diagnose"
    $Script:ApplyingPreset = $false
    $Script:AllModuleDefs = $ModuleDefinitions   # script-scope for event handler access

    # Preset → module ID list mappings.
    # $null means "all modules" (Full Diagnose).
    # "custom" sentinel means "do not change checkboxes".
    $Script:Presets = @{
        "Quick Scan"    = @("sysinfo", "events", "smart", "network", "hardware")
        "Full Diagnose" = $null
        "Safe Repair"   = @("sysinfo", "sfc", "temp", "network", "winupdate")
        "Custom"        = "custom"
    }

    # ── FORM ──────────────────────────────────────────────────
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text            = "FixPC Toolkit  v1.0"
    $Form.Size            = New-Object System.Drawing.Size(820, 800)
    $Form.MinimumSize     = New-Object System.Drawing.Size(820, 800)
    $Form.BackColor       = $Script:Theme.BgDark
    $Form.ForeColor       = $Script:Theme.White
    $Form.StartPosition   = "CenterScreen"
    $Form.Font            = $Script:Fonts.Sub
    $Form.FormBorderStyle = "FixedSingle"
    $Form.MaximizeBox     = $false

    # ── HEADER ────────────────────────────────────────────────
    $Header = New-HeaderPanel -Version "1.0"

    # ── PRESET STRIP ──────────────────────────────────────────
    $PanelPresets           = New-Object System.Windows.Forms.Panel
    $PanelPresets.Location  = New-Object System.Drawing.Point(10, 74)
    $PanelPresets.Size      = New-Object System.Drawing.Size(790, 34)
    $PanelPresets.BackColor = $Script:Theme.BgHeader

    $LblPresets           = New-Object System.Windows.Forms.Label
    $LblPresets.Text      = "PRESETS:"
    $LblPresets.Location  = New-Object System.Drawing.Point(8, 11)
    $LblPresets.Size      = New-Object System.Drawing.Size(62, 14)
    $LblPresets.Font      = $Script:Fonts.Tiny
    $LblPresets.ForeColor = $Script:Theme.Gray
    $PanelPresets.Controls.Add($LblPresets)

    # Preset button definitions — Name, X position, width
    $presetDefs = @(
        @{ Name = "Quick Scan";    X = 75;  W = 100 }
        @{ Name = "Full Diagnose"; X = 180; W = 110 }
        @{ Name = "Safe Repair";   X = 295; W = 100 }
        @{ Name = "Custom";        X = 400; W = 80  }
    )
    foreach ($pd in $presetDefs) {
        $pb           = New-Object System.Windows.Forms.Button
        $pb.Text      = $pd.Name
        $pb.Location  = New-Object System.Drawing.Point($pd.X, 4)
        $pb.Size      = New-Object System.Drawing.Size($pd.W, 26)
        $pb.Font      = $Script:Fonts.Small
        $pb.FlatStyle = "Flat"
        $pb.Cursor    = "Hand"
        $pb.BackColor = $Script:Theme.BgCard
        $pb.ForeColor = $Script:Theme.Gray
        $pb.FlatAppearance.BorderSize  = 1
        $pb.FlatAppearance.BorderColor = $Script:Theme.Separator

        # Capture loop variable before closure — prevents last-value-only capture
        $capturedName = $pd.Name
        $pb.Add_Click({
            Apply-Preset -PresetName $capturedName -AllModuleDefs $Script:AllModuleDefs
        }.GetNewClosure())

        $PanelPresets.Controls.Add($pb)
        $Script:PresetBtns[$pd.Name] = $pb
    }

    # ── MODULE PANEL ──────────────────────────────────────────
    $PanelModules           = New-Object System.Windows.Forms.Panel
    $PanelModules.Location  = New-Object System.Drawing.Point(10, 112)
    $PanelModules.Size      = New-Object System.Drawing.Size(790, 340)
    $PanelModules.BackColor = $Script:Theme.BgMid

    # Column headers — "MODULE" shifted right to align with checkbox-aware rows
    $headerDefs = @(
        @{ X=50;  Txt="MODULE";      W=236 }
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

    # Module rows — each row now includes a selection checkbox
    $y = 27; $idx = 0
    foreach ($mod in $ModuleDefinitions) {
        $row = New-ModuleRow -ModuleDef $mod -YOffset $y -RowIndex $idx -LabelStore $Script:StatusLabels
        $PanelModules.Controls.Add($row)
        $y += 25; $idx++
    }

    # Wire checkbox CheckedChanged — any manual toggle switches display to "Custom" mode.
    # Guard with $Script:ApplyingPreset so programmatic changes from Apply-Preset don't
    # trigger this handler and immediately override the just-applied preset.
    foreach ($mod in $ModuleDefinitions) {
        $chk = $Script:StatusLabels[$mod.Id + "_chk"]
        if (-not $chk) { continue }
        $chk.Add_CheckedChanged({
            if ($Script:ApplyingPreset) { return }
            if ($Script:ActivePreset -ne "Custom") {
                $Script:ActivePreset = "Custom"
                foreach ($pn in $Script:PresetBtns.Keys) {
                    $pbx = $Script:PresetBtns[$pn]
                    if ($pn -eq "Custom") {
                        $pbx.BackColor = $Script:Theme.Accent
                        $pbx.ForeColor = $Script:Theme.BgDark
                        $pbx.FlatAppearance.BorderColor = $Script:Theme.Accent
                    } else {
                        $pbx.BackColor = $Script:Theme.BgCard
                        $pbx.ForeColor = $Script:Theme.Gray
                        $pbx.FlatAppearance.BorderColor = $Script:Theme.Separator
                    }
                }
            }
        })
    }

    # Apply the default preset (Full Diagnose — all modules checked)
    Apply-Preset -PresetName "Full Diagnose" -AllModuleDefs $ModuleDefinitions

    # ── PROGRESS ──────────────────────────────────────────────
    $Prog = New-ProgressSection -Location (New-Object System.Drawing.Point(10, 456))
    $ProgressBar  = $Prog.Bar
    $LblProgress  = $Prog.Label

    # ── LOG HEADER ────────────────────────────────────────────
    $LblLog           = New-Object System.Windows.Forms.Label
    $LblLog.Text      = "  LIVE LOG"
    $LblLog.Location  = New-Object System.Drawing.Point(10, 498)
    $LblLog.Size      = New-Object System.Drawing.Size(200, 16)
    $LblLog.Font      = $Script:Fonts.Tiny
    $LblLog.ForeColor = $Script:Theme.Gray

    # ── LOG BOX ───────────────────────────────────────────────
    $LogBox = New-LogBox `
        -Location (New-Object System.Drawing.Point(10, 516)) `
        -Size     (New-Object System.Drawing.Size(790, 152))

    # ── EXECUTION MODE SELECTOR ───────────────────────────────
    $LblMode           = New-Object System.Windows.Forms.Label
    $LblMode.Text      = "Mode:"
    $LblMode.Location  = New-Object System.Drawing.Point(10, 676)
    $LblMode.Size      = New-Object System.Drawing.Size(40, 20)
    $LblMode.Font      = $Script:Fonts.Small
    $LblMode.ForeColor = $Script:Theme.Gray

    $CmbMode           = New-Object System.Windows.Forms.ComboBox
    $CmbMode.Location  = New-Object System.Drawing.Point(52, 673)
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
        -Text        "> Run Diagnostic" `
        -Location    (New-Object System.Drawing.Point(205, 671)) `
        -Size        (New-Object System.Drawing.Size(175, 34)) `
        -BackColor   $Script:Theme.Accent `
        -ForeColor   $Script:Theme.BgDark `
        -BorderColor $Script:Theme.Accent

    $BtnReport = New-ActionButton `
        -Text        "  View Report" `
        -Location    (New-Object System.Drawing.Point(392, 671)) `
        -Size        (New-Object System.Drawing.Size(145, 34)) `
        -BackColor   [System.Drawing.Color]::FromArgb(30, 50, 30) `
        -ForeColor   $Script:Theme.Green `
        -BorderColor $Script:Theme.Green `
        -Enabled     $false

    $BtnJson = New-ActionButton `
        -Text        "  JSON" `
        -Location    (New-Object System.Drawing.Point(548, 671)) `
        -Size        (New-Object System.Drawing.Size(80, 34)) `
        -BackColor   [System.Drawing.Color]::FromArgb(10, 20, 40) `
        -ForeColor   $Script:Theme.Accent `
        -BorderColor $Script:Theme.Accent `
        -Enabled     $false

    $BtnExit = New-ActionButton `
        -Text        "X  Exit" `
        -Location    (New-Object System.Drawing.Point(650, 671)) `
        -Size        (New-Object System.Drawing.Size(150, 34)) `
        -BackColor   [System.Drawing.Color]::FromArgb(40, 15, 20) `
        -ForeColor   $Script:Theme.Red `
        -BorderColor $Script:Theme.Red

    $Sep           = New-Object System.Windows.Forms.Panel
    $Sep.Location  = New-Object System.Drawing.Point(0, 668)
    $Sep.Size      = New-Object System.Drawing.Size(820, 1)
    $Sep.BackColor = $Script:Theme.Separator

    # ── ASSEMBLE ──────────────────────────────────────────────
    $Form.Controls.AddRange(@(
        $Header, $PanelPresets, $PanelModules, $Prog.Panel,
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

        # ── Collect selected module definitions ───────────────
        $selectedModDefs = @($Script:AllModuleDefs | Where-Object {
            $chk = $Script:StatusLabels[$_.Id + "_chk"]
            # No checkbox stored means always include; otherwise honour Checked state.
            (-not $chk) -or $chk.Checked
        })

        if ($selectedModDefs.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select at least one module to run.",
                "FixPC Toolkit", [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        # Reset ALL module badges to "pending" so the UI starts clean
        Reset-UI -LogBox $LogBox -ProgressBar $ProgressBar -LblProgress $LblProgress `
                 -ModuleDefinitions $Script:AllModuleDefs -BtnRun $BtnRun `
                 -BtnReport $BtnReport -BtnJson $BtnJson

        # Mark unselected modules as SKIPPED immediately (timer will render the badge)
        $selectedIds = @($selectedModDefs | ForEach-Object { $_.Id })
        foreach ($mod in $Script:AllModuleDefs) {
            if ($mod.Id -notin $selectedIds) {
                $Script:State.ModuleStatus[$mod.Id] = "skipped"
                Update-StatusBadge -Id $mod.Id -Status "skipped"
            }
        }

        Append-LogLine -Box $LogBox -Text "FixPC Toolkit v1.0  |  Mode: $selectedMode" -Type "step"
        Append-LogLine -Box $LogBox -Text "Computer: $env:COMPUTERNAME  |  $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" -Type "info"
        Append-LogLine -Box $LogBox -Text "Modules: $($selectedIds -join ', ')  ($($selectedModDefs.Count) of $($Script:AllModuleDefs.Count))" -Type "info"
        Append-LogLine -Box $LogBox -Text ("-" * 50) -Type "info"

        Start-BackgroundWorkflow -Mode $selectedMode -State $Script:State -ModuleDefinitions $selectedModDefs
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

    # Reset ALL module badges to pending (caller sets skipped ones afterwards)
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
        . "$ToolkitRoot\Modules\Network\NetworkModule.ps1"
        . "$ToolkitRoot\Modules\Hardware\HardwareModule.ps1"
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

        # Run the workflow — $ModuleDefinitions already contains only selected modules
        Start-DiagnosticWorkflow -Context $ctx -State $State -ModuleDefinitions $ModuleDefinitions
    }

    $PS = [PowerShell]::Create()
    $PS.Runspace = $RS
    $PS.AddScript($WorkerScript) | Out-Null
    $PS.BeginInvoke() | Out-Null
}

# ============================================================
#  PRESET LOGIC
#  Called from preset button click handlers and on initial load.
#  Uses $Script:StatusLabels to reach checkboxes and
#  $Script:PresetBtns to update button highlighting.
# ============================================================
function Apply-Preset {
    param(
        [Parameter(Mandatory)] [string]$PresetName,
        [Parameter(Mandatory)] [array] $AllModuleDefs
    )

    $Script:ActivePreset  = $PresetName

    # ── Update button highlighting ────────────────────────────
    foreach ($pn in $Script:PresetBtns.Keys) {
        $pb = $Script:PresetBtns[$pn]
        if ($pn -eq $PresetName) {
            $pb.BackColor = $Script:Theme.Accent
            $pb.ForeColor = $Script:Theme.BgDark
            $pb.FlatAppearance.BorderColor = $Script:Theme.Accent
        } else {
            $pb.BackColor = $Script:Theme.BgCard
            $pb.ForeColor = $Script:Theme.Gray
            $pb.FlatAppearance.BorderColor = $Script:Theme.Separator
        }
    }

    # Custom preset — just highlight the button; don't touch checkboxes.
    if ($Script:Presets[$PresetName] -eq "custom") { return }

    # ── Update checkboxes without triggering the "switch to Custom" handler
    $Script:ApplyingPreset = $true
    try {
        $selectedIds = $Script:Presets[$PresetName]   # $null = all modules
        foreach ($mod in $AllModuleDefs) {
            $chk = $Script:StatusLabels[$mod.Id + "_chk"]
            if (-not $chk) { continue }
            $chk.Checked = ($null -eq $selectedIds) -or ($mod.Id -in $selectedIds)
        }
    } finally {
        $Script:ApplyingPreset = $false
    }
}

Write-Verbose "[MainForm] Main form loaded."
