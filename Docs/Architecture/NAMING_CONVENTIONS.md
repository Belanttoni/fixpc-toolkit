# Naming Conventions

## Purpose
Define consistent naming standards across the FixPC Toolkit project.

## General Principles
- Names must be clear and descriptive
- Avoid abbreviations unless widely understood
- Use consistent patterns across modules

## PowerShell Function Naming

### Format
Verb-Noun

### Examples
- Get-SystemInfo
- Invoke-SystemScan
- Start-NetworkAnalysis
- Repair-SystemIntegrity

### Rules
- Use approved verbs when possible
- Use PascalCase
- Avoid generic names like "Run", "Do", "Process"

---

## Variable Naming

### Format
camelCase

### Examples
- systemData
- moduleResult
- executionMode

---

## Module Naming

### Format
PascalCase

### Examples
- System
- Network
- Hardware

---

## File Naming

### Format
Module.Action.ps1

### Examples
- System.Collect.ps1
- System.Analyze.ps1
- System.Repair.ps1
- System.Export.ps1

---

## Folder Naming

### Format
PascalCase

### Examples
- Core
- Modules
- Reports
- UI.WinForms
- UI.WPF

---

## Constants and Enums

### Format
UPPER_CASE

### Examples
- EXECUTION_MODE_DIAGNOSE
- SEVERITY_WARN

---

## Logging Labels

### Format
UPPER_CASE

### Examples
- INFO
- WARN
- ERROR
- CRITICAL

---

## Rule Summary

### Rule 1
Consistency is more important than preference.

### Rule 2
Names must reflect purpose clearly.

### Rule 3
Avoid mixing naming styles within the same context.