<#
.SYNOPSIS
    Builds FixPC.SensorBridge.exe and places it in Tools\SensorBridge\.

.DESCRIPTION
    Requires the .NET SDK (https://dot.net).
    After building, PowerShell HardwareCollect.ps1 will automatically use
    the EXE when it is present in this folder.

.NOTES
    Default target: net8.0 (framework-dependent — requires .NET 8 runtime on target machine).

    To produce a self-contained single EXE that needs no .NET runtime:
        dotnet publish FixPC.SensorBridge.csproj `
            --configuration Release `
            --runtime win-x64 `
            --self-contained true `
            -p:PublishSingleFile=true `
            --output $PSScriptRoot

    To target .NET Framework 4.7.2 (works on all Windows 10+ without extra runtime):
        1. Edit FixPC.SensorBridge.csproj: change <TargetFramework> to net472
        2. Add: <PackageReference Include="Newtonsoft.Json" Version="13.*" />
        3. Update Program.cs to use Newtonsoft.Json.JsonConvert.SerializeObject()
        4. Run: dotnet publish FixPC.SensorBridge.csproj --configuration Release --output $PSScriptRoot
#>

#Requires -Version 5.1

$ScriptDir   = $PSScriptRoot
$ProjectFile = Join-Path $ScriptDir "FixPC.SensorBridge.csproj"
$OutDir      = $ScriptDir

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Error "dotnet SDK not found. Install it from https://dot.net and retry."
    exit 1
}

Write-Host "Building FixPC.SensorBridge..." -ForegroundColor Cyan
dotnet publish $ProjectFile `
    --configuration Release `
    --output $OutDir `
    --no-self-contained 2>&1

if ($LASTEXITCODE -eq 0) {
    $exePath = Join-Path $OutDir "FixPC.SensorBridge.exe"
    if (Test-Path $exePath) {
        Write-Host "Build succeeded: $exePath" -ForegroundColor Green
    } else {
        Write-Warning "Build exited cleanly but EXE not found at expected path."
    }
} else {
    Write-Error "Build failed (exit $LASTEXITCODE)."
    exit $LASTEXITCODE
}
