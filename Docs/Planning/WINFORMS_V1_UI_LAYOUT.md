# WinForms V1 UI Layout

## Purpose
This document defines the intended interface layout for FixPC Toolkit Version 1.

## Goal
Provide a structured and professional WinForms interface that supports the V1 workflow.

## UI Identity
WinForms V1 is a functional and structured interface focused on:
- clarity
- operational efficiency
- live execution visibility
- report access

It is not intended to be the final visual form of the product.

## Main Layout Sections

### 1. Header Area
The header should display:
- application name
- current machine identity
- current user
- execution mode
- optional summary indicators

### 2. Module Status Area
This area should show:
- module name
- description
- current status
- execution time
- severity when finished

Planned modules:
- System
- Network
- Hardware

### 3. Execution Controls Area
This area should provide:
- module selection
- execution mode selection
- run button
- report access button
- exit button

### 4. Progress Area
This area should show:
- progress bar
- current step text
- optional active module indicator

### 5. Live Log Area
This area should show:
- execution logs
- repair logs
- warnings
- failures
- completion messages

### 6. Final Summary Area
This area should show:
- overall result summary
- number of warnings
- number of errors
- report availability
- next-step recommendations

## UI Design Rules

### Rule 1
The UI must not contain business logic.

### Rule 2
The UI must only display data received from the Application layer.

### Rule 3
The UI must support DiagnoseOnly, SafeRepair, and FullRepair modes clearly.

### Rule 4
The UI must make module progress visible in real time.

### Rule 5
The UI must support future migration to WPF by keeping layout concepts stable.

## Recommended Visual Structure

### Top
Header + system identity

### Middle
Module grid + execution controls

### Bottom
Live log + final summary

## V1 Notes
WinForms V1 should prioritize:
- readability
- stability
- operational usefulness

A more modern and refined visual experience is planned for WPF V2.