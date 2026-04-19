# Repair Policy

## Purpose
This document defines the rules and boundaries for repair actions in FixPC Toolkit V1.

## Core Principle
Repair actions must be:
- controlled
- predictable
- logged
- reversible when possible

## Repair Categories

### SafeRepair
Low-risk actions only.

Characteristics:
- minimal system impact
- safe to execute without high risk
- no deep system changes

Examples:
- temporary file cleanup
- DNS flush
- SFC scan
- service restart (controlled)

---

### FullRepair
Higher-impact actions allowed.

Characteristics:
- deeper system changes
- potential side effects
- must be clearly logged

Examples:
- DISM restore
- network stack reset
- deeper remediation workflows

---

## Global Rules

### Rule 1
No repair action should run without prior analysis.

### Rule 2
All repair actions must be recorded in `ActionsTaken`.

### Rule 3
Repair actions must respect execution mode.

### Rule 4
Critical system changes must be limited and controlled.

### Rule 5
The tool must not perform destructive actions.

---

## Safety Rules

### Rule 6
No automatic reboot in V1.

### Rule 7
No forced disk operations without explicit design.

### Rule 8
No registry modifications without clear justification.

### Rule 9
No external network configuration changes beyond scope.

---

## Logging Requirements

Every repair action must log:
- action name
- timestamp
- target component
- result (success/failure)

---

## V1 Boundaries

The repair system in V1 must NOT:
- act autonomously without user initiation
- execute high-risk operations silently
- attempt full system recovery scenarios

---

## Future Direction

Future versions may include:
- more granular repair levels
- rollback mechanisms
- guided repair workflows