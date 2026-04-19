# System Module Scope

## Purpose
This document defines the scope of the System module for FixPC Toolkit V1.

## Module Identity
The System module is responsible for operating system health, integrity checks, cleanup workflows, and system-level diagnostic findings.

## Primary Goal
Provide a structured view of Windows operating system condition and support controlled repair actions.

## Internal Lifecycle
The System module follows the standard lifecycle:
- Collect
- Analyze
- Repair
- Export

## Collect Scope
The System module may collect the following information in V1:

- operating system name and version
- build number
- uptime
- computer name
- current user
- CPU usage snapshot
- RAM usage snapshot
- disk usage snapshot
- system drive free space
- startup items
- recent critical event log entries
- Windows Update status overview
- SFC eligibility and results
- DISM eligibility and results
- CHKDSK eligibility and results
- SMART summary if exposed through system-level collection
- memory-related warning indicators

## Analyze Scope
The System module must analyze findings such as:

- low free disk space
- high system resource usage
- excessive uptime
- system file corruption indicators
- Windows image repair requirement
- event log critical patterns
- startup overload or high startup impact
- update backlog indicators
- disk warning indicators
- memory-related warning indicators

## Repair Scope
The System module supports the following repair categories in V1:

### SafeRepair
Allowed examples:
- temporary file cleanup
- low-risk service refresh workflows
- SFC execution
- log cleanup where appropriate

### FullRepair
Allowed examples:
- DISM repair execution
- deeper system remediation workflows
- controlled CHKDSK-related actions
- Windows Update remediation workflows where approved

## Export Scope
The System module must export:

- summarized findings
- system health recommendations
- actions taken
- severity
- key operating system identity information
- report-friendly output for HTML, TXT, and JSON

## Severity Guidelines

### ok
System state appears healthy.

### info
No active issue, but useful operational information is available.

### warn
A non-critical but relevant issue exists.
Examples:
- low disk space
- startup overload
- pending updates

### error
A significant operating system issue exists.
Examples:
- repeated event log failures
- SFC detected corruption
- DISM needed

### critical
A severe condition exists that may require urgent action.
Examples:
- major disk warning
- unrecoverable integrity failure
- repeated serious boot-related failures

## V1 Boundaries
The System module in V1 does not aim to:
- replace advanced forensic tools
- provide enterprise patch management
- perform unrestricted deep remediation automatically
- make autonomous decisions outside the workflow rules

## V1 Success Criteria
The System module is considered structurally ready when:
- its collection scope is documented
- its analysis scope is documented
- its repair categories are defined
- its export expectations are defined
- its severity mapping is defined

## Future Direction
Future versions may expand this module to include:
- deeper service analysis
- registry health checks
- BitLocker and Secure Boot awareness
- Defender and security state
- advanced storage and boot diagnostics