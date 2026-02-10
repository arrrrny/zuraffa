---
title: "[PLUGIN] Create ControllerPlugin (VPC)"
phase: "Migration"
priority: "High"
estimated_hours: 16
labels: plugin, vpc, controller, migration
dependencies: [PLUGIN] Create PresenterPlugin, [PLUGIN] Create ViewPlugin
---

## 📋 Task Overview

**Phase:** Migration
**Priority:** High
**Estimated Hours:** 16
**Dependencies:** [PLUGIN] Create PresenterPlugin, [PLUGIN] Create ViewPlugin

## 📝 Description

Extract Controller generation into standalone plugin. Generates {entity}_controller.dart with state management and CancelToken handling.

## ✅ Acceptance Criteria

- [ ] ControllerPlugin generates controllers using code_builder
- [ ] Supports both basic and stateful controllers
- [ ] Proper CancelToken handling
- [ ] Integrates with PresenterPlugin

## 📁 Files

### To Create
- `lib/src/plugins/controller/controller_plugin.dart`
- `lib/src/plugins/controller/builders/controller_class_builder.dart`
- `lib/src/plugins/controller/builders/stateful_controller_builder.dart`
- `test/plugins/controller/controller_plugin_test.dart`

### To Modify


## 🧪 Testing Requirements



## 💬 Notes


