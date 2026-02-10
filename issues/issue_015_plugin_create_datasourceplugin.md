---
title: "[PLUGIN] Create DataSourcePlugin"
phase: "Migration"
priority: "Medium"
estimated_hours: 14
labels: plugin, datasource, migration
dependencies: [PLUGIN] Migrate RepositoryGenerator
---

## 📋 Task Overview

**Phase:** Migration
**Priority:** Medium
**Estimated Hours:** 14
**Dependencies:** [PLUGIN] Migrate RepositoryGenerator

## 📝 Description

Create DataSource generation plugin. Generates DataSource interface, RemoteDataSource, and LocalDataSource (if --cache). Integrates with Repository and GQL plugins.

## ✅ Acceptance Criteria

- [ ] DataSourcePlugin generates all datasource types using code_builder
- [ ] Integrates with RepositoryPlugin
- [ ] Supports GraphQL generation
- [ ] Supports local/remote split for caching

## 📁 Files

### To Create
- `lib/src/plugins/datasource/datasource_plugin.dart`
- `lib/src/plugins/datasource/generators/interface_generator.dart`
- `lib/src/plugins/datasource/generators/remote_generator.dart`
- `lib/src/plugins/datasource/generators/local_generator.dart`
- `test/plugins/datasource/datasource_plugin_test.dart`

### To Modify


## 🧪 Testing Requirements

Test interface, remote, and local implementations. Integration test with Repository and Cache.

## 💬 Notes


