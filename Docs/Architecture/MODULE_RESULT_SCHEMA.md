# Module Result Schema

## Purpose
This document defines the standard result contract for all FixPC Toolkit modules.

## Goal
Every module must return results using a shared structure so the application can:
- consolidate results consistently
- generate reports reliably
- display findings uniformly in the UI
- support future UI migration from WinForms to WPF

## Standard Module Lifecycle
Each module must follow the same internal stages:
- Collect
- Analyze
- Repair
- Export

Not every execution mode must use all stages, but the contract must remain consistent.

## Required Result Structure

Each module result must provide the following fields:

- ModuleName
- Success
- ExecutionMode
- StartedAt
- FinishedAt
- DurationSeconds
- Severity
- Findings
- Recommendations
- ActionsTaken
- Errors
- Warnings
- Data
- ExportData

## Field Definitions

### ModuleName
Name of the module.

Examples:
- System
- Network
- Hardware

### Success
Boolean value indicating whether the module completed successfully.

### ExecutionMode
The mode used during execution.

Allowed values:
- DiagnoseOnly
- SafeRepair
- FullRepair

### StartedAt
Execution start timestamp.

### FinishedAt
Execution end timestamp.

### DurationSeconds
Total execution time in seconds.

### Severity
Overall severity returned by the module.

Allowed values:
- ok
- info
- warn
- error
- critical

### Findings
List of diagnostic findings identified by the module.

Examples:
- Low disk space
- DNS resolution failed
- CPU temperature high

### Recommendations
List of recommended next actions.

Examples:
- Run SFC scan
- Reset Winsock
- Check CPU cooling

### ActionsTaken
List of actions actually performed by the module.

Examples:
- Temporary files cleaned
- DNS cache flushed
- DISM executed

### Errors
List of hard failures encountered during execution.

### Warnings
List of non-blocking warnings encountered during execution.

### Data
Structured raw or analyzed module data used by the application and reports.

### ExportData
Report-oriented output prepared for HTML, TXT, or JSON generation.

## Severity Rules

### ok
No relevant issue found.

### info
Informational result only.

### warn
Issue found that requires attention but is not immediately critical.

### error
Important issue found that impacts normal operation.

### critical
Severe issue found that may require urgent intervention.

## Module Contract Rules

### Rule 1
All modules must return the same top-level schema.

### Rule 2
Modules may include custom fields inside `Data`, but must not change the top-level contract.

### Rule 3
Severity must reflect the overall state of the module result.

### Rule 4
Repair actions must be recorded in `ActionsTaken`.

### Rule 5
Findings and recommendations must be human-readable.

### Rule 6
Errors and warnings must be kept separate.

## Example Conceptual Result

```text
ModuleName: System
Success: true
ExecutionMode: DiagnoseOnly
Severity: warn
Findings:
- Low disk space on system drive
- Windows image repair recommended
Recommendations:
- Run DISM RestoreHealth
- Free disk space
ActionsTaken:
- None
Warnings:
- Event log access partially limited
Errors:
- None