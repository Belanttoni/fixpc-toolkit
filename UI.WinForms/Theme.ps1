<#
.SYNOPSIS
    FixPC Toolkit — UI Theme
    Centralized color palette and font definitions for the WinForms UI.
    All UI components import from here. Never hardcode colors in UI files.

.VERSION 1.0
#>

Add-Type -AssemblyName System.Drawing

# ============================================================
#  COLOR PALETTE
# ============================================================
$Script:Theme = @{
    BgDark    = [System.Drawing.Color]::FromArgb(13,  13,  26)
    BgMid     = [System.Drawing.Color]::FromArgb(19,  19,  38)
    BgCard    = [System.Drawing.Color]::FromArgb(26,  26,  50)
    BgHeader  = [System.Drawing.Color]::FromArgb(10,  20,  50)
    BgLog     = [System.Drawing.Color]::FromArgb(8,   8,   18)
    Accent    = [System.Drawing.Color]::FromArgb(0,   212, 255)
    Green     = [System.Drawing.Color]::FromArgb(40,  167, 69)
    Yellow    = [System.Drawing.Color]::FromArgb(255, 193, 7)
    Red       = [System.Drawing.Color]::FromArgb(255, 77,  109)
    Gray      = [System.Drawing.Color]::FromArgb(120, 130, 160)
    White     = [System.Drawing.Color]::FromArgb(220, 220, 238)
    Separator = [System.Drawing.Color]::FromArgb(30,  30,  60)
    LogGreen  = [System.Drawing.Color]::FromArgb(80,  200, 100)
    LogYellow = [System.Drawing.Color]::FromArgb(255, 193, 7)
    LogRed    = [System.Drawing.Color]::FromArgb(255, 100, 120)
    LogBlue   = [System.Drawing.Color]::FromArgb(80,  180, 220)
    LogCyan   = [System.Drawing.Color]::FromArgb(0,   212, 255)
}

# ============================================================
#  FONTS
# ============================================================
$Script:Fonts = @{
    Title  = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
    Sub    = New-Object System.Drawing.Font("Segoe UI",  9, [System.Drawing.FontStyle]::Regular)
    Bold   = New-Object System.Drawing.Font("Segoe UI",  9, [System.Drawing.FontStyle]::Bold)
    Small  = New-Object System.Drawing.Font("Segoe UI",  8, [System.Drawing.FontStyle]::Regular)
    Tiny   = New-Object System.Drawing.Font("Segoe UI",  7, [System.Drawing.FontStyle]::Bold)
    Mono   = New-Object System.Drawing.Font("Consolas",  8, [System.Drawing.FontStyle]::Regular)
}

# ============================================================
#  LOG COLORS BY MESSAGE TYPE
# ============================================================
function Get-LogColor {
    param([string]$Type)
    switch ($Type) {
        "ok"    { return $Script:Theme.LogGreen   }
        "warn"  { return $Script:Theme.LogYellow  }
        "error" { return $Script:Theme.LogRed     }
        "info"  { return $Script:Theme.LogBlue    }
        "step"  { return $Script:Theme.LogCyan    }
        default { return $Script:Theme.LogGreen   }
    }
}

# ============================================================
#  STATUS → COLORS
# ============================================================
function Get-StatusColor {
    param([string]$Status)
    switch ($Status) {
        "ok"      { return $Script:Theme.Green  }
        "warn"    { return $Script:Theme.Yellow }
        "error"   { return $Script:Theme.Red    }
        "running" { return $Script:Theme.Accent }
        default   { return $Script:Theme.Gray   }
    }
}

Write-Verbose "[Theme] UI theme loaded."
