# Logging Standard

## Purpose
Define logging behavior across the application.

## Goals
- trace execution
- track repairs
- support troubleshooting
- support reporting

---

## Log Structure

Each log entry must include:

- timestamp
- source
- level
- message

---

## Log Levels

### INFO
General execution steps

### WARN
Non-critical issues

### ERROR
Failures that affect execution

### CRITICAL
Severe failures

---

## Example

[INFO] Starting System module  
[WARN] Low disk space detected  
[ERROR] DNS resolution failed  

---

## Logging Rules

### Rule 1
All modules must log their execution steps.

### Rule 2
All repair actions must be logged.

### Rule 3
Errors must include clear context.

### Rule 4
Logs must be readable by humans.

---

## Output Targets

Logs should be visible in:
- UI (live log)
- report output (optional)