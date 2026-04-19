# Application Workflow

## Purpose
This document defines the official runtime workflow for FixPC Toolkit V1.

## Workflow Overview
The application workflow is responsible for coordinating:
- application startup
- environment validation
- module selection
- execution mode
- module orchestration
- result consolidation
- report generation
- final user feedback

## High-Level Workflow

1. Application starts
2. Environment is validated
3. UI is initialized
4. User selects modules
5. User selects execution mode
6. Application starts workflow execution
7. Selected modules run in sequence
8. Results are consolidated
9. Reports are generated
10. Final status is shown to the user

## Detailed Workflow

### 1. Startup
The application loads:
- configuration
- shared state
- UI settings
- available modules

### 2. Environment Validation
Before execution, the application must validate:
- administrative privileges
- supported Windows version
- required dependencies
- report output location
- required assets and libraries

If validation fails, execution must stop and the UI must show the failure reason.

### 3. UI Initialization
The UI must:
- display system identity
- show available modules
- show default execution mode
- initialize progress and log areas

### 4. Module Selection
The user may choose one or more modules:
- System
- Network
- Hardware

If no module is selected, execution must not begin.

### 5. Execution Mode Selection
The application supports the following modes:

#### DiagnoseOnly
- collect data
- analyze findings
- generate reports
- do not perform repairs

#### SafeRepair
- run approved low-risk repair actions
- preserve system stability
- avoid aggressive resets

#### FullRepair
- allow all approved repair actions
- include deeper corrective workflows
- require stronger validation and user awareness

### 6. Workflow Execution
The application starts the selected workflow and:
- updates shared state
- updates progress
- writes live logs
- executes modules in defined order

### 7. Module Execution Order
Default execution order for V1:

1. System
2. Network
3. Hardware

This order may be adjusted in future versions if needed.

### 8. Result Consolidation
After all selected modules complete, the application consolidates:
- module status
- findings
- recommendations
- actions taken
- duration
- final severity
- final health overview

### 9. Report Generation
The application generates reports based on the consolidated result.

Planned report formats:
- HTML
- TXT
- JSON

### 10. Final Feedback
The UI must show:
- overall execution status
- module-by-module summary
- warnings and critical items
- report availability
- final recommendations

## Workflow Rules

### Rule 1
The UI must never contain business logic.

### Rule 2
Workflow orchestration must be independent from the UI technology.

### Rule 3
Reports must be generated from consolidated results, not directly from UI components.

### Rule 4
All modules must follow a shared execution contract.

### Rule 5
Validation failures must stop execution before module processing starts.

## V1 Notes
V1 uses WinForms as the official interface.

The workflow logic must be designed so it can later be reused by the WPF interface in V2 without rewriting the application core.