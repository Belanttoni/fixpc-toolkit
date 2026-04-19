# Module Dependency Map

## Purpose
This document defines the dependency relationships between the main areas of FixPC Toolkit V1.

## Goal
Clarify which components depend on which layers so the project remains modular and maintainable.

## Dependency Philosophy
Dependencies should flow downward in a controlled way.

Higher-level layers may depend on lower-level layers.
Lower-level layers must not depend on higher-level layers.

## Main Layers

- UI Layer
- Application Layer
- Module Layer
- Core Layer
- Report Layer

## Dependency Map

### UI Layer
The UI layer may depend on:
- Application Layer
- shared display-ready results

The UI layer must not depend directly on:
- raw module internals
- low-level execution helpers
- report generation internals

---

### Application Layer
The Application layer may depend on:
- Core Layer
- Module Layer
- Report Layer

The Application layer is the orchestration layer.

It must not depend on:
- a specific UI implementation

---

### Module Layer
Modules may depend on:
- Core Layer
- shared contracts
- shared severity model
- shared execution mode model

Modules must not depend on:
- WinForms
- WPF
- other modules directly unless explicitly approved in future versions

---

### Core Layer
The Core layer must be dependency-light.

It should provide shared services used by:
- Application Layer
- Module Layer
- Report Layer

The Core layer must not depend on:
- UI
- module-specific logic

---

### Report Layer
The Report layer may depend on:
- consolidated result data
- Core shared contracts

The Report layer must not depend on:
- WinForms controls
- WPF controls
- module internal execution steps

## Module-to-Module Rules

### Rule 1
System, Network, and Hardware must not directly depend on each other in V1.

### Rule 2
Shared behaviors must be handled through the Core layer or shared contracts.

### Rule 3
Cross-module insights may be added only at the Application consolidation level.

## Conceptual Dependency Flow

UI
↓
Application
↓
Modules / Reports
↓
Core

## Approved Relationships

### UI → Application
Allowed

### Application → Core
Allowed

### Application → Modules
Allowed

### Application → Reports
Allowed

### Modules → Core
Allowed

### Reports → Core
Allowed

## Disallowed Relationships

### Core → UI
Not allowed

### Core → Modules
Not allowed

### Modules → UI
Not allowed

### Reports → UI
Not allowed

### System → Network
Not allowed in V1

### Network → Hardware
Not allowed in V1

### Hardware → System
Not allowed in V1

## V1 Notes
This dependency structure exists to:
- reduce coupling
- support WinForms V1
- preserve reuse for WPF V2
- simplify future maintenance

## Future Direction
Future versions may allow richer coordination patterns, but only through controlled orchestration layers.