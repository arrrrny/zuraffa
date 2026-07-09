# Architecture

Zuraffa is a **code generation framework** built on a flexible plugin system. It generates Clean Architecture code for Flutter applications through a pipeline that resolves presets, aliases, and plugin capabilities into a deterministic generation plan.

## Clean Architecture Structure

Generated code follows a strict layer separation:

```
lib/src/
├── domain/                    # Enterprise business rules
│   ├── entities/              # Zorphy-annotated immutable models
│   ├── repositories/          # Abstract repository interfaces
│   ├── services/              # Domain service interfaces
│   └── usecases/              # Application-specific business logic
├── data/                      # Data layer implementations
│   ├── datasources/           # Remote (HTTP) + Local (Hive) data sources
│   └── repositories/          # Repository implementations
├── presentation/              # Flutter UI layer
│   ├── controllers/           # Stateful controllers (ChangeNotifier)
│   ├── presenters/            # Optional orchestration layer
│   ├── views/                 # CleanView widgets
│   └── states/                # UI state classes
├── di/                        # get_it registration files
├── routes/                    # GoRouter route definitions
├── mocks/                     # Mock data providers
└── cache/                     # Hive cache setup
```

## Plugin System

### Core Concepts

The plugin system lives in `lib/src/core/plugin_system/` and `lib/src/plugins/`.

**Plugin lifecycle** (defined in `plugin_interface.dart`):
1. `validate(context)` — Pre-generation validation
2. `beforeGenerate(context)` — Pre-generation setup
3. `generateWithContext(context)` — File generation (main work)
4. `afterGenerate(context)` — Post-generation cleanup
5. `onError(context, error, stack)` — Error handling

**Two plugin types:**
- `ZuraffaPlugin` — Base interface with lifecycle hooks
- `FileGeneratorPlugin` — Extends `ZuraffaPlugin` for file generation; provides both `generateWithContext()` (modern) and `generate()` (legacy bridge)

**Dependency ordering** (`plugin_registry.dart`):
- `dependsOn` — Hard requirement; the dependency must be active
- `runAfter` — Soft ordering; runs after if the other is active
- The registry performs topological sort with cycle detection

### 21 Built-in Plugins

| Plugin ID | Generated Output | Key File |
|---|---|---|
| `repository` | Repository interface + implementation | `plugins/repository/repository_plugin.dart` |
| `datasource` | Remote/local data sources | `plugins/datasource/datasource_plugin.dart` |
| `usecase` | Use case classes | `plugins/usecase/usecase_plugin.dart` |
| `service` | Service interfaces | `plugins/service/service_plugin.dart` |
| `provider` | Data providers | `plugins/provider/provider_plugin.dart` |
| `controller` | Presentation controllers | `plugins/controller/controller_plugin.dart` |
| `presenter` | Presenter classes | `plugins/presenter/presenter_plugin.dart` |
| `view` | Flutter view widgets | `plugins/view/view_plugin.dart` |
| `state` | UI state classes | `plugins/state/state_plugin.dart` |
| `observer` | State observers | `plugins/observer/observer_plugin.dart` |
| `route` | GoRouter route constants | `plugins/route/route_plugin.dart` |
| `di` | get_it DI registrations | `plugins/di/di_plugin.dart` |
| `test` | Unit tests | `plugins/test/test_plugin.dart` |
| `mock` | Mock data providers | `plugins/mock/mock_plugin.dart` |
| `cache` | Hive cache initialization | `plugins/cache/cache_plugin.dart` |
| `sync` | Offline-first sync metadata | `plugins/sync/sync_plugin.dart` |
| `gql` | Internal GraphQL strings | `plugins/gql/gql_plugin.dart` |
| `graphql` | Schema-first GraphQL Dart | `plugins/graphql/graphql_plugin.dart` |
| `feature` | Feature scaffolding coordinator | `plugins/feature/feature_plugin.dart` |
| `method_append` | Method appending to existing classes | `plugins/method_append/method_append_plugin.dart` |
| `shadcn` | Shadcn-style UI components | `plugins/shadcn/shadcn_plugin.dart` |

> **For detailed plugin development**: see the [Plugin Development](plugin-development.md) guide.

### Capability System

Each plugin exposes `ZuraffaCapability` objects — a structured interface for AI/CLI interrogation:

```dart
class ZuraffaCapability {
  final String name;
  final String description;
  final Map inputSchema;   // JSON Schema for input
  final Map outputSchema;  // JSON Schema for output
  EffectReport plan(args);           // "What will this do?"
  ExecutionResult execute(args);     // "Do it"
}
```

This enables `--plan` / `--explain` flags that show the normalized plan before writing files.

## Code Generation Pipeline

### Flow: CLI Command to Generated Files

