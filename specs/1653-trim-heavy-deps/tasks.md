# Tasks: Lean Core — heavy integrations become opt-in zfa plugins

**Input**: Design documents from `/specs/1653-trim-heavy-deps/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: TDD mode is ON (bug-config/tdd extension): every behavior-marked task is driven by the red-green loop (`tdd/test-list.md`); test tasks are MANDATORY and precede their implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)

## Path Conventions

- Core package: repo root (`lib/`, `test/`, `pubspec.yaml`)
- Companion packages: `packages/zuraffa_graphql/`, `packages/zuraffa_storage/`, `packages/zuraffa_observability/`

---

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 Create companion package skeletons: `packages/zuraffa_graphql/pubspec.yaml` (deps: graphql, gql, analyzer-free core exports as needed), `packages/zuraffa_storage/pubspec.yaml` (dep: minio), `packages/zuraffa_observability/pubspec.yaml` (dep: opentelemetry) — each with `analysis_options.yaml` (reuse root lint set), `lib/<package>.dart` barrel, `test/` dir, `CHANGELOG.md`, `README.md`
- [ ] T002 [P] Register the three companions in root `pubspec.yaml` excluded paths/docs if required by tooling; confirm root resolution ignores them (`dart pub get --no-example` in root unaffected)

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 Create `OptionalPlugin` + `PluginCatalog` model in `lib/src/plugins/plugin_gate/plugin_catalog.dart` per data-model.md (catalog ids `graphql`, `storage`, `observability`; backing packages `zuraffa_graphql`, `zuraffa_storage`, `zuraffa_observability`; unknown id refuses naming the catalog)
- [ ] T004 Create `.zfa.json` plugins-section persistence in `lib/src/plugins/plugin_gate/plugin_config.dart` (read `plugins:<name>:bool`; write is additive, other keys untouched)
- [ ] T005 [P] Create light `TraceObserver` seam in `lib/src/core/trace_observer.dart` (`currentTraceId`/`currentSpanId`, null defaults, static instance registry) per data-model.md
- [ ] T006 [P] De-type `lib/src/core/hook.dart`, `lib/src/domain/usecase.dart`, `lib/src/domain/stream_usecase.dart` to read trace fields from `TraceObserver` instead of `OtelTracer.instance` (byte-equal values when tracing active via plugin; null when absent)
- [ ] T007 [P] Flip the failure-reporter default to the no-op reporter in `lib/src/core/failure_reporter_registry.dart` (otel reporter becomes plugin-registered; no core import of `otel_failure_reporter.dart`)

**Checkpoint**: Foundation ready — user story implementation can now begin

---

## Phase 3: User Story 1 — Lean core dependency graph (Priority: P1) 🎯 MVP

**Goal**: The core package's manifest and barrel carry zero heavy packages; core-only consumers and tests pass without them.

**Independent Test**: `dart pub get --no-example` + `dart test` in root with the heavy deps gone; the lean-core pin suite passes.

### Tests for User Story 1 (MANDATORY — write FIRST, prove RED)

- [ ] T008 [P] [US1] [behavior: U1] Write the dependency-manifest pin: `test/core/lean_core_pin_test.dart` asserts root `pubspec.yaml` `dependencies:` contains none of `graphql/gql/minio/opentelemetry` (FR-001..003) — RED before the manifest trim
- [ ] T009 [P] [US1] [behavior: U2] Extend the pin: no file under `lib/` imports any of the four packages, and `lib/zuraffa.dart`'s export closure contains no heavy symbol (FR-004) — RED before the moves
- [ ] T010 [P] [US1] [behavior: U3] Pin `TraceObserver` seam behavior: `test/core/trace_observer_test.dart` — default observer yields null trace/span ids; hook context assembly reads it (not OtelTracer) — RED before T005/T006

### Implementation for User Story 1

- [ ] T011 [US1] Create `packages/zuraffa_observability/`: move `lib/src/core/otel_tracer.dart`, `lib/src/core/otel_failure_reporter.dart`, `lib/src/core/telemetry_hook.dart` (imports rewritten to package-local), register the otel-backed `TraceObserver` + failure reporter on the package's barrel init; move the simulation otel adapter from `lib/src/simulation/simulation_adapters.dart` (core keeps a light adapter seam)
- [ ] T012 [US1] Create `packages/zuraffa_storage/`: move `lib/src/core/minio_client.dart` (MinioClient) with its doc examples
- [ ] T013 [US1] Create `packages/zuraffa_graphql/`: move the heavy-importing `lib/src/graphql/**` files (client factory/provider/subscription stream, gql documents generator + document builder + file preserver, heavy datasource/di codegen, graphql validator) and the 3 heavy-importing test files; rewrite intra-package imports
- [ ] T014 [US1] Slim `lib/zuraffa.dart`: delete the otel api re-export, `MinioClient`, `TelemetryHook`, and moved-graphql export lines; keep pure-Dart graphql codegen helpers; keep light seams
- [ ] T015 [US1] Trim root `pubspec.yaml` `dependencies:`: remove `graphql`, `gql`, `minio`, `opentelemetry`; run `dart pub get --no-example`; fix any residual compile errors in core until `dart analyze lib` is clean
- [ ] T016 [US1] Move/adjust heavy-dependent core tests to companions; make root `dart test` (default lane) green without the heavy packages

**Checkpoint**: User Story 1 independently verifiable — lean manifest, green core suite (SC-001/SC-002)

---

## Phase 4: User Story 2 — Seamless enabled workflows (Priority: P1)

**Goal**: With a capability enabled and its companion resolvable, the existing zfa workflow runs unchanged; otherwise every entry point refuses with guidance.

**Independent Test**: With `plugins.graphql: true` + companion path-resolvable, the graphql command path completes; with either condition false, it exits non-zero naming the fix.

### Tests for User Story 2 (MANDATORY — write FIRST, prove RED)

- [ ] T017 [P] [US2] [behavior: U6] Write the gate tests: `test/plugins/plugin_gate/plugin_gate_test.dart` — not-enabled → refusal exit + guidance naming `zfa plugin enable <name>` (FR-008); enabled-not-resolvable → refusal naming the package + `dart pub get`; enabled+resolvable → delegation proceeds (spy seam, FR-007); refusal happens before any artifact write
- [ ] T018 [P] [US2] [behavior: A2] Write the trace-hook integration pin: with the observability companion registered (fixture path dep), `HookContext` trace ids flow as before the split — RED until the registration path exists

### Implementation for User Story 2

- [ ] T019 [US2] Implement the gate in the graphql command path (`lib/src/plugins/graphql/` command wiring): resolve enablement (`.zfa.json`) + resolvability (project `package_config.json` — reuse the `ZuraffaBarrelExports` package_config seam); delegate to the companion entry when healthy
- [ ] T020 [US2] Companion CLI entries: `packages/zuraffa_graphql/bin/` (or `lib/zuraffa_graphql.dart` entry) exposing the moved generate flow so delegation is a spawn through the `ZfaExecutable` no-JIT seam (AGENTS.md)
- [ ] T021 [US2] Observability registration path: companion-provided `TraceObserver`/failure reporter wiring usable from a consumer app (documented init call), covered by T018's pin

**Checkpoint**: US2 independently verifiable — enabled path seamless, disabled path honest (SC-003)

---

## Phase 5: User Story 3 — Plugin discovery and toggling (Priority: P2)

**Goal**: One command lists capabilities/states/packages; enable is idempotent and persisted.

**Independent Test**: list → all disabled; enable → list shows enabled; enable again → no-op success; `.zfa.json` untouched elsewhere.

### Tests for User Story 3 (MANDATORY — write FIRST, prove RED)

- [ ] T022 [P] [US3] [behavior: U5] Write `test/plugins/plugin_gate/plugin_command_test.dart`: `zfa plugin list` renders name/state/package/resolvable (exit 0 always, FR-005); `zfa plugin enable <name>` writes `.zfa.json` additively (FR-006); unknown id refuses naming the catalog; re-enable is no-op success; disable reports what stays behind

### Implementation for User Story 3

- [ ] T023 [US3] Implement `zfa plugin` command family (`lib/src/plugins/plugin_gate/plugin_command.dart`, registered in `lib/src/cli/cli_runner.dart`): `list`, `enable <name>`, `disable <name>` per contracts/plugin-gate.md
- [ ] T024 [US3] Wire the graphql gate (T019) and observability/storage docs to the same catalog so guidance text cannot drift

**Checkpoint**: All user stories independently functional

---

## Phase 5b: Behavior tasks inserted by tdd.plan (LLM-guided fallback)

- [ ] T030 [P] [US2] [behavior: U4] Pin the catalog: `test/plugins/plugin_gate/plugin_gate_test.dart` — the three catalog ids resolve to their backing packages; an unknown id refuses naming the catalog (FR-005/FR-006)
- [ ] T031 [P] [US3] [behavior: U7] Pin list rendering: `zfa plugin list` renders one line per capability with name/enabled/backing-package/resolvable and always exits 0 (FR-005)
- [ ] T032 [US1] [behavior: A1] Fresh-consumer acceptance: in a temp package, add the trimmed core via path dep, resolve, assert zero heavy packages in the resolution and `dart analyze lib` clean in core (SC-001/SC-002)
- [ ] T033 [US2] [behavior: A3] Disabled-path acceptance: drive a capability entry point in a project without enablement — non-zero exit, exact guidance, no partial artifacts (FR-008/SC-003)
- [ ] T034 [P] [US1] [behavior: A4] Companion health: `dart pub get` + `dart analyze` + `dart test` green in each of packages/zuraffa_graphql, packages/zuraffa_storage, packages/zuraffa_observability (SC-002)

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T025 [P] CHANGELOG: major-version breaking-change entry with the per-export migration map (FR-010, contracts/plugin-gate.md table)
- [ ] T026 [P] Companion READMEs: enable flow, registration examples, what moved
- [ ] T027 Update `docs/` surface touched by removed exports (grep docs for MinioClient/TelemetryHook/OtelTracer/graphql client references)
- [ ] T028 Run quickstart.md validation end-to-end; `dart format lib test packages` + `dart analyze` on all touched packages
- [ ] T029 Tag the three heavy suites' replacements with correct tiers (`slow`/`e2e`) per test/README.md

---

## Dependencies & Execution Order

### Phase Dependencies

- Setup (T001-T002) → Foundational (T003-T007) → US1 (T008-T016) → US2 (T017-T021) → US3 (T022-T024) → Polish
- US2 depends on US1's moves (delegation targets the companions) and Foundational's gate plumbing
- US3 depends on Foundational (catalog/config) and integrates US2's gate but is independently testable

### Within Each User Story

- Pin/behavior tests (T008-T010, T017-T018, T022) are written FIRST and proven RED
- Moves/de-typing before manifest trim (T011-T013 → T014-T015)
- Gate delegation before command polish

### Parallel Opportunities

- T005/T006/T007 (seam de-typing) in Foundational
- Companion creation T011/T012/T013 after their source files' dependents are de-typed
- Test-first tasks are [P] within their story

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 + 2 (foundation seams)
2. Phase 3: lean core — the issue's headline value
3. STOP and validate: fresh resolution + default lane green

### Incremental Delivery

- US1 lands the lean core (breaking, migration-mapped)
- US2 restores heavy workflows behind the opt-in gate
- US3 makes the gate discoverable — the "seamless zfa command" contract

## Notes

- Commit after each task or logical group (hooks do this per phase)
- STOP-ON-ROADBLOCK (AGENTS.md) applies to any zfa misfire during delegation testing
- Never spawn zfa JIT (`dart bin/zfa.dart`) in tests/children — use the compiled-binary seams
