---
title: "[CLEANUP] Remove Legacy Code"
phase: "Polish"
priority: "Low"
estimated_hours: 6
labels: cleanup, debt
dependencies: All plugin migrations complete, Regression tests pass
---

## 📋 Task Overview

**Phase:** Polish
**Priority:** Low
**Estimated Hours:** 6
**Dependencies:** All plugin migrations complete, Regression tests pass

## 📝 Description

Clean up old generators after migration. Remove lib/src/generator/*.dart files, duplicate logic, unused imports. Only do when 100% sure plugins work.

## ✅ Acceptance Criteria

- [ ] Old generator files removed
- [ ] No dead code remaining
- [ ] All tests still pass
- [ ] Code coverage maintained

## 📁 Files

### To Create


### To Modify
- `lib/src/generator/code_generator.dart`

## 🧪 Testing Requirements

Full test suite passes and no imports to deleted files.

## 💬 Notes

Only do this when 100% sure plugins work.
