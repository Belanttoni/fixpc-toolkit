# PawnIO — Kernel Sensor Driver

PawnIO is a low-level kernel driver that enables hardware monitoring tools
(such as LibreHardwareMonitorLib) to read CPU temperature sensors on modern
Windows systems where ring-3 access is insufficient.

---

## For end users

If CPU temperature is unavailable in Hardware Diagnostics and
`PawnIO_setup.exe` is present in this folder, FixPC Toolkit will
**automatically install PawnIO** when run in **SafeRepair** or **FullRepair**
mode.

- **DiagnoseOnly mode**: PawnIO is never installed automatically.
- **Administrator privileges** are required. If FixPC Toolkit is not running
  as Administrator, the install step is skipped and logged.
- The install is non-fatal: if it fails, Hardware Diagnostics continues with
  the available fallbacks (WMI bridge, ACPI, drive temperatures, battery health).
- A system **reboot may be required** after install for the driver to become active.

---

## For developers / release builders

### Obtaining PawnIO_setup.exe

Place the official `PawnIO_setup.exe` installer in this directory.
FixPC Toolkit expects it at:

```
Tools\PawnIO\PawnIO_setup.exe
```

If the file is absent, the install step is silently skipped.

### Install command

FixPC Toolkit runs the installer as:

```
PawnIO_setup.exe -install -silent
```

A 30-second timeout is enforced. Exit code `0` = success.

### Uninstall

To remove PawnIO from a system, run:

```
PawnIO_setup.exe -uninstall -silent
```

FixPC Toolkit does not perform automatic uninstallation.

---

## What git tracks

| Path | Tracked | Notes |
|---|---|---|
| `Tools/PawnIO/PawnIO_setup.exe` | ✔ yes (if present) | prebuilt installer |
| `Tools/PawnIO/README.md` | ✔ yes | this file |

---

## Security notes

- PawnIO operates at kernel level (ring 0). Installation requires
  Administrator privileges.
- FixPC Toolkit uses PawnIO in **read-only** mode: it reads sensor values
  and performs no hardware writes, fan control, or configuration changes.
- The PawnIO service is registered under the name `PawnIO`.
  FixPC Toolkit detects it via `Get-Service -Name PawnIO`.
