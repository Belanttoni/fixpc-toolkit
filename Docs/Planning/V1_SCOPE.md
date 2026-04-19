
---

# 3) `V1_SCOPE.md`

```md
# V1 Scope

## Purpose
This document defines the official scope of FixPC Toolkit Version 1.

## Version Identity
Version 1 is the first operational release of FixPC Toolkit.

V1 uses:
- WinForms for the user interface
- modular architecture for internal organization
- shared contracts for module execution and reporting

## Primary Goal
Deliver a stable and structured diagnostic and repair tool with a reusable application core.

## V1 Included Areas

### 1. Application Foundation
V1 includes:
- startup flow
- validation flow
- module orchestration
- execution modes
- shared state design
- logging strategy

### 2. User Interface
V1 uses WinForms.

The WinForms interface must support:
- main dashboard
- module status table
- progress feedback
- live log display
- execution controls
- report access

### 3. System Module
V1 includes System planning and implementation scope for:
- system information
- SFC
- DISM
- CHKDSK
- temporary files
- startup programs
- event viewer checks
- Windows Update review
- SMART review
- memory-related checks

### 4. Network Module
V1 includes Network planning and implementation scope for:
- IP information
- adapter state
- loopback test
- gateway test
- internet reachability test
- DNS resolution test
- repair-safe network actions
- full repair network actions

### 5. Hardware Module
V1 includes Hardware planning and implementation scope for:
- CPU usage and status
- RAM and disk overview
- motherboard and BIOS identity
- SMART integration
- future-ready sensor planning
- thermal analysis planning

### 6. Reports
V1 includes report architecture for:
- HTML output
- TXT output
- JSON output
- consolidated execution summaries
- recommendations and actions taken

## Execution Modes in V1

### DiagnoseOnly
Required in V1.

### SafeRepair
Required in V1.

### FullRepair
Required in V1, but must be controlled and clearly separated from safe repair actions.

## V1 Non-Goals
The following items are not required for V1:
- WPF as the main UI
- AI-based diagnosis
- cloud synchronization
- remote multi-device orchestration
- advanced historical analytics
- plugin marketplace model

## V1 Exit Criteria
V1 may be considered structurally complete when:
- repository structure is stable
- application workflow is defined
- module contract is defined
- WinForms V1 scope is documented
- System, Network, and Hardware scope are documented
- reporting strategy is documented
- migration path to WPF V2 is documented

## Future Direction
V1 is intentionally designed to support a future WPF migration in V2 without rewriting the application core.