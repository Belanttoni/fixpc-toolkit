<#
.SYNOPSIS
    FixPC Toolkit — UI Components
    Reusable WinForms control factory functions.
    Components know about layout. They do NOT know about business logic.

.VERSION 1.0
#>

function New-HeaderPanel {
    param([string]$Version = "1.0")

    $panel           = New-Object System.Windows.Forms.Panel
    $panel.Size      = New-Object System.Drawing.Size(820, 70)
    $panel.Location  = New-Object System.Drawing.Point(0, 0)
    $panel.BackColor = $Script:Theme.BgHeader

    $title           = New-Object System.Windows.Forms.Label
    $title.Text      = "  FixPC Toolkit  v$Version"
    $title.Font      = $Script:Fonts.Title
    $title.ForeColor = $Script:Theme.Accent
    $title.Location  = New-Object System.Drawing.Point(10, 8)
    $title.Size      = New-Object System.Drawing.Size(500, 32)

    $sub             = New-Object System.Windows.Forms.Label
    $sub.Text        = "  Ticket: My PC is very slow   |   Computer: $env:COMPUTERNAME   |   User: $env:USERNAME"
    $sub.Font        = $Script:Fonts.Small
    $sub.ForeColor   = $Script:Theme.Gray
    $sub.Location    = New-Object System.Drawing.Point(10, 44)
    $sub.Size        = New-Object System.Drawing.Size(780, 18)

    $panel.Controls.AddRange(@($title, $sub))
    return $panel
}

function New-ModuleRow {
    param(
        [PSCustomObject] $ModuleDef,
        [int]            $YOffset,
        [int]            $RowIndex,
        [hashtable]      $LabelStore   # out: populated with label references
    )

    $rowH  = 25
    $col1  = 8;   $col2 = 32;  $col3 = 290; $col4 = 520; $col5 = 655
    $bg    = if ($RowIndex % 2 -eq 0) { $Script:Theme.BgMid } else { $Script:Theme.BgCard }

    $row           = New-Object System.Windows.Forms.Panel
    $row.Location  = New-Object System.Drawing.Point(0, ($YOffset - 2))
    $row.Size      = New-Object System.Drawing.Size(790, $rowH)
    $row.BackColor = $bg

    $dot           = New-Object System.Windows.Forms.Label
    $dot.Text      = "$([char]0x25CF)"
    $dot.Location  = New-Object System.Drawing.Point($col1, 4)
    $dot.Size      = New-Object System.Drawing.Size(22, 18)
    $dot.ForeColor = $Script:Theme.Gray
    $dot.Font      = New-Object System.Drawing.Font("Segoe UI", 8)

    $nameL           = New-Object System.Windows.Forms.Label
    $nameL.Text      = $ModuleDef.Name
    $nameL.Location  = New-Object System.Drawing.Point($col2, 5)
    $nameL.Size      = New-Object System.Drawing.Size(255, 16)
    $nameL.Font      = $Script:Fonts.Bold
    $nameL.ForeColor = $Script:Theme.White

    $descL           = New-Object System.Windows.Forms.Label
    $descL.Text      = $ModuleDef.Desc
    $descL.Location  = New-Object System.Drawing.Point($col3, 6)
    $descL.Size      = New-Object System.Drawing.Size(225, 15)
    $descL.Font      = $Script:Fonts.Small
    $descL.ForeColor = $Script:Theme.Gray

    $statusL           = New-Object System.Windows.Forms.Label
    $statusL.Text      = "$([char]0x2014) PENDING $([char]0x2014)"
    $statusL.Location  = New-Object System.Drawing.Point($col4, 5)
    $statusL.Size      = New-Object System.Drawing.Size(130, 16)
    $statusL.Font      = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $statusL.ForeColor = $Script:Theme.Gray

    $timeL           = New-Object System.Windows.Forms.Label
    $timeL.Text      = ""
    $timeL.Location  = New-Object System.Drawing.Point($col5, 6)
    $timeL.Size      = New-Object System.Drawing.Size(100, 15)
    $timeL.Font      = $Script:Fonts.Small
    $timeL.ForeColor = $Script:Theme.Gray

    $row.Controls.AddRange(@($dot, $nameL, $descL, $statusL, $timeL))

    # Store references for external update
    $id = $ModuleDef.Id
    $LabelStore[$id]           = $statusL
    $LabelStore[$id + "_dot"]  = $dot
    $LabelStore[$id + "_time"] = $timeL

    return $row
}

function New-ActionButton {
    param(
        [string] $Text,
        [System.Drawing.Point] $Location,
        [System.Drawing.Size]  $Size,
        [System.Drawing.Color] $BackColor,
        [System.Drawing.Color] $ForeColor,
        [System.Drawing.Color] $BorderColor,
        [bool]                  $Enabled = $true
    )

    $btn           = New-Object System.Windows.Forms.Button
    $btn.Text      = $Text
    $btn.Location  = $Location
    $btn.Size      = $Size
    $btn.BackColor = $BackColor
    $btn.ForeColor = $ForeColor
    $btn.Font      = $Script:Fonts.Bold
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize  = if ($BorderColor -ne $BackColor) { 1 } else { 0 }
    if ($BorderColor -ne $BackColor) { $btn.FlatAppearance.BorderColor = $BorderColor }
    $btn.Cursor    = "Hand"
    $btn.Enabled   = $Enabled
    return $btn
}

function New-ProgressSection {
    param([System.Drawing.Point]$Location)

    $panel           = New-Object System.Windows.Forms.Panel
    $panel.Location  = $Location
    $panel.Size      = New-Object System.Drawing.Size(790, 38)
    $panel.BackColor = $Script:Theme.BgMid

    $bar          = New-Object System.Windows.Forms.ProgressBar
    $bar.Location = New-Object System.Drawing.Point(0, 5)
    $bar.Size     = New-Object System.Drawing.Size(790, 16)
    $bar.Minimum  = 0
    $bar.Maximum  = 100
    $bar.Value    = 0
    $bar.Style    = "Continuous"

    $lbl           = New-Object System.Windows.Forms.Label
    $lbl.Text      = "Ready $([char]0x2014) Press 'Run Diagnostic' to start"
    $lbl.Location  = New-Object System.Drawing.Point(0, 23)
    $lbl.Size      = New-Object System.Drawing.Size(790, 14)
    $lbl.Font      = $Script:Fonts.Small
    $lbl.ForeColor = $Script:Theme.Gray
    $lbl.TextAlign = "MiddleCenter"

    $panel.Controls.AddRange(@($bar, $lbl))
    return @{ Panel = $panel; Bar = $bar; Label = $lbl }
}

function New-LogBox {
    param([System.Drawing.Point]$Location, [System.Drawing.Size]$Size)

    $box            = New-Object System.Windows.Forms.RichTextBox
    $box.Location   = $Location
    $box.Size       = $Size
    $box.BackColor  = $Script:Theme.BgLog
    $box.ForeColor  = $Script:Theme.LogGreen
    $box.Font       = $Script:Fonts.Mono
    $box.ReadOnly   = $true
    $box.BorderStyle= "None"
    $box.ScrollBars = "Vertical"
    return $box
}

Write-Verbose "[Components] UI components loaded."
