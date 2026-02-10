---
title: "[CORE] Create Shared Generation Context"
phase: "Foundation"
priority: "Critical"
estimated_hours: 6
labels: core, context, foundation, critical
dependencies: None
---

## 📋 Task Overview

**Phase:** Foundation
**Priority:** Critical
**Estimated Hours:** 6
**Dependencies:** None

## 📝 Description

Build GenerationContext - shared state passed to all plugins during generation. Enables plugins to share information and access configuration.

## ✅ Acceptance Criteria

- [ ] GenerationContext contains GeneratorConfig
- [ ] Context provides file system abstraction
- [ ] Plugins can share data via context.store
- [ ] Progress reporting hooks for CLI/UI

## 📁 Files

### To Create
- `lib/src/core/context/generation_context.dart`
- `lib/src/core/context/context_store.dart`
- `lib/src/core/context/progress_reporter.dart`
- `test/core/context/generation_context_test.dart`

### To Modify


## 🧪 Testing Requirements

Test context sharing and config access.

## 💬 Notes