```
zfa make Product --preset=crud --with=vpc
  │
  ├─ 1. CliRunner.run(args)
  │     Loads all 21 plugins via PluginLoader.buildRegistry()
  │     Registers core commands + CliAwarePlugin commands
  │
  ├─ 2. MakeCommand.run()
  │     Parses args (entity name, presets, flags, --with/--without)
  │     Loads optional JSON config (--from-json / --from-stdin)
  │     Resolves the plan via PluginManager.resolvePlan()
  │
  ├─ 3. PlanResolver.resolve()
  │     a. Expand preset (crud → [usecase, repository, datasource, ...])
  │     b. Merge explicit plugin IDs from positional args
  │     c. Apply --with / --without flags
  │     d. Expand aliases (vpc → [view, presenter, controller])
  │     e. Apply --no-<plugin> flag muting
  │     f. Remove disabled plugins from config
  │     g. Sort by dependency order (topological)
  │     h. Return GenerationPlan{ activePlugins, warnings }
  │
  ├─ 4. PluginManager.buildContext()
  │     Creates PluginContext with CoreConfig, merged plugin options, DiscoveryEngine
  │
  ├─ 5. PluginManager.run(context, activePlugins)
  │      a. If --revert: load PlanStore and undo
  │      b. Validate all plugins
  │      c. Run beforeGenerate hooks
  │      d. For each sorted plugin: generateWithContext() → staged file writes
  │      e. On error: run onError hooks
  │      f. Commit transactional file system (atomic write)
  │      g. Run afterGenerate hooks
  │
  └─ 6. Persist EffectReport to PlanStore (for revert)
```

### Key files in the pipeline

| File | Role |
|---|---|
| `lib/src/cli/cli_runner.dart` | Top-level CLI dispatcher; discovers plugins, registers commands |
| `lib/src/cli/plugin_loader.dart` | Instantiates all 21 plugins |
| `lib/src/commands/make_command.dart` | `zfa make` command: arg parsing, plan resolution, execution |
| `lib/src/core/planning/plan_resolver.dart` | Resolves presets/aliases/flags into a sorted `GenerationPlan` |
| `lib/src/core/planning/generation_plan.dart` | Immutable plan model |
| `lib/src/core/planning/preset_registry.dart` | Named preset definitions |
| `lib/src/core/planning/plugin_alias_resolver.dart` | Alias expansion (vpc, data, quality, etc.) |
| `lib/src/core/plugin_system/plugin_manager.dart` | Orchestrates lifecycle, context building, plan persistence |
| `lib/src/core/plugin_system/plugin_registry.dart` | Singleton registry with topological sort |
| `lib/src/core/generation/generation_context.dart` | Session state: config, file system, context store |
| `lib/src/core/generation/code_builder_factory.dart` | Factory for typed code builders |

## Transactional File System

All file writes go through `GenerationTransaction` / `TransactionalFileSystem`:

- Files are staged in memory during generation
- Committed atomically at the end of `PluginManager.run()`
- On failure, all changes are discarded
- `DiscoveryEngine` checks pending operations before disk reads
- `PlanStore` persists `EffectReport` for `--revert` (deletes created files, restores previous content)

## Presets and Aliases

### Presets (expand to plugin lists)

| Preset | Plugins |
|---|---|
| `crud` | usecase, repository, datasource, service |
| `feature` | usecase, repository, datasource, service, view, presenter, controller, state, route, di, test |
| `vpc` | view, presenter, controller |
| `read-only` | usecase (get, getList only), repository, datasource |
| `full-stack` | All available plugins |
| `data-layer` | repository, datasource |

### Aliases (shorthand)

| Alias | Expanded |
|---|---|
| `data` | repository, datasource |
| `vpc` | view, presenter, controller |
| `full-ui` | view, presenter, controller, state, route |
| `quality` | test, mock, di |

Custom presets and aliases can be defined in `.zfa.json`.

## Key Architectural Decisions

1. **Code generation over runtime reflection** — DI, routing, and serialization glue is generated at build time, not discovered at runtime.
2. **Plugin-based architecture** — Each generation target is a self-contained plugin with lifecycle hooks, making the system extensible without modifying core code.
3. **Deterministic output** — Given the same inputs, `zfa make` produces identical output every time (no randomness, no AI-generated variability).
4. **Atomic file writes** — The transactional file system ensures partial generations don't leave corrupted state.
5. **Revert support** — Every generation run persists a plan that can be undone.
6. **Dual plugin API** — The modern `generateWithContext(PluginContext)` coexists with legacy `generate(GeneratorConfig)` for backward compatibility.

## Source Map

```
lib/src/core/plugin_system/
├── plugin_interface.dart       # ZuraffaPlugin, FileGeneratorPlugin base classes
├── plugin_manager.dart         # Lifecycle orchestration, plan persistence
├── plugin_registry.dart        # Singleton registry, sort, dependency checking
├── plugin_context.dart         # Shared context object
├── capability.dart             # ZuraffaCapability, Effect, EffectReport
├── cli_aware_plugin.dart       # Mixin for plugins with CLI subcommands
├── discovery_engine.dart       # Glob-based file finder
├── plan_store.dart             # Persisted execution plans for revert
├── presets.dart                 # Built-in preset definitions
├── plugin_lifecycle.dart       # Lifecycle stages, validation results
└── ... (config, filter, etc.)

lib/src/core/planning/
├── plan_resolver.dart          # CLI args → GenerationPlan resolution
├── generation_plan.dart        # Immutable plan model
├── preset_registry.dart        # Named presets storage
└── plugin_alias_resolver.dart  # Shorthand alias expansion

lib/src/core/generation/
├── generation_context.dart     # Session state
└── code_builder_factory.dart   # Typed builder factory
```
