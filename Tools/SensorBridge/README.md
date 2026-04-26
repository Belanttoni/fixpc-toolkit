# FixPC.SensorBridge

A lightweight .NET console app that reads CPU temperature sensors via
**LibreHardwareMonitorLib** and writes JSON to stdout.  PowerShell's
`HardwareCollect.ps1` calls it as a child process so the .NET runtime
handles all dependency resolution naturally — no `Add-Type`, no assembly
loading tricks required inside PowerShell.

---

## For end users

`FixPC.SensorBridge.exe` is a **prebuilt runtime dependency** included in
every FixPC Toolkit release package.  You do not need to build anything.

If the EXE is present in this folder, Hardware Diagnostics will use it for
CPU temperature readings.  If it is absent, the toolkit falls back to the
LHM/OHM WMI bridge and ACPI thermal zones automatically — no configuration
needed.

---

## For developers / release builders

### Prerequisites

- [.NET SDK 8.0+](https://dotnet.microsoft.com/download)

### Build and publish

Run the included `Build.ps1` from this directory:

```powershell
.\Build.ps1
```

This calls `dotnet publish` and places the output (EXE + all dependency DLLs)
directly in `Tools\SensorBridge\`.  Those files are the runtime distribution
and are tracked in git / included in the release ZIP.

### Manual build command

```powershell
dotnet publish FixPC.SensorBridge.csproj `
    --configuration Release `
    --output . `
    --no-self-contained
```

### Self-contained single-file (optional)

To produce a single EXE that requires no .NET runtime on the target machine
(larger file, ~60 MB):

```powershell
dotnet publish FixPC.SensorBridge.csproj `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    --output .
```

### .NET Framework 4.7.2 target (no .NET runtime required on target)

If the target machine may not have .NET 8 installed:

1. Change `<TargetFramework>` in `FixPC.SensorBridge.csproj` to `net472`
2. Add a NuGet reference to `Newtonsoft.Json` (version 13.x)
3. Replace `System.Text.Json.JsonSerializer.Serialize` in `Program.cs`
   with `Newtonsoft.Json.JsonConvert.SerializeObject`
4. Run `dotnet publish` as above

---

## Release packaging

When creating a release ZIP, include the entire published output from
`Tools\SensorBridge\` (EXE + DLLs).  The source files (`Program.cs`,
`*.csproj`, `Build.ps1`, `README.md`) may be omitted from the release
package but should remain in the repository.

### What git tracks

| Path | Tracked | Notes |
|---|---|---|
| `Tools/SensorBridge/FixPC.SensorBridge.exe` | ✔ yes | prebuilt runtime |
| `Tools/SensorBridge/*.dll` | ✔ yes | prebuilt runtime deps |
| `Tools/SensorBridge/*.runtimeconfig.json` | ✔ yes | prebuilt runtime config |
| `Tools/SensorBridge/Program.cs` | ✔ yes | source |
| `Tools/SensorBridge/FixPC.SensorBridge.csproj` | ✔ yes | source |
| `Tools/SensorBridge/Build.ps1` | ✔ yes | developer tooling |
| `Tools/SensorBridge/obj/` | ✘ ignored | MSBuild intermediate |
| `Tools/SensorBridge/bin/` | ✘ ignored | MSBuild default output |

---

## JSON output format

```json
{
  "source": "SensorBridge",
  "temperatures": [
    { "name": "CPU Package", "hardwareName": "Intel Core i7-...", "value": 45.5 }
  ],
  "fans": [
    { "name": "Fan #1", "hardwareName": "...", "value": 1200.0 }
  ],
  "levels": [
    { "name": "Charge Level", "hardwareName": "Battery", "value": 85.0 }
  ]
}
```

On error:

```json
{ "error": "message" }
```

Exit code `0` = success, `1` = error.
