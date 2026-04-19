# FixPC Toolkit

FixPC Toolkit is a modular PC diagnostic and repair project designed for IT support workflows.

## Project Goals
- Build a structured and scalable diagnostic tool
- Keep WinForms as Version 1
- Plan a future migration to WPF in Version 2
- Separate system, network, and hardware logic into independent modules
- Generate clear technical reports for support operations

## Planned Versions
- **V1:** WinForms
- **V2:** WPF

## Planned Modules
- System
- Network
- Hardware
- Reports
- Core application services

## Repository Structure
- `App/` Application bootstrap and workflow orchestration
- `Core/` Shared services, state, logging, validation, utilities
- `Modules/` System, Network, Hardware, and shared module contracts
- `Reports/` HTML, TXT, and JSON reporting
- `UI.WinForms/` Version 1 interface
- `UI.WPF/` Version 2 interface
- `Docs/` Architecture, phases, framework, and flowcharts
- `Tests/` Validation and module tests
- `Build/` Packaging and release helpers

## Status
Project planning and repository structure initialized.

## Documentation
See the `Docs/` folder for:
- framework
- phases
- flowcharts
- repository blueprint
- GitHub setup