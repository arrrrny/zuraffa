---
title: "[PLUGIN] Enhance RoutePlugin with code_builder"
phase: "Migration"
priority: "Medium"
estimated_hours: 10
labels: plugin, route, refactoring
dependencies: [BUILDER] Create CodeBuilderFactory, [AST] Implement Smart Append Strategy
---

## 📋 Task Overview

**Phase:** Migration
**Priority:** Medium
**Estimated Hours:** 10
**Dependencies:** [BUILDER] Create CodeBuilderFactory, [AST] Implement Smart Append Strategy

## 📝 Description

RoutePlugin was recently created but uses string generation. Migrate to code_builder for consistency. Convert AppRoutes updates to use AST.

## ✅ Acceptance Criteria

- [ ] RoutePlugin uses code_builder exclusively
- [ ] AppRoutes updates use AST
- [ ] All current functionality preserved
- [ ] Better error handling

## 📁 Files

### To Create
- `lib/src/plugins/route/builders/app_routes_builder.dart`
- `lib/src/plugins/route/builders/entity_routes_builder.dart`
- `lib/src/plugins/route/builders/extension_builder.dart`

### To Modify
- `lib/src/generator/route_generator.dart`

## 🧪 Testing Requirements

Test route spec generation and AST-based AppRoutes update.

## 💬 Notes


