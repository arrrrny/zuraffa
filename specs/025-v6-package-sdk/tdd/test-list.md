---
feature: 025-v6-package-sdk
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4 # SC-001..SC-004 in spec.md; 25 story-level acceptance scenarios traced through the inner loop
planned_at: d27c3d2b
updated_at: post-implementation (all behaviors DONE)
suite_baseline: green # captured before first red: `dart analyze` 111 issues / 23 pre-existing errors (zikzak_session/ + examples/mcp_demo/, documented since spec 038); `dart test` fast tier green on master
---

# Test List: v6 Package SDK

## Outer loop: acceptance behaviors

One per success criterion in `spec.md`. Each stays red until the feature works end to end through its real entry point (the `zfa` CLI / `ZuraffaEngine`).

| id  | behavior                                                                                                                     | traces  | kind | state | test |
| --- | --------------------------------------------------------------------------------------------------------------------------- | ------- | ---- | ----- | ---- |
| A1  | A freshly scaffolded package (`zfa package create`) passes `dart analyze` and the full `zfa build` codegen pipeline with zero manual edits, in under 5 minutes | SC-001, US1-S1..S4 | example | DONE | `test/package_sdk/package_e2e_test.dart` (integration tier): CLI scaffold → pub get → analyze → entity create → make → build, timed |
| A2  | A consuming app that imports a package with one datasource + one usecase resolves both from its container with no manual registration code; without the module, nothing registers | SC-002, US3-S1..S3 | example | DONE | `test/package_sdk/package_auto_registration_test.dart` + `examples/reference_package_app/` consume test |
| A3  | The same entity generated in app vs package context yields byte-identical domain/data files; only DI registration (and presentation) differ — ≥90% overlap | SC-003, US6-S3 | example | DONE | `test/package_sdk/package_generation_parity_test.dart` (in-process, both contexts, byte-compare domain+data) |
| A4  | The guide + reference package enable end-to-end build & consume: reference package builds via the documented commands; demo app resolves datasource + usecase + invokes the namespaced agent tool | SC-004, US7-S1..S3 | example | DONE | reference package build run (recorded) + `examples/reference_package_app/test/` consume loop |

## Inner loop: unit behaviors

Grouped by the plan.md component that owns them.

### Package-mode detection (`lib/src/package/package_mode.dart`)

