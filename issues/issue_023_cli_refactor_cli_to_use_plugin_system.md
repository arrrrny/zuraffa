---
title: "[CLI] Refactor CLI to Use Plugin System"
phase: "Integration"
priority: "High"
estimated_hours: 12
labels: cli, integration
dependencies: [CORE] Create Plugin Interface, [CORE] Create Shared Generation Context
---

## 📋 Task Overview

**Phase:** Integration
**Priority:** High
**Estimated Hours:** 12
**Dependencies:** [CORE] Create Plugin Interface, [CORE] Create Shared Generation Context

## 📝 Description

Update CLI commands to work with new plugin architecture. Generate command loads and runs plugins. New plugin command to list/enable/disable plugins. Better error messages and progress reporting.

## ✅ Acceptance Criteria

- [ ] generate command uses plugin registry
- [ ] plugin command works (list, enable, disable)
- [ ] Progress shown during generation
- [ ] Clear error messages when plugins fail
- [ ] Backward compatible (existing flags work)

## 📁 Files

### To Create
- `lib/src/commands/plugin_command.dart`
- `lib/src/cli/plugin_loader.dart`
- `lib/src/cli/progress_reporter.dart`

### To Modify
- `lib/src/commands/generate_command.dart`
- `bin/zfa.dart`

## 🧪 Testing Requirements

CLI argument parsing, full workflow, and error handling tests.

## 💬 Notes


