# Execution Modes

## Purpose
This document defines the execution modes of FixPC Toolkit V1.

## Overview
Execution modes control how modules behave during runtime.

They determine:
- whether repair actions are allowed
- how aggressive the system can be
- how findings are handled

## Available Modes

### 1. DiagnoseOnly

#### Description
This mode performs:
- data collection
- analysis
- report generation

No repair actions are executed.

#### Use Cases
- initial diagnostics
- safe environment analysis
- reporting without changes

#### Behavior
- Collect → enabled
- Analyze → enabled
- Repair → disabled
- Export → enabled

---

### 2. SafeRepair

#### Description
This mode allows only low-risk repair actions.

It prioritizes:
- system stability
- reversible operations
- minimal impact

#### Examples of Allowed Actions
- temporary file cleanup
- DNS flush
- lightweight service refresh
- SFC execution

#### Behavior
- Collect → enabled
- Analyze → enabled
- Repair → limited
- Export → enabled

---

### 3. FullRepair

#### Description
This mode allows deeper repair actions.

It may include:
- system repair operations
- network resets
- advanced corrective actions

#### Examples of Allowed Actions
- DISM repair
- Winsock reset
- TCP/IP reset
- deeper system remediation

#### Behavior
- Collect → enabled
- Analyze → enabled
- Repair → full
- Export → enabled

---

## Mode Selection Rules

### Rule 1
User must explicitly select the execution mode.

### Rule 2
Default mode should be DiagnoseOnly.

### Rule 3
FullRepair must require clear user awareness.

### Rule 4
Repair actions must always be logged.

---

## V1 Notes
Execution modes are part of the application core and must not depend on UI implementation.

These modes must remain compatible with future WPF migration.