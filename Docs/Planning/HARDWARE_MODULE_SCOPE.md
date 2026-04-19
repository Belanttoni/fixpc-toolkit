# Hardware Module Scope

## Purpose
This document defines the scope of the Hardware module for FixPC Toolkit V1.

## Module Identity
The Hardware module is responsible for hardware health visibility, thermal awareness planning, identity collection, and device-level condition indicators.

## Primary Goal
Provide a structured hardware overview and identify warning conditions that may affect stability, performance, or reliability.

## Internal Lifecycle
The Hardware module follows the standard lifecycle:
- Collect
- Analyze
- Repair
- Export

## Collect Scope
The Hardware module may collect the following information in V1:

- CPU model and basic identity
- motherboard identity
- BIOS version and vendor
- total installed RAM
- disk inventory overview
- SMART summary where available
- basic CPU usage indicators
- basic RAM usage indicators
- basic disk usage indicators
- thermal data planning placeholders
- future sensor availability checks
- optional battery information for portable devices where feasible

## Analyze Scope
The Hardware module must analyze findings such as:

- SMART warning indicators
- storage health concerns
- BIOS visibility issues
- missing hardware identity information
- probable thermal concern indicators
- probable hardware stress indicators
- memory capacity concern indicators
- storage reliability warning indicators

## Repair Scope
The Hardware module has limited direct repair responsibilities in V1.

### SafeRepair
Allowed examples:
- no direct intrusive repair by default
- guidance-oriented recommendations only

### FullRepair
Allowed examples:
- still primarily recommendation-driven
- no unrestricted automatic hardware remediation

In V1, the Hardware module is mainly diagnostic and advisory.

## Export Scope
The Hardware module must export:

- hardware identity summary
- storage health summary
- BIOS and motherboard summary
- recommendations
- severity
- future-ready placeholders for sensor-based output
- report-friendly output for HTML, TXT, and JSON

## Severity Guidelines

### ok
Hardware state appears healthy.

### info
No active concern is found, but useful hardware information is available.

### warn
A relevant hardware concern exists.
Examples:
- SMART caution
- incomplete BIOS visibility
- probable thermal suspicion

### error
A significant hardware risk exists.
Examples:
- unhealthy SMART result
- repeated storage warning
- severe capacity or stability concern

### critical
A severe hardware risk exists.
Examples:
- strong failure indicators on storage
- major thermal danger if sensor support becomes available
- conditions suggesting urgent intervention

## V1 Boundaries
The Hardware module in V1 does not aim to:
- replace dedicated hardware diagnostics from vendors
- perform direct firmware updates
- control fans or low-level hardware settings
- guarantee universal sensor visibility on all motherboards

## V1 Success Criteria
The Hardware module is considered structurally ready when:
- identity collection scope is documented
- health-related analysis expectations are documented
- advisory-only repair rules are documented
- export expectations are documented
- severity mapping is defined

## Future Direction
Future versions may expand this module to include:
- CPU temperature
- motherboard temperature
- NVMe and SSD temperature
- fan speed
- advanced sensor integration
- notebook battery health
- richer motherboard and controller telemetry