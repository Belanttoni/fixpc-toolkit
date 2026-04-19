# Reporting Model

## Purpose
This document defines the reporting model for FixPC Toolkit V1.

## Goal
Provide a consistent and reusable reporting structure for all module results and final execution summaries.

## Reporting Principles
Reports must be:
- structured
- readable
- technology-independent
- based on consolidated module results
- usable by support technicians

## Planned Output Formats
V1 supports the following report formats:

- HTML
- TXT
- JSON

## Reporting Levels

### 1. Module-Level Reporting
Each module must provide report-friendly output that includes:
- module name
- severity
- findings
- recommendations
- actions taken
- relevant summary data

### 2. Consolidated Reporting
The final application report must combine all selected module results into one summary.

It should include:
- execution metadata
- selected modules
- execution mode
- start and end time
- total duration
- module summaries
- final recommendations
- overall status overview

## Standard Final Report Sections

### 1. Header
The header should include:
- application name
- machine identity
- current user
- execution mode
- execution timestamp

### 2. Execution Summary
This section should include:
- selected modules
- total execution time
- number of warnings
- number of errors
- overall severity

### 3. Module Sections
Each selected module should have its own section.

Each section should show:
- module summary
- severity
- findings
- recommendations
- actions taken
- notable warnings or errors

### 4. Final Recommendations
The final report should include an overall recommendation area summarizing the most important next steps.

## Format-Specific Notes

### HTML
HTML is the primary human-readable output for V1.

It should support:
- structured sections
- status highlighting
- readable formatting
- technician-friendly presentation

### TXT
TXT is a simplified plain-text output.

It should support:
- portability
- quick reading
- easy copy/paste into tickets or notes

### JSON
JSON is the structured output format.

It should support:
- future integrations
- machine-readable storage
- comparison and automation scenarios in future versions

## Reporting Rules

### Rule 1
Reports must be generated from consolidated result data.

### Rule 2
Reports must not depend on WinForms controls or UI state.

### Rule 3
All modules must map to the same reporting model.

### Rule 4
Severity must be preserved in exported results.

### Rule 5
Actions taken must always be visible in reports when repairs were executed.

## V1 Notes
The reporting model is part of the reusable application core and must remain valid for WPF V2.

## Future Direction
Future versions may expand reporting with:
- historical comparisons
- richer visual summaries
- issue grouping by priority
- export templates for service desk workflows