# FixPC Toolkit

FixPC Toolkit is a modular PC diagnostic and repair project designed for IT support workflows.

## Overview

This project started as an evolution of an existing functional PowerShell WinForms tool:

- `PC-DiagRepair-GUI-V2.ps1`

The goal of FixPC Toolkit is to transform that working monolithic script into a structured, maintainable, and scalable toolkit with a clear internal architecture.

## Current Status

**V1 Alpha in progress**

Current focus:
- modular architecture
- WinForms operational flow
- System, Network, and Hardware modules
- structured reporting
- reusable application core

## Version Strategy

### V1
- WinForms
- focus on structure, stability, and modularization

### V2
- WPF
- planned future UI modernization
- no WPF implementation in the current alpha stage

## Implemented Areas

### Core
- shared contracts
- execution modes
- severity model
- logging foundation
- validation foundation
- workflow support

### Application
- bootstrap flow
- workflow coordination
- module routing
- result consolidation

### Modules
- System
- Network
- Hardware

### Reporting
- HTML
- TXT
- JSON

### UI
- WinForms V1 active
- WPF V2 planned only

## Architecture Principles

- UI must not contain business logic
- modules must not depend on UI
- reporting must not depend on UI controls
- App layer orchestrates execution
- Core layer provides shared services
- modules follow:
  - Collect
  - Analyze
  - Repair
  - Export

## Execution Modes

- `DiagnoseOnly`
- `SafeRepair`
- `FullRepair`

## Repository Structure

- `App/` application bootstrap and workflow orchestration
- `Core/` shared services, contracts, logging, validation, utilities
- `Modules/` System, Network, Hardware, and shared module patterns
- `Reports/` HTML, TXT, JSON reporting
- `UI.WinForms/` active V1 interface
- `UI.WPF/` planned V2 interface
- `Docs/` architecture, planning, roadmap, setup, and decisions
- `Tests/` validation and module test planning
- `Build/` packaging and release helpers
- `Assets/` visual and external support resources

## Documentation

The `Docs/` folder contains:
- architecture documents
- execution workflow
- module scopes
- implementation order
- reporting model
- V1 and V2 planning
- ADRs and development conventions

## Branch Strategy

- `main` = stable
- `dev` = active development
- `feature/*` = isolated work branches

## Current Goal

Reach a stable **V1 Alpha** with:
- operational WinForms flow
- consistent module result schema
- stable reporting
- modular implementation foundation for future growth

## Notes

This project is currently in active development and is not yet a final release.