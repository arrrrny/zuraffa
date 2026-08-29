# Implementation Plan: v6 Package SDK

**Branch**: `025-v6-package-sdk` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

## Summary

Deliver the v6 package SDK: a `zfa package create <name>` command that scaffolds a Zuraffa-native reusable package (standard domain/data layout, runtime module, package registrar, test harness, analysis + dependency configuration) passing `dart analyze` and the `zfa build` codegen pipeline with zero manual edits; package-mode-aware generators that emit a **package registrar** instead of the app service locator and skip app-specific artifacts (routes, presentation, app shell); a `PackageModule` runtime contract (init/ready/dispose) that the existing `ZuraffaEngine` activates, auto-registering the package's datasources/repositories/usecases in the consuming app's DI container with zero manual registration; namespaced (`<package>.<usecase>`) agent tools that merge into the consuming app's tool registry collision-free; a zuraffa-version compatibility check at module registration; plus the "Writing Zuraffa packages" guide and a toy reference package in `examples/`.

## Technical Context

**Language/Version**: Dart 3.13 (SDK `^3.11.0`). Pure-Dart root package; the package SDK surface is pure Dart (no Flutter imports) so scaffolded packages work headless.

**Primary stack (existing, reused)**:
- **Engine / micro-frontend module system (v6)** — `lib/src/core/module/`: `ZuraffaEngine` (register → bootstrap: `registerDependencies` + `onInit`), `ZuraffaPlugin` contract, `ZuraffaDIContainer` (wraps GetIt; `.getIt` accessor), runtime-tier `McpTool` + flat `McpToolRegistry` (public via `lib/zuraffa.dart`). The package module builds on this family — no separate lifecycle model (spec assumption).
- **Agent tier** — `lib/src/agent/runtime/mcp_tool_registry.dart` already implements `"$namespace.$tool"` canonical keys with `NamespaceCollisionException`; the runtime-tier registry is the publicly-exported surface packages compile against, so package agent tools target `core/module/mcp_tool.dart` + `mcp_tool_registry.dart`.
- **Generator / DI codegen** — `lib/src/plugins/di/di_plugin.dart` (per-entity `di/*/<entity>_di.dart` + per-category `index.dart` files exposing `registerAll*` functions, main `di/index.dart` with `setupDependencies(GetIt)`, and `di/service_locator.dart` via `ServiceLocatorBuilder`), driven through `PluginContext`/`FileSystem` (rooted at project root) with `AppendExecutor` for idempotent appends.
- **CLI** — `lib/src/cli/cli_runner.dart` registers commands; `zfa setup` (`setup_command.dart`) is the app-scaffold precedent (name validation `^[a-z][a-z0-9_]*$`, existing-directory refusal); `zfa module` scaffolds Flutter feature plugins (`ZuraffaPlugin` orchestrators) — Flutter-only and superseded here by a pure-Dart package flow.
- **Build pipeline** — `zfa build` (`build_command.dart`): `BuildYamlGuard` pre-flight → `RouteAnnotationCompiler` (already no-ops when zero `@Route` annotations) → `dart run build_runner build` → safety nets. `build.yaml` (root) configures `zorphy:zorphy` + `json_serializable`.
- **Version identity** — `lib/src/version.dart` (`const version = '6.1.0'`).

**No new package dependencies.** Constraint parsing for FR-015 is implemented against the caret/range forms the scaffolder itself emits.

**Storage**: file system only — scaffolded packages, generated registrars, guide, examples. No runtime persistence.

**Testing**: `dart test` fast tier (in-process, temp dirs via `Directory.systemTemp.createTemp` + try/finally, `FileSystem.create(root: ...)` fake roots for DI plugin tests) + an `integration`-tagged end-to-end test that scaffolds a real package, runs `dart pub get`, `dart analyze`, `zfa entity create` + `zfa make` + `zfa build` inside it (network: pub.dev for zorphy/build_runner — same tier the existing integration tests use). The consuming-app auto-registration story is proven in-process with `GetIt.asNewInstance()`-backed containers (pattern from engine tests).

**Target Platform**: Linux/macOS/Windows headless CI; any Dart 3.11+ host.

**Project Type**: Dart CLI package (`zuraffa`) — feature adds a command, generator behavior, runtime contracts, docs, and examples.

**Performance Goals**: SC-001 — scaffold + `dart analyze` + build pipeline on a fresh package in < 5 min (bounded by `build_runner`, not by the scaffolder; the scaffold itself is pure file writes, < 1s).

**Constraints**: FR-014 (existing name → clear error, never overwrite); FR-003 (no app artifacts in package context); FR-005 (import-scoped registration — no global statics, registration happens only through the activated module); FR-009 (collision-safe tool names); existing suite must stay green (engine/plugin changes are additive with default no-op hooks); `dart format` clean.

