---
title: "[PLUGIN] Create DIPlugin"
phase: "Migration"
priority: "Medium"
estimated_hours: 12
labels: plugin, di, migration
dependencies: [PLUGIN] Migrate RepositoryGenerator, [AST] Implement Smart Append Strategy
---

## 📋 Task Overview

**Phase:** Migration
**Priority:** Medium
**Estimated Hours:** 12
**Dependencies:** [PLUGIN] Migrate RepositoryGenerator, [AST] Implement Smart Append Strategy

## 📝 Description

Create DI generation plugin for dependency injection. Generates lib/src/di/index.dart and lib/src/di/injection.dart with get_it registrations.

## ✅ Acceptance Criteria

- [ ] DIPlugin generates registration files using code_builder
- [ ] Detects what needs registration automatically
- [ ] Updates existing files via AST
- [ ] Supports --use-mock flag

## 📁 Files

### To Create
- `lib/src/plugins/di/di_plugin.dart`
- `lib/src/plugins/di/builders/registration_builder.dart`
- `lib/src/plugins/di/detectors/registration_detector.dart`
- `test/plugins/di/di_plugin_test.dart`

### To Modify


## 🧪 Testing Requirements

Test registration generation, AST-based file update, and mock vs real registration.

## 💬 Notes


