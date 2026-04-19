# Git Workflow

## Purpose
Define how development must be handled using Git.

---

## Branch Strategy

### main
Stable version

### dev
Active development

### feature/*
Feature-specific work

---

## Workflow

1. Create feature branch
2. Implement change
3. Commit locally
4. Push branch
5. Open Pull Request
6. Merge into dev
7. Eventually merge dev into main

---

## Commit Messages

### Format
Short, clear, descriptive

### Examples
- Add system module structure
- Implement network analysis plan
- Refactor core logging structure

---

## Rules

### Rule 1
Do not commit directly to main.

### Rule 2
Use dev for integration.

### Rule 3
Use feature branches for new work.

### Rule 4
Keep commits small and focused.

---

## Tags

Use tags for versions:

- v0.1.0
- v0.2.0

---

## V1 Notes
Focus on structure and clarity, not perfect Git flow.