**Scale/Scope**: ~1 new command + scaffolder, 1 detector, 1 runtime contract file + engine extension, 1 agent-tools bridge, 1 compatibility checker, DiPlugin package-mode branch, PluginManager package-mode plugin filter, 1 guide, 2 examples (reference package + consuming demo), ~8 test files.

## Constitution Check

PASS — `.specify/memory/constitution.md` is the unfilled template in this repo (no project-specific principles registered). The design aligns with established repo conventions: extension over rewrite (engine gains default no-op `onReady`/`onDispose` hooks — source-compatible for every existing `ZuraffaPlugin` subclass), pure-Dart core (package SDK adds zero Flutter imports), and codegen stamps/append-regions follow the existing `// Generated by zfa` conventions.

## Project Structure

### Documentation (this feature)

```text
specs/025-v6-package-sdk/
├── spec.md              # input (pre-existing draft)
├── plan.md              # this file
├── tasks.md             # /speckit.tasks output
└── tdd/
    ├── test-list.md     # behaviors + red/green evidence map
    ├── cycle-log.md     # per-cycle red-green-refactor record
    └── verification.md  # /speckit.tdd.verify audit
docs/writing_zuraffa_packages.md   # the guide (FR-013)
```

### Source Code (repository root)

```text
lib/src/core/module/
├── engine.dart                    # + ready() / shutdown() / activeModuleIds / registerPackage()
├── zuraffa_plugin.dart            # + default no-op onReady() / onDispose()
└── package_module.dart            # NEW — PackageModule contract (packageName, agentTools, sdk constraint)
lib/src/package/                   # NEW — package SDK core
├── package_mode.dart              # build.yaml `zfa.package_mode` marker detection (FR-010/011)
├── package_scaffold.dart          # pure scaffolder used by the command (FR-001/014)
├── package_agent_tools.dart       # namespaced tool bridge + PackageUseCaseTool (FR-008/009)
└── package_compatibility.dart     # zuraffa constraint vs running version check (FR-015)
lib/src/commands/package_command.dart   # NEW — `zfa package create <name>`
lib/src/cli/cli_runner.dart            # + PackageCommand registration
lib/src/plugins/di/di_plugin.dart      # package-mode branch: package registrar instead of
                                       #   di/index.dart setupDependencies + service_locator.dart (FR-004/012)
lib/src/core/plugin_system/plugin_manager.dart  # package-mode filter: drop route/view/presenter/
                                                  #   controller/app_shell plugins (FR-003)
lib/zuraffa.dart                       # + exports: PackageModule, PackageMode, PackageAgentTools,
                                       #   PackageUseCaseTool, PackageCompatibility
examples/reference_package/            # NEW — toy reference package (entity + datasource + usecase +
                                       #   agent tool + module + registrar), built via zfa (FR-013)
examples/reference_package_app/        # NEW — consuming demo app (engine activation, auto-DI,
                                       #   namespaced tool invocation) + SC-002 proof test
test/package_sdk/                     # NEW — unit/integration tests (see tdd/test-list.md)
```

**Structure Decision**: runtime contracts live in `core/module/` (the engine family the spec says the package module must follow); SDK tooling (scaffold, mode detection, agent-tools bridge, compatibility) lives in a new `lib/src/package/`; generator changes are confined to the DI plugin's emission tail and the plugin manager's activation filter, so every other generator path is untouched.

## Key Design Decisions

### D1 — Package-mode marker (FR-010/FR-011)

> **Amended during TDD cycle 10** (e2e misfire): the marker originally
> planned as a `zfa: package_mode: true` top-level key in `build.yaml` is
> **rejected by build_runner**, which strictly validates build.yaml's
> schema (`Unrecognized keys: [zfa]`, exit 78 on every subsequent build).
> The marker moved to a zfa-owned `zfa.yaml` at the package root. Same
> semantics, no build_runner coupling.

The scaffold writes a `zfa.yaml` at the package root whose content is the
package-shape marker the pipeline reads:

```yaml
# zfa.yaml
package_mode: true
```

