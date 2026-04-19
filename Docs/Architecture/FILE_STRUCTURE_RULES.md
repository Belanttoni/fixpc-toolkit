# File Structure Rules

## Purpose
Define how files and folders must be organized.

## Core Rule
Each module must follow the same internal structure.

---

## Module Structure

Modules must follow:

- Collect
- Analyze
- Repair
- Export

Example:

Modules/System/
- Collect/
- Analyze/
- Repair/
- Export/

---

## File Rules

### Rule 1
One responsibility per file.

### Rule 2
Do not mix Collect, Analyze, and Repair logic.

### Rule 3
Keep files small and focused.

---

## Core Layer Rules

Core must be divided into:

- Logging
- State
- Validation
- Utilities
- Execution
- Contracts

---

## UI Rules

UI must not contain:
- business logic
- module execution logic

UI should only:
- display data
- trigger workflows

---

## Reports Rules

Reports must:
- be independent from UI
- use structured data only

---

## Folder Consistency

All modules must follow the same structure.

---

## Anti-Patterns

Avoid:
- monolithic scripts
- mixed responsibilities
- direct UI-to-module coupling