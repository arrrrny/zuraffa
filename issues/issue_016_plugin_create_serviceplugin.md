---
title: "[PLUGIN] Create ServicePlugin"
phase: "Migration"
priority: "Low"
estimated_hours: 10
labels: plugin, service, migration
dependencies: [PLUGIN] Migrate UseCaseGenerator
---

## 📋 Task Overview

**Phase:** Migration
**Priority:** Low
**Estimated Hours:** 10
**Dependencies:** [PLUGIN] Migrate UseCaseGenerator

## 📝 Description

Create Service generation plugin for custom usecases. Generates Service interface and provider when using --service flag with custom usecases.

## ✅ Acceptance Criteria

- [ ] ServicePlugin generates service interfaces using code_builder
- [ ] Integrates with custom usecase generation
- [ ] Proper dependency injection

## 📁 Files

### To Create
- `lib/src/plugins/service/service_plugin.dart`
- `lib/src/plugins/service/builders/service_interface_builder.dart`
- `test/plugins/service/service_plugin_test.dart`

### To Modify


## 🧪 Testing Requirements

Test service interface generation and integration with custom usecase.

## 💬 Notes


