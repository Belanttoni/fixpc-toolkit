@echo off
cd /d "%~dp0"

if not exist "%~dp0pwsh\pwsh.exe" (
    echo PowerShell portable nao encontrado em:
    echo %~dp0pwsh\pwsh.exe
    pause
    exit /b 1
)

"%~dp0pwsh\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0FixPC-Toolkit.ps1"

pause