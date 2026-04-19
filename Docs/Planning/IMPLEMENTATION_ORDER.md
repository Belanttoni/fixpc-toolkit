# Implementation Order

## Purpose
This document defines the recommended implementation order for FixPC Toolkit V1.

## Goal
Ensure the project is built in a stable, logical, and low-risk sequence.

## Guiding Principle
The project should be implemented from the inside out:

1. Contracts and shared structure
2. Core services
3. Application workflow
4. First reference module
5. Additional modules
6. Reporting
7. WinForms UI integration
8. Packaging and V1 stabilization

## Implementation Order

### Phase 1 - Shared Foundations
Implement first:
- shared contracts
- severity model
- result schema
- execution mode definitions
- repair boundaries

### Phase 2 - Core Layer
Implement next:
- shared state model
- logging model
- validation model
- utility helpers
- execution support helpers

### Phase 3 - Application Layer
Implement next:
- bootstrap flow
- workflow coordinator
- execution context model
- result consolidation logic

### Phase 4 - System Module
Implement first practical module:
- collect
- analyze
- repair
- export

The System module acts as the reference model for all others.

### Phase 5 - Network Module
Implement after System:
- layered connectivity collection
- failure classification
- mode-based repair actions
- export

### Phase 6 - Hardware Module
Implement after Network:
- identity collection
- health indicators
- advisory analysis
- export

### Phase 7 - Reporting
Implement after at least one module is stable, then expand:
- HTML reporting
- TXT reporting
- JSON reporting
- consolidated execution summary

### Phase 8 - WinForms V1 UI
Integrate UI after the core execution model is stable:
- module grid
- execution controls
- progress display
- live log
- report access
- final summary

### Phase 9 - V1 Stabilization
Finalize:
- consistency validation
- result contract validation
- report validation
- workflow validation
- release readiness review

## Implementation Rules

### Rule 1
Do not start with UI-first implementation.

### Rule 2
Do not implement Network or Hardware before the System module establishes the reference pattern.

### Rule 3
Do not couple reporting logic to WinForms.

### Rule 4
Do not allow module-specific contract drift.

### Rule 5
Stabilize architecture before planning WPF implementation.

## Recommended Priority Summary

1. Contracts
2. Core
3. App
4. System
5. Network
6. Hardware
7. Reporting
8. WinForms UI
9. Stabilization

## V1 Notes
This order is intended to reduce rework and keep V1 architecture reusable for WPF V2.