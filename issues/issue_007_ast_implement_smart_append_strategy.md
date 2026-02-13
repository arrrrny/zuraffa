---
title: "[AST] Implement Smart Append Strategy"
phase: "AST Integration"
priority: "High"
estimated_hours: 14
labels: core, ast, integration, smart-append
dependencies: None
---

## 📋 Task Overview

**Phase:** AST Integration
**Priority:** High
**Estimated Hours:** 14
**Dependencies:** None

## 📝 Description

Build intelligent file modification system using AST instead of fragile regex. Can check if method exists before adding, preserves formatting and comments.

## ✅ Acceptance Criteria

- [ ] Can append methods to existing classes
- [ ] Detects duplicates (same name + signature)
- [ ] Preserves existing code formatting
- [ ] Preserves comments and documentation

## 📁 Files

### To Create
- `lib/src/core/ast/strategies/append_strategy.dart`
- `lib/src/core/ast/strategies/method_append_strategy.dart`
- `lib/src/core/ast/strategies/export_append_strategy.dart`
- `lib/src/core/ast/append_executor.dart`
- `test/core/ast/append_strategy_test.dart`

### To Modify


## 🧪 Testing Requirements

Test append, duplicate detection, and preservation.

## 💬 Notes


