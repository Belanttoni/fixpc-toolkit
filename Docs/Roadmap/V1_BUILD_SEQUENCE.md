# V1 Build Sequence

## Purpose
This document defines the practical build sequence for FixPC Toolkit V1.

## Goal
Translate architecture and planning into an ordered implementation path.

## Build Strategy
V1 should be built incrementally, validating one stable layer at a time.

## Build Sequence

### Step 1 - Repository and Documentation Baseline
Deliverables:
- repository structure
- README
- architecture documents
- planning documents
- roadmap documents
- ADRs

Status:
- expected to be completed first

---

### Step 2 - Shared Contracts
Deliverables:
- severity vocabulary
- execution mode definitions
- module result schema
- shared expectations for findings, recommendations, and actions taken

Outcome:
- all modules share one common language

---

### Step 3 - Core Foundation
Deliverables:
- state design
- logging design
- validation design
- utility design
- execution support design

Outcome:
- reusable foundation for all modules and workflows

---

### Step 4 - Application Workflow Foundation
Deliverables:
- bootstrap model
- workflow coordinator
- execution context
- result consolidation design

Outcome:
- one central path for all execution behavior

---

### Step 5 - System Module Build
Deliverables:
- collect implementation plan
- analyze implementation plan
- repair implementation plan
- export implementation plan

Outcome:
- first complete reference module

---

### Step 6 - Reporting Foundation
Deliverables:
- module-level reporting model
- consolidated reporting model
- HTML/TXT/JSON structure

Outcome:
- output pipeline becomes stable early

---

### Step 7 - Network Module Build
Deliverables:
- layered network collection plan
- failure analysis plan
- repair plan
- export plan

Outcome:
- second complete module following the System pattern

---

### Step 8 - Hardware Module Build
Deliverables:
- identity collection plan
- advisory analysis plan
- export plan

Outcome:
- third complete module aligned to V1 structure

---

### Step 9 - WinForms UI Integration
Deliverables:
- main screen
- execution mode controls
- module status area
- progress area
- live log area
- final summary area

Outcome:
- V1 becomes operational through the planned interface

---

### Step 10 - V1 Consolidation
Deliverables:
- flow consistency review
- module consistency review
- report consistency review
- acceptance criteria review

Outcome:
- V1 becomes structurally ready for real implementation stabilization

## Build Rules

### Rule 1
Build shared foundations before UI integration.

### Rule 2
Stabilize the System module before using it as a reference for other modules.

### Rule 3
Keep reporting independent from WinForms.

### Rule 4
Validate consistency at each step before moving forward.

## Milestone Alignment

### Milestone 1
Foundation complete

### Milestone 2
System reference module complete

### Milestone 3
Network and Hardware planning aligned

### Milestone 4
WinForms V1 operational structure complete

### Milestone 5
V1 architecture ready for implementation work

## V1 Notes
This build sequence is intended to reduce architectural rework and preserve compatibility with future WPF V2 migration.