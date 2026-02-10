---
title: "[PLUGIN] Migrate UseCaseGenerator to UseCasePlugin"
phase: "Migration"
priority: "High"
estimated_hours: 20
labels: plugin, usecase, migration
dependencies: [CORE] Create Plugin Interface, [BUILDER] Create CodeBuilderFactory
---

## 📋 Task Overview

**Phase:** Migration
**Priority:** High
**Estimated Hours:** 20
**Dependencies:** [CORE] Create Plugin Interface, [BUILDER] Create CodeBuilderFactory

## 📝 Description

Migrate the monolithic UseCaseGenerator to plugin architecture. Split into sub-generators for each usecase type. Use code_builder instead of strings.

## ✅ Acceptance Criteria

- [ ] UseCasePlugin implements ZuraffaPlugin interface
- [ ] All current usecase types generate correctly
- [ ] Uses code_builder instead of strings
- [ ] Supports smart append mode
- [ ] 100% test coverage

## 📁 Files

### To Create
- `lib/src/plugins/usecase/usecase_plugin.dart`
- `lib/src/plugins/usecase/generators/entity_usecase_generator.dart`
- `lib/src/plugins/usecase/generators/custom_usecase_generator.dart`
- `lib/src/plugins/usecase/generators/stream_usecase_generator.dart`
- `lib/src/plugins/usecase/builders/usecase_class_builder.dart`
- `test/plugins/usecase/usecase_plugin_test.dart`

### To Modify
- `lib/src/generator/code_generator.dart (remove usecase calls)`

## 🧪 Testing Requirements

Test all usecase types generate correctly.

## 💬 Notes

Pilot plugin - get this right and others follow the pattern.
