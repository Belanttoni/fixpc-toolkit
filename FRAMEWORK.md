# FixPC Toolkit Framework

## 1. Product vision

FixPC Toolkit is a modular Windows support application designed to diagnose, analyze, and optionally repair endpoint issues across system, network, and hardware domains.

## 2. Design principles

- **Modular first**
- **UI-independent core**
- **Safe repair separation**
- **Structured output**
- **GitHub-driven development**
- **WinForms now, WPF later**

## 3. Application layers

```text
UI Layer
Application Layer
Module Layer
Core Layer
Report Layer
```

## 4. Layer responsibilities

### UI Layer
Responsible for:
- rendering screens
- receiving user interaction
- showing progress
- showing logs and findings
- opening reports

### Application Layer
Responsible for:
- orchestrating execution
- validating selected mode and modules
- updating application state
- consolidating results

### Module Layer
Responsible for:
- collecting raw data
- analyzing findings
- executing allowed repair actions
- exporting module-specific result sections

### Core Layer
Responsible for:
- logging
- runspaces/background execution
- global state
- helper functions
- validation and environment checks
- security checks

### Report Layer
Responsible for:
- HTML export
- TXT export
- JSON export
- final summary rendering

## 5. Module framework

Every module should follow the same lifecycle:

```text
Definitions -> Collect -> Analyze -> Repair -> Export
```

### Definitions
Contains:
- module metadata
- supported modes
- thresholds
- constants

### Collect
Contains:
- raw data gathering only
- no repair logic

### Analyze
Contains:
- finding generation
- severity classification
- recommendations
- score impact

### Repair
Contains:
- safe repair actions
- complete repair actions
- action logs

### Export
Contains:
- report section formatting
- normalized output blocks

## 6. Standard execution modes

### DiagnoseOnly
Runs collection, analysis, and reporting.
No changes are made to the machine.

### SafeRepair
Runs only low-risk repair actions.

### FullRepair
Runs broader repair actions after analysis.

## 7. Standard module result model

```text
ModuleResult
├── ModuleName
├── Success
├── Severity
├── Findings
├── Recommendations
├── ActionsTaken
├── Data
├── ScoreImpact
├── StartedAt
├── FinishedAt
└── DurationSec
```

## 8. Severity model

Use a single severity model across the application:

- `ok`
- `info`
- `warn`
- `error`
- `critical`

## 9. Domain modules

### System
Focus:
- OS health
- file integrity
- Windows servicing state
- startup impact
- storage health
- memory indicators
- update state

### Network
Focus:
- adapter state
- IP and DNS correctness
- local connectivity
- internet reachability
- DNS resolution
- network repair actions

### Hardware
Focus:
- motherboard and BIOS data
- temperature telemetry
- fan telemetry
- storage temperature
- optional battery data

## 10. Core services

### Logging service
- live log output
- file log output
- severity tagging

### State service
- current module
- current step
- progress
- selected mode
- selected modules
- consolidated results

### Validation service
- admin rights
- Windows version support
- tool dependencies
- report path validation

### Execution service
- background execution
- UI-safe updates
- cancellation support (future)

## 11. Report framework

Reports should be UI-independent and generated from normalized module results.

### Output formats
- HTML
- TXT
- JSON

### Report sections
- machine summary
- execution mode
- module summary
- findings by module
- actions taken
- recommendations
- final health score

## 12. UI strategy

### V1 - WinForms
Use WinForms as the operational interface.
The priority is delivery speed and architecture stabilization.

### V2 - WPF
Use WPF as the upgraded interface.
The priority is better presentation, scalability, and modern UX.

## 13. Migration rule

The UI must call the workflow layer.
The workflow layer must call the modules.
Modules must never depend directly on UI controls.

## 14. Recommended folder structure

```text
FixPC-Toolkit/
├── App/
├── Core/
├── Modules/
│   ├── Common/
│   ├── System/
│   ├── Network/
│   └── Hardware/
├── Reports/
├── UI.WinForms/
├── UI.WPF/
├── Assets/
├── Tests/
└── Docs/
```

## 15. Governance model

Use GitHub for:
- versioning
- issues
- milestones
- releases
- project tracking
- documentation
