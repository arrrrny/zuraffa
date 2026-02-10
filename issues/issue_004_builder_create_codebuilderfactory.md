---
title: "[BUILDER] Create CodeBuilderFactory"
phase: "Code Builder"
priority: "Critical"
estimated_hours: 16
labels: core, code-builder, foundation, critical
dependencies: None
---

## 📋 Task Overview

**Phase:** Code Builder
**Priority:** Critical
**Estimated Hours:** 16
**Dependencies:** None

## 📝 Description

Central factory for creating code_builder Spec objects. Replaces all string-based code generation with type-safe builders.

## ✅ Acceptance Criteria

- [ ] All factory methods return code_builder Spec objects
- [ ] Generated code is properly formatted
- [ ] Factory handles all variations (entity vs custom usecases)
- [ ] Comprehensive unit tests for each factory method

## 📁 Files

### To Create
- `lib/src/core/builder/code_builder_factory.dart`
- `lib/src/core/builder/factories/usecase_factory.dart`
- `lib/src/core/builder/factories/repository_factory.dart`
- `lib/src/core/builder/factories/vpc_factory.dart`
- `lib/src/core/builder/factories/route_factory.dart`
- `lib/src/core/builder/shared/spec_library.dart`
- `test/core/builder/code_builder_factory_test.dart`

### To Modify


## 🧪 Testing Requirements

Test each factory method generates valid Dart code.

## 💬 Notes

Most time-consuming but highest quality improvement.
