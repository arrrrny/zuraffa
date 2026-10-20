# Zuraffa Documentation

## TDD Workflow

- [ZFA TDD Cycle — External Agent Guideline](zfa-tdd-guide.md) - From zero to a completed engine+skin TDD cycle: setup, spec authoring, plan, run, verify, misfire protocol

## Architecture

- [Writing Zuraffa Packages](writing_zuraffa_packages.md) - Greenfield guide: create, generate, consume, and publish zuraffa-native packages and federated plugins
- [Package Migration Guide](package_migration_guide.md) - Brownfield playbook: convert an existing Dart/Flutter package into a zuraffa package or federated plugin, rebuilt test-first (automated by the `zuraffa-migrate` speckit extension)
- [Offline-First Sync Plugin](architecture/offline-first-sync.md) - Local-first persistence with background synchronization

## Integrations

- [VM Service API Bridge](integrations/vm-service-api-bridge.md) - Auto-generated debug RPC bridge for all UseCases via `dart:developer.registerExtension`
- [API Plugin Development & Testing](integrations/api-plugin-testing.md) - How to develop, test, and debug the VM Service API plugin across platforms

---

_Documentation auto-generated and maintained by the `/docs` skill_
_Last updated: 2026-07-09_