| id  | behavior                                                                                                    | traces        | kind | state | test |
| --- | ----------------------------------------------------------------------------------------------------------- | ------------- | ---- | ----- | ---- |
| U1  | `build.yaml` containing `zfa: package_mode: true` → `isEnabled` true; absent marker / `false` / missing file → false | FR-010, FR-011 | unit | DONE | `test/package_sdk/package_mode_test.dart` |
| U1b | Marker read is scoped to the project root the FileSystem is rooted at (a sibling app's build.yaml does not leak) | FR-011 | unit | DONE | same, rooted-fs case |

### Package scaffold (`lib/src/package/package_scaffold.dart` + command)

| id  | behavior                                                                                                                             | traces        | kind | state | test |
| --- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---- | ----- | ---- |
| U2  | Scaffold writes the full standard layout: pubspec.yaml, build.yaml (marker + builders), analysis_options.yaml, domain/data dirs, module stub, registrar stub, barrel, test harness, README | FR-001 | unit | DONE | `test/package_sdk/package_scaffold_test.dart` |
| U3  | pubspec carries correct v6 constraints (zuraffa caret at the running major.minor, zorphy, zorphy_annotation, dev build_runner/test) and `publish_to: none` | FR-001, US1-S4 | unit | DONE | same |
| U3b | `--zuraffa-path` swaps the hosted zuraffa dep for a path dependency (local-dev flow used by tests/examples) | FR-001 | unit | DONE | same |
| U4  | Scaffolded module stub compiles semantically: extends `PackageModule`, `pluginId` = package name, `registerDependencies` calls the registrar, empty routes; barrel exports module + registrar | FR-001, FR-006 | unit | DONE | same (content assertions) |
| U4b | Scaffolded smoke test imports the barrel and constructs the module (test harness present, FR-001) | FR-001 | unit | DONE | same |

### PackageModule contract + engine lifecycle (`core/module/`)

| id  | behavior                                                                                                                              | traces        | kind | state | test |
| --- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---- | ----- | ---- |
| U6  | `PackageModule` defaults: `packageName` defaults to `pluginId`, `agentTools` empty, `zuraffaSdkConstraint` overridable                   | FR-006/008 | unit | DONE | `test/package_sdk/package_module_test.dart` |
| U7  | Engine `ready()` calls `onReady` on every registered plugin in registration order, exactly once; second call → StateError                | FR-006, US4 | unit | DONE | same |
| U8  | Engine `shutdown()` calls `onDispose` in reverse registration order; idempotent guard                                                  | FR-006, US4-S2 | unit | DONE | same |
| U9  | `activeModuleIds` lists discoverable ids of registered modules; query after bootstrap finds the package module (US4-S3)                  | FR-007 | unit | DONE | same |
| U5  | Existing `ZuraffaPlugin` subclasses (no onReady/onDispose overrides) survive bootstrap+ready+shutdown unchanged (source-compat)          | FR-006 (no regression) | unit | DONE | same |

### Compatibility check (`lib/src/package/package_compatibility.dart`)

| id  | behavior                                                                                                                          | traces        | kind | state | test |
| --- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---- | ----- | ---- |
| U10 | `^6.0.0` vs `6.1.0` → compatible; `^7.0.0` vs `6.1.0` → incompatible; exact/range forms parse                                        | FR-015 | unit | DONE | `test/package_sdk/package_compatibility_test.dart` |
| U11 | Package minor above app minor (`^6.2.0` vs `6.1.0`) → warning (not error)                                                           | FR-015 | unit | DONE | same |
| U12 | `engine.registerPackage(module)` rejects an incompatible module with a clear StateError naming both versions; compatible module registers | FR-015, edge: version incompat | unit | DONE | same |

### DI plugin package mode (`di_plugin.dart`)

| id  | behavior                                                                                                                                    | traces        | kind | state | test |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---- | ----- | ---- |
| U13 | With marker on: `make ... di` emits `di/<pkg>_package_registrar.dart` with `register<Pascal>Package(ZuraffaDIContainer di)` calling `registerAll*`; `service_locator.dart` and main `di/index.dart` (`setupDependencies`) are NOT emitted | FR-004, FR-003 | unit | DONE | `test/package_sdk/package_registrar_test.dart` |
| U14 | Registrar aggregates every entity's category index present on disk — two entities made in sequence produce one registrar covering both (multi-entity single pass, idempotent re-run) | FR-012 | unit | DONE | same |
| U15 | Pre-existing scaffold stub registrar is merged (function updated, not duplicated); app context (marker off) still emits setupDependencies + service_locator | FR-004, FR-010 | unit | DONE | same |

### App-artifact suppression (`plugin_manager.dart` / app shell)

| id  | behavior                                                                                                                                      | traces        | kind | state | test |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---- | ----- | ---- |
| U16 | Package mode on → `route`, `view`, `presenter`, `controller`, `app_shell` are dropped from active plugins with a notice; datasource/repository/usecase/di stay | FR-003 | unit | DONE | `test/package_sdk/package_mode_filter_test.dart` |
| U17 | `zfa app shell` in a package-mode project refuses with a clear error (no app shell in packages)                                                 | FR-003 | unit | DONE | same |
| U18 | Generation parity: entity/repository/datasource/usecase file bytes identical between contexts; DI files differ (registrar vs locator)          | SC-003, FR-010 | unit | DONE | `test/package_sdk/package_generation_parity_test.dart` |

### Agent tools (`lib/src/package/package_agent_tools.dart`)

| id  | behavior                                                                                                                                          | traces        | kind | state | test |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---- | ----- | ---- |
| U22 | `PackageAgentTools.namespaced('my_pkg', 'do_it')` → `my_pkg.do_it`; `registerInto` registers every module tool under the package namespace             | FR-008 | unit | DONE | `test/package_sdk/package_agent_tools_test.dart` |
| U23 | `PackageUseCaseTool` resolves its usecase from the DI container and returns an ok `McpToolResult`; unknown-args shape surfaces as error result          | FR-008, US5-S4 | unit | DONE | same |
| U24 | Tool set from a module appears in the app registry under `<pkg>.<tool>` keys on registration (import-scoped: absent until registered)                  | FR-008, US5-S3 | unit | DONE | same |
| U28 | Two packages contributing the same tool name coexist (`a.do_it`, `b.do_it`); same package registered twice → duplicate-name error (collision-safe)      | FR-009 | unit | DONE | same |
| U29 | Invoking a registered package tool executes with the package's own dependency context and returns the standard tool response format                     | FR-008, US5-S4 | unit | DONE | same |

### Auto-registration (consuming app)

| id  | behavior                                                                                                                                       | traces        | kind | state | test |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---- | ----- | ---- |
| U25 | Engine + module (registrar with datasource + usecase) → after `bootstrap()` both resolve from the container; zero registration lines in the app test code | FR-005, SC-002 | example | DONE | `test/package_sdk/package_auto_registration_test.dart` |
| U26 | Two packages' registrars merge into one container: both datasources present, no conflicts, no manual merge logic                                            | FR-005, US3-S2 | example | DONE | same |
| U27 | Lifecycle order per module: registerDependencies → onInit → onReady → onDispose (reverse); two modules hook independently                                     | FR-006/007, US4 | example | DONE | same |

### End-to-end (integration tier)

| id  | behavior                                                                                                                               | traces        | kind | state | test |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---- | ----- | ---- |
| U30 | Full pipeline in a scaffolded package: analyze zero errors → entity create → make (registrar emitted, no app artifacts) → `zfa build` clean, < 5 min | SC-001, FR-002 | example | DONE | `test/package_sdk/package_e2e_test.dart` (`@Tags(['integration'])`) |
| U19 | `zfa package create` CLI: valid name scaffolds under cwd; invalid name → usage error; `--dry-run` writes nothing                            | FR-001 | unit | DONE | `test/package_sdk/package_command_test.dart` |
| U20 | Duplicate target directory → clear error, exit non-zero, existing content untouched                                                       | FR-014, edge | unit | DONE | same |
| U21 | Command appears in `zfa --help` BOOTSTRAP section; registered on the runner                                                              | FR-001 | unit | DONE | same |

## Invariants and edge cases still to place

- Module-only package (no entities): scaffold's empty registrar + module must activate and dispose cleanly — covered by scaffold smoke test + an explicit empty-module lifecycle assertion in the U27 run.
- Directory that looks like a package but wasn't scaffolded: package mode is marker-driven (`build.yaml`), not scaffold-driven — any project with the marker gets package-mode codegen; documented in the guide (edge case answered by design).
- Package contributes a datasource identity already registered by the app: `ZuraffaDIContainer.register*` with `override: false` throws StateError on conflict — surfaced as a clear registration error during `bootstrap()` (existing container semantics; documented in guide).
- Module init failure during startup: exception propagates out of `bootstrap()` (existing engine fail-fast); no silent swallow — asserted via U27's error-path case.
- Consuming app without an agent tool registry: tools are registered only when the app explicitly calls `registerInto` — no registry, no failure (US edge); documented in guide.

## Out of scope

- Agent-tier (`agent/runtime`) registry changes — the publicly exported runtime tier is the package surface; spec 029 owns agent-tier codegen.
- `zfa module` (Flutter feature packages) — remains as-is; the package SDK is the pure-Dart path.
- Cross-process / distributed package composition (spec assumption: v1 single-app consumption).
- Conflict-resolution strategies beyond existing container semantics (spec defers exact strategy; documented).

## Verification commands

- Fast tier: `dart test test/package_sdk/` then full `dart test`
- Integration tier: `dart test --preset=integration test/package_sdk/package_e2e_test.dart`
- Static: `dart analyze` (must match master baseline of 111 issues / 23 pre-existing errors, all in zikzak_session/ + examples/mcp_demo/)
- Format: `dart format .` → zero diffs
