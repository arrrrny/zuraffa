# Tasks: v6 Package SDK

**Input**: Design documents from `/specs/025-v6-package-sdk/` (spec.md, plan.md)

**Organization**: MVP-first — Phase 3 (US1 scaffold) is the entry point every other capability depends on; Phase 4 (US2 package-mode generators) is the core value; US3/US4 (auto-DI + module lifecycle) build on both; US5–US7 are namespacing, parity hardening, and docs/examples. TDD: every behavior task is driven red-first per `tdd/test-list.md` (test tasks are mandatory, not optional — TDD extension active).

## Phase 1: Setup (runtime contracts — shared infrastructure)

- [x] T001 [US4] `PackageMode` detector (`lib/src/package/package_mode.dart`): parses `build.yaml` `zfa.package_mode: true` via `yaml` pkg; `isEnabled(projectRoot)` + `isEnabledFromFs(FileSystem)` — red first (U1)
- [x] T002 [US4] `PackageModule` contract (`lib/src/core/module/package_module.dart`): `extends ZuraffaPlugin`, `packageName` (defaults to `pluginId`), `zuraffaSdkConstraint`, `agentTools` (default `const []`) — red first (U6)
- [x] T003 [US4] Engine lifecycle extension (`engine.dart` + `zuraffa_plugin.dart`): default no-op `onReady`/`onDispose` on `ZuraffaPlugin`; `ZuraffaEngine.ready()` (once, insertion order), `shutdown()` (reverse order), `activeModuleIds`, `registerPackage()` — red first (U7–U9); existing engine tests must stay green
- [x] T004 [US4] `PackageCompatibility` (`lib/src/package/package_compatibility.dart`): caret/range/exact constraint parsing vs running version → compatible/warning/incompatible; `registerPackage` rejects incompatible with clear `StateError` — red first (U10–U12)

## Phase 2: Foundational (package-mode generator behavior)

- [x] T005 [US2] DiPlugin package-mode branch: when `PackageMode.isEnabledFromFs(fs)` → emit/update `di/<package>_package_registrar.dart` (`register<Pascal>Package(ZuraffaDIContainer di)` aggregating `registerAll*`), skip `di/index.dart` main index + `service_locator.dart` — red first (U13)
- [x] T006 [US2/US6] Registrar aggregation: registrar content derived from ALL on-disk category indexes (multi-entity single pass, idempotent re-run, no ordering assumptions); scaffold-stub compatibility (file pre-exists → merge, not duplicate) — red first (U14–U15)
- [x] T007 [US2/US6] PluginManager package-mode filter: drop `route`/`view`/`presenter`/`controller`/`app_shell` active plugins when package mode on, one notice per drop; `zfa app shell` refuses in package mode — red first (U16–U17)
- [x] T008 [US6] SC-003 parity test: same entity generated in app context vs package context → domain/data files byte-identical; only DI emission differs (registrar vs locator) — red first (U18)

## Phase 3: User Story 1 — `zfa package create` scaffold (P1) 🎯 MVP

- [x] T009 [US1] `PackageScaffold` (`lib/src/package/package_scaffold.dart`): writes pubspec.yaml (zuraffa `^<maj>.<min>.0` or `--zuraffa-path` path-dep, zorphy, zorphy_annotation, dev build_runner/test, `publish_to: none`), build.yaml (package-mode marker + standard builders), analysis_options.yaml, .gitignore, README, domain/data dirs, barrel `lib/<name>.dart`, module stub, registrar stub, `test/package_smoke_test.dart` — red first (U2–U4)
- [x] T010 [US1] `zfa package create <name>` command (`package_command.dart` + `cli_runner.dart` registration): name validation `^[a-z][a-z0-9_]*$`, `--description`, `--zuraffa-path`, `--output`, `--dry-run`; **existing target → clear error, no overwrite** (FR-014) — red first (U19–U21)
- [x] T011 [US1] CLI-level test via `CommandRunner` (setup-command pattern): flags exist, scaffold lands on disk, duplicate-name error surfaces — red first (U21)
- [x] T012 [US1] GREEN: scaffold + in-process assertions all pass

## Phase 4: User Story 2/3 — generators in package context + auto-DI (P1/P2)

- [x] T013 [US2/US3] Agent-tools bridge (`lib/src/package/package_agent_tools.dart`): `PackageAgentTools.namespaced()`, `registerInto(registry, module)` (prefixes `"$packageName.$toolName"`), `PackageUseCaseTool` adapter (resolves usecase from DI, JSON-args invoke, `McpToolResult`) — red first (U22–U24)
- [x] T014 [US3] Consuming-app auto-registration proof test: temp package (registrar registering a datasource + usecase) + module; `ZuraffaEngine.register(module)` → `bootstrap()` → `di.get<T>()` resolves both; no registration lines in the app code (SC-002); container without the module has no reference (US3-S3) — red first (U25)
- [x] T015 [US3] Two-package merge: two registrars into one container, no conflicts, no manual merge logic (US3-S2) — red first (U26)
- [x] T016 [US4] Lifecycle order + independence test: init → ready → dispose order recorded per module; two modules' hooks fire independently; `activeModuleIds` lists both — red first (U27)
- [x] T017 [US5] Agent-tool registry integration test: module tools appear as `<pkg>.<tool>`; two packages same tool name coexist; same package twice → duplicate error (SC for FR-008/009) — red first (U28–U29)

## Phase 5: User Story 1 (SC-001) — end-to-end pipeline proof (integration tier)

- [x] T018 [US1/US6] `test/package_sdk/package_e2e_test.dart` (`@Tags(['integration'])`): in temp dir run CLI `package create my_pkg --zuraffa-path <repo>` → `dart pub get` → `dart analyze` (zero errors) → `zfa entity create` → `zfa make ... datasource repository usecase di` → assert registrar exists, no service_locator/routes/presentation → `zfa build` (codegen clean); elapsed < 5 min — red first (U30)
- [x] T019 [US1] Record SC-001 evidence (timings, analyze output) in `tdd/verification.md`

## Phase 6: User Story 7 — guide + reference package (P3)

- [x] T020 [US7] `docs/writing_zuraffa_packages.md`: create → generate (entity/make/build in package mode) → consume (module activation, lifecycle, agent tools) → compatibility → layout reference; every command in the guide verified runnable
- [x] T021 [US7] `examples/reference_package/`: toy package with one entity, one datasource, one usecase, one agent tool, module + registrar — **built via the real zfa pipeline** (dogfood), then committed
- [x] T022 [US7] `examples/reference_package_app/`: consuming demo app (pure Dart) — engine activation, auto-DI resolution, namespaced tool invocation, with a test proving the end-to-end consume loop (SC-002/SC-004 support)

## Phase 7: Cross-cutting + closure

- [x] T023 Barrel exports (`lib/zuraffa.dart`): `PackageModule`, `PackageMode`, `PackageAgentTools`, `PackageUseCaseTool`, `PackageCompatibility` — no ambiguous-export regressions (existing export tests stay green)
- [x] T024 CLI help text: `zfa --help` BOOTSTRAP section gains `package create <name>`
- [x] T025 Full verification: `dart analyze` (no new issues), `dart test` (fast tier green, zero regressions), integration-tier e2e green, `dart format .` clean
- [x] T026 `/speckit.analyze` cross-artifact consistency pass (spec ↔ plan ↔ tasks ↔ test-list)
- [x] T027 `/speckit.tdd.verify` audit → `tdd/verification.md` with per-SC verdicts and honest gaps
- [x] T028 Commit artifacts (spec.md, plan.md, tasks.md, tdd/*) + implementation; push branch; open PR (closes #389)
