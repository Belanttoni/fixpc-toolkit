# Core Layer Design

## Purpose
This document defines the responsibility and structure of the Core layer in FixPC Toolkit V1.

## Role of the Core Layer
The Core layer provides shared services used by the entire application.

It is responsible for:
- shared state
- logging
- validation
- utility functions
- execution support
- contracts and shared models

## Core Layer Areas

### 1. State
The State area manages shared runtime information.

Examples:
- selected modules
- execution mode
- progress
- current action
- final result references

### 2. Logging
The Logging area manages:
- execution logs
- repair logs
- warnings
- failures
- reportable log entries

### 3. Validation
The Validation area checks:
- administrative privilege requirements
- required dependencies
- application readiness
- supported execution conditions

### 4. Utilities
The Utilities area provides shared helpers.

Examples:
- formatting helpers
- date/time helpers
- size conversions
- string normalization
- common lookups

### 5. Execution Support
The Execution area provides shared execution helpers.

Examples:
- safe process invocation
- background execution support
- timeout helpers
- cancellation-aware patterns in future versions

### 6. Contracts
The Contracts area provides:
- shared result schema
- severity definitions
- shared models
- common rule references

## Core Design Rules

### Rule 1
The Core layer must not depend on the UI.

### Rule 2
The Core layer must not contain module-specific business logic.

### Rule 3
The Core layer must be reusable by all modules.

### Rule 4
The Core layer must support both WinForms V1 and WPF V2 without redesign.

## Severity Model
The Core layer is the owner of the shared severity vocabulary:

- ok
- info
- warn
- error
- critical

No module may redefine severity labels independently.

## Shared Logging Expectations
All runtime and repair activities must be loggable through the Core layer.

Minimum log expectations:
- timestamp
- source area
- action description
- result status

## Shared Validation Expectations
Validation must happen before execution starts.

Examples:
- admin check
- dependency presence
- asset availability
- report path readiness

## V1 Notes
The Core layer is a stability layer.

It exists to reduce duplication and guarantee consistency.

## Future Direction
Future versions may expand the Core layer with:
- persistent state snapshots
- advanced validation policies
- richer execution orchestration helpers
- localization-ready shared services