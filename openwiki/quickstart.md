# Zuraffa Quickstart

**Zuraffa** is an AI-first Clean Architecture framework and CLI for Flutter. It generates complete, type-safe feature layers — domain, data, presentation, dependency injection, caching, testing, and more — from simple CLI commands.

- **Version:** 5.3.0 (v5)
- **Language:** Dart 3.11+ / Flutter 3.41+
- **Package:** [pub.dev/packages/zuraffa](https://pub.dev/packages/zuraffa)
- **Repository:** [github.com/arrrrny/zuraffa](https://github.com/arrrrny/zuraffa)
- **CLI executables:** `zuraffa`, `zfa`, `zuraffa_mcp_server`

## Table of Contents

- [Quickstart](#quickstart)
- [Architecture Overview](architecture.md)
- [CLI Reference](cli.md)
- [Domain Layer](domain-layer.md)
- [Presentation Layer](presentation-layer.md)
- [Data & DI Layer](data-layer.md)
- [Testing](testing.md)

## What Zuraffa Does

Zuraffa generates production-ready Flutter code following Clean Architecture principles:

| What | How |
|---|---|
| Entities | Zorphy-annotated immutable entities under `lib/src/domain/entities/` |
| Use Cases | Business logic operations returning `Result<T, AppFailure>` |
| Repositories | Domain repository interfaces + data implementations |
| Data Sources | Remote (HTTP) and local (Hive) data access |
| Presentation | Controllers (ChangeNotifier/Provider), Views, optional Presenters |
| Navigation | GoRouter route constants and builders |
| DI | `get_it` service locator registrations |
| Caching | Dual DataSource pattern with pluggable policies (daily, restart, TTL) |
| Offline Sync | Push-only and bidirectional sync metadata and strategies |
| Tests | Unit tests for all generated layers |
| Mocks | Mock data providers and test helpers |

## Canonical v5 Workflow

```
zfa entity create  →  zfa make  →  zfa build
```

### 1. Create an entity

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double \
  --field description:String?
```

Output: `lib/src/domain/entities/product/product.dart`

### 2. Generate architecture with `make`

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di \
  --test
```

This generates domain (usecases, repository), data (remote/local datasources), presentation (view, controller, presenter), DI registration, and test files.

### 3. Build generated code

```bash
zfa build
```

Runs `build_runner` under the hood to process Zorphy annotations and JSON serialization.

## Installation

```yaml
dependencies:
  zuraffa: ^5.0.0

dev_dependencies:
  zuraffa: ^5.0.0
  zorphy_annotation: ^1.7.0
  build_runner: ^2.4.0
```

Activate the CLI globally:

```bash
dart pub global activate zuraffa
```

## Key Source Layout

```
lib/src/
├── cli/                    # CLI runner, plugin loader
├── commands/               # ~30 CLI command implementations
├── config/                 # .zfa.json configuration
├── core/                   # Core types: Result, Failure, hooks, plugin system, planning, generation
├── domain/                 # UseCase base classes (UseCase, StreamUseCase, SyncUseCase, BackgroundUseCase)
├── extensions/             # Future extensions
├── generator/              # Top-level code generator
├── graphql/                # GraphQL schema translation & entity emission
├── models/                 # Generator config models, file metadata
├── plugins/                # 21 concrete generator plugins
├── presentation/           # Controller, View, Presenter, responsive/adaptive shells
├── utils/                  # Entity analysis, file utils, string utils, test utils
└── version.dart            # Version constant
```

## Next Steps

| Page | What You'll Find |
|---|---|
| [Architecture](architecture.md) | Plugin system, code generation pipeline, presets, aliases, plan resolution |
| [CLI Reference](cli.md) | All commands, configuration, MCP server, entity workflow |
| [Domain Layer](domain-layer.md) | UseCase hierarchy, Result type, Failure types, Hook system |
| [Presentation Layer](presentation-layer.md) | Controller (MVP/VM), View, Presenter, responsive/adaptive layouts |
| [Data & DI Layer](data-layer.md) | Repository pattern, Dual DataSource caching, get_it DI, offline sync |
| [Testing](testing.md) | Test structure, Result matchers, integration testing utilities |
| [Integrations](integrations.md) | MCP server, GraphQL, Zed extension, OpenTelemetry |
| [Operations](operations.md) | Configuration, debugging, CI/CD, caching, sync, migration |
| [Plugin Development](plugin-development.md) | Plugin API, lifecycle, capability system, development checklist |
| [TDD Declared Routing](tdd-declared-routing.md) | How `zfa tdd` routes behaviors from spec declarations (markers, contract traces), provenance, `--strict-routing` |

## Key References

- [CLI Guide](../CLI_GUIDE.md) — Complete CLI reference
- [Caching Guide](../CACHING.md) — Dual DataSource caching deep-dive
- [AI Agents Guide](../AGENTS.md) — v5 contract for AI agents
- [v4 vs v5 Comparison](../docs/v4_vs_v5_comparison.md) — Migration guide
- [Plugin API Reference](../doc/PLUGIN_API_REFERENCE.md) — For plugin developers
- [MCP Server Docs](../doc/MCP_SERVER.md) — MCP server integration
- [Roadmap](../doc/ROADMAP.md) — Planned features
