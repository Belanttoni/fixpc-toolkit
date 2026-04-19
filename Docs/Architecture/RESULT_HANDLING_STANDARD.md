# Result Handling Standard

## Purpose
Define how results must be created, updated, and returned.

## Core Principle
All modules must return structured results.

---

## Required Structure

Each result must include:

- ModuleName
- Success
- Severity
- Findings
- Recommendations
- ActionsTaken
- Errors
- Warnings

---

## Result Rules

### Rule 1
Do not return raw text as final output.

### Rule 2
Always return structured data.

### Rule 3
Severity must reflect the overall state.

### Rule 4
ActionsTaken must reflect actual execution.

---

## Aggregation

The Application layer must:
- combine module results
- generate final summary
- pass structured data to reporting

---

## Anti-Patterns

Avoid:
- returning mixed data types
- inconsistent field names
- missing severity values