`PackageMode.isEnabled(projectRoot)` (and `isEnabledForOutput(outputDir)`,
which walks up from the generator's output dir to the project root) parses
`zfa.yaml` with the `yaml` package (already a direct dep) and returns
`true` only when the marker is exactly `true`. Detection is
filesystem-based so it flows through the DI plugin's delegator pattern and
is unit-testable with rooted fake filesystems. The scaffold's
`build.yaml` carries only build_runner-legal configuration, mirroring
`DependencyWirer.buildYamlContent` (zorphy + json_serializable builders)
so `zfa build` behaves identically in both contexts (FR-010 parity).

### D2 — Package registrar vs app locator (FR-004, FR-012)

In app context the DI plugin emits `di/index.dart` (`setupDependencies(GetIt)`) + `di/service_locator.dart`. In package context (marker detected through the plugin's `FileSystem`) the same per-entity and per-category files are generated — the domain/data registration surface is unchanged — but the emission tail instead writes/updates **`di/<package_name>_package_registrar.dart`**:

```dart
// Generated by zfa — package registrar for <name> (spec 025, FR-004).
import 'package:zuraffa/zuraffa.dart';

void register<Pascal>Package(ZuraffaDIContainer di) {
  final getIt = di.getIt;
  registerAllUseCases(getIt);      // from di/usecases/index.dart
  registerAllDataSources(getIt);   // from di/datasources/index.dart
  registerAllRepositories(getIt);  // from di/repositories/index.dart
}
```

The registrar is regenerated from the full set of category indexes on every `zfa make ... di` run — multi-entity aggregation in a single pass with no cross-entity ordering assumptions (FR-012), and idempotent because the function body is rebuilt from the on-disk category indexes rather than appended blindly (AppendExecutor strategies handle the merge when the file pre-exists, e.g. the scaffold stub). The app-side `setupDependencies` entry point and `service_locator.dart` are **not** emitted in package mode.

### D3 — Auto-registration via the runtime module (FR-005, FR-006, FR-007)

The scaffold emits `lib/src/module/<name>_package_module.dart`:

```dart
class <Pascal>PackageModule extends PackageModule {
  @override
  String get pluginId => '<name>';           // stable identifier (FR-007)
  @override
  void registerDependencies(ZuraffaDIContainer di) =>
      register<Pascal>Package(di);            // the package registrar (D2)
  @override
  Map<String, ZuraffaRouteHandler> get routes => const {};
}
```

Registration is import-scoped by construction: the registrar function is reachable **only** through the module, and the module is reachable only by importing the package — no global/static state, so a non-imported package contributes nothing (US3-S3). The consuming app does not write a single registration line (SC-002): it activates the module and the container fills.

Lifecycle (FR-006/007): `ZuraffaPlugin` gains default no-op `onReady`/`onDispose` (source-compatible); `ZuraffaEngine` gains `ready()` (calls `onReady` in registration order, once), `shutdown()` (calls `onDispose` in reverse order), `activeModuleIds` (discoverable identifiers of registered modules), and `registerPackage(PackageModule)` (validates the module's declared zuraffa constraint against the running `const version` — D5 — then registers). `bootstrap()` itself keeps its existing two-phase behavior, so every existing plugin/engine test stays valid.

### D4 — Namespaced agent tools (FR-008, FR-009)

`PackageModule` exposes `List<McpTool> get agentTools` (runtime-tier `McpTool` — the publicly exported contract) with **un-namespaced** tool names. `PackageAgentTools.registerInto(McpToolRegistry registry, PackageModule module)` registers each tool as `"$packageName.$toolName"`, so a consuming app's registry exposes `my_pkg.do_something` (US5-S1). Two packages contributing the same use-case name produce distinct canonical names (US5-S2); the same package registered twice hits the flat registry's duplicate-name `StateError` and the engine's duplicate-`pluginId` `ArgumentError`. `PackageUseCaseTool` is a ready-made `McpTool` adapter that resolves a usecase from the DI container and invokes it with a JSON-args → params mapping hook, so scaffolded/example tools execute with the package's own dependency context (US5-S4). The agent-tier (`agent/runtime`) namespaced registry is left untouched — it is not publicly exported, and the runtime tier is the surface `zfa mcp`/`McpServerPlugin` actually serves.

### D5 — Version compatibility (FR-015)

The scaffold stamps the package's pubspec with `zuraffa: ^<major>.<minor>.0` and the module declares the constraint it was generated against. `ZuraffaEngine.registerPackage(module)` calls `PackageCompatibility.check(packageConstraint: module.zuraffaSdkConstraint, appVersion: version)` before registering: different major → `StateError` with a clear remediation message; package minor above app minor → printed warning; otherwise silent. `PackageCompatibility.check` is public and unit-tested (caret `^6.0.0`, `>=6.0.0 <7.0.0`, exact `6.1.0` forms).

### D6 — App-artifact suppression (FR-003)

`PluginManager.resolveActivePlugins` filters out `route`, `view`, `presenter`, `controller`, and `app_shell` when `PackageMode.isEnabled(projectRoot)`, printing one notice line per dropped plugin ("package mode: skipping app-only plugin 'route'"). `zfa app shell` refuses to run in a package-mode project with a clear error. `RouteAnnotationCompiler` already no-ops with zero `@Route` annotations, so `zfa build` needs no change. The result: the same `zfa make <Entity> datasource repository usecase di` command works identically in both contexts (FR-010) and only the DI emission shape differs (D2) — which is also what makes SC-003's ≥90% domain/data identity hold (the entity/repository/datasource/usecase generators are byte-identical in both modes; only DI files differ).

## Complexity Tracking

No violations. No new dependencies; runtime changes are additive default-no-op hooks; generator changes are a bounded branch in one plugin's emission tail plus one activation filter; the command mirrors the established setup-command shape; docs/examples follow existing `docs/` + `examples/` layout.
