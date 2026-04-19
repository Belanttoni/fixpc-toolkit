# FixPC Toolkit Project Phases

## Product direction

- **Version 1:** WinForms
- **Version 2:** WPF
- **Current objective:** create a stable, modular, maintainable diagnostic and repair platform before redesigning the UI stack.

## Phase 1 - Repository and project foundation

### Goal
Create a clean GitHub-based project foundation.

### Deliverables
- GitHub repository created
- Branch strategy defined
- Labels, milestones, and project board created
- README, roadmap, and architecture docs added
- Initial folder structure added

### Success criteria
- Repository is online
- `main` and `dev` exist
- Project documentation is in English

## Phase 2 - Architecture refactor for WinForms V1

### Goal
Move from a single-script implementation to a modular project structure.

### Deliverables
- `App/`
- `Core/`
- `Modules/`
- `Reports/`
- `UI.WinForms/`
- Common module contract
- Common severity model
- Application state model
- Main workflow/orchestrator design

### Success criteria
- UI no longer contains business logic directly
- Modules can be called from a central workflow

## Phase 3 - System module foundation

### Goal
Transform the current OS diagnostics into a structured module.

### Scope
- System information
- SFC
- DISM
- CHKDSK
- temporary files cleanup
- startup analysis
- event viewer analysis
- disk SMART health
- RAM checks
- Windows Update analysis

### Deliverables
- `System.Definitions`
- `System.Collect`
- `System.Analyze`
- `System.Repair`
- `System.Export`

### Success criteria
- System logic is no longer tied to the form
- Findings, recommendations, and actions are structured

## Phase 4 - Network module

### Goal
Create a complete and independent network troubleshooting module.

### Scope
- adapter discovery
- IP, subnet, gateway, DNS
- loopback test
- gateway test
- internet reachability test
- DNS resolution test
- proxy detection
- DHCP and Winsock-related repair actions

### Deliverables
- `Network.Definitions`
- `Network.Collect`
- `Network.Analyze`
- `Network.Repair`
- `Network.Export`

### Success criteria
- Network failures are classified by layer
- Safe and complete repair modes are separated

## Phase 5 - Hardware module

### Goal
Add physical health visibility.

### Scope
- motherboard and BIOS identification
- CPU temperature
- motherboard temperature
- storage temperature
- fan speed
- battery health for laptops (optional)

### Deliverables
- `Hardware.Definitions`
- `Hardware.Collect`
- `Hardware.Analyze`
- `Hardware.Repair` (limited or advisory only)
- `Hardware.Export`

### Success criteria
- Hardware health is visible in the report
- Thermal warnings are classified correctly

## Phase 6 - Reporting and diagnostics output

### Goal
Standardize output across all modules.

### Deliverables
- HTML report engine
- TXT summary
- JSON export
- unified result model
- final diagnostic summary
- health score

### Success criteria
- All modules export consistent data
- Reports can be generated without depending on UI controls

## Phase 7 - WinForms V1 polish

### Goal
Improve the current WinForms experience without changing the application core.

### Deliverables
- cleaner layout
- grouped modules
- mode selection
- summary cards
- better status badges
- report access improvements
- better log view

### Success criteria
- WinForms version looks cleaner and feels more professional
- UI is only a presentation layer

## Phase 8 - Packaging and release process

### Goal
Prepare the application for repeatable distribution.

### Deliverables
- build process documentation
- packaging script
- versioning rules
- release checklist
- changelog policy

### Success criteria
- Stable builds can be packaged consistently
- Releases can be published through GitHub Releases

## Phase 9 - WPF V2 migration plan

### Goal
Prepare and then deliver a WPF interface using the same core application logic.

### Deliverables
- WPF information architecture
- screen map
- view model strategy
- migration checklist
- compatibility layer between workflow and UI

### Success criteria
- Core modules remain unchanged
- WPF replaces the UI layer only

## Phase 10 - WPF V2 implementation

### Goal
Launch the second-generation UI.

### Deliverables
- WPF main window
- dashboard and module views
- modern theming
- enhanced status visualization
- reusable styles and templates

### Success criteria
- WPF version uses the same workflow and modules as WinForms
- UI becomes more scalable and visually modern
