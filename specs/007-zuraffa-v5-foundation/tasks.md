# Tasks: Zuraffa V5 Foundation

**Input**: Design documents from `specs/007-zuraffa-v5-foundation/`  
**Prerequisites**: `plan.md` (required), `spec.md` (required)

**Tests**: Hermetic CLI/integration/regression tests are required. Local-infrastructure tests (e.g. MinIO) must be gated out of the default suite.

**Organization**: Tasks are grouped by user story and foundation phase so implementation can proceed incrementally while preserving a shippable v5 migration path.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g. US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Source**: `lib/src/` at repository root
- **CLI/Config**: `lib/src/commands/`, `lib/src/config/`, `lib/src/core/plugin_system/`, `lib/src/core/planning/`
- **Presentation**: `lib/src/presentation/`
- **Tests**: `test/commands/`, `test/integration/`, `test/regression/`, `test/core/`
- **Docs**: `README.md`, `CLI_GUIDE.md`, `AGENTS.md`, `SKILL.md`, `website/docs/`
- **Agent memory**: `.zfa/`

---

## Phase 1: Foundation & Baseline

**Purpose**: Establish the v5 branch, baseline the failing areas, and lock the migration direction before code changes.

- [x] T001 Run the current hermetic/default test suite and capture non-MinIO failures as baseline notes in `specs/007-zuraffa-v5-foundation/plan.md`
- [x] T002 [P] Audit public references to `zfa generate`, `zfa feature`, and `zfa make` across `README.md`, `CLI_GUIDE.md`, `AGENTS.md`, `SKILL.md`, and `website/docs/**`
- [x] T003 [P] Audit all direct `Directory.current` usage in `lib/src/commands/`, `lib/src/config/`, `lib/src/cli/`, and `lib/src/core/plugin_system/` that can break subprocess/agent execution
- [x] T004 [P] Audit plugin default/config participation in `lib/src/plugins/**` and record which plugins expose `configKey`

**Checkpoint**: The v5 migration scope is grounded in current failures and command/docs drift.

---

## Phase 2: Foundational Planning Layer (Critical Path)

**Purpose**: Introduce a single normalized planning system used by CLI and programmatic generation.

**⚠️ CRITICAL**: No user-story implementation should proceed until this phase is complete.

- [x] T005 Create `lib/src/core/planning/generation_plan.dart` to model normalized plan data (name, preset, plugins, aliases, defaults, exclusions, warnings, execution order)
- [x] T006 Create `lib/src/core/planning/preset_registry.dart` for built-in presets such as `feature`, `crud`, `read-only`, `service-feature`, and `adaptive-feature`
- [x] T007 Create `lib/src/core/planning/plugin_alias_resolver.dart` for aliases/groups like `data => repository,datasource` and `vpc => view,presenter,controller`
- [x] T008 Create `lib/src/core/planning/plan_resolver.dart` to merge CLI args, `.zfa.json` defaults, presets, aliases, explicit plugin inclusions, and exclusions
- [x] T009 Update `lib/src/core/plugin_system/plugin_manager.dart` to consume a resolved `GenerationPlan` and execute only selected plugins
- [x] T010 Update `lib/src/generator/code_generator.dart` to use the same planning/resolution path as CLI instead of activating all registered plugins
- [x] T011 Add focused tests for plan normalization in `test/core/planning/plan_resolver_test.dart`
- [x] T012 Add focused tests for alias/preset expansion in `test/core/planning/preset_registry_test.dart`

**Checkpoint**: One normalized plan contract exists and both CLI and programmatic generation can consume it.

---

## Phase 3: User Story 1 — Canonical `zfa make` and Removal of `generate` (Priority: P1)

**Goal**: `zfa make` becomes the canonical API, `feature` becomes a wrapper, and `generate` is fully removed in v5.

**Independent Test**: Run `zfa make` with JSON input/output in a temp workspace and verify the same plan/result is returned regardless of whether the flow is direct or preset-driven.

### Tests for User Story 1 ⚠️

> **NOTE: Write or update these tests FIRST, ensure they fail before implementation**

- [x] T013 [P] [US1] Add CLI test for `zfa make --format=json` in `test/commands/make_command_test.dart`
- [x] T014 [P] [US1] Add CLI test for `zfa make --from-json` in `test/commands/make_command_test.dart`
- [x] T015 [P] [US1] Add CLI test for `zfa make --from-stdin` in `test/commands/make_command_test.dart`
- [x] T016 [P] [US1] Add regression test proving `zfa feature scaffold` resolves through the same normalized plan in `test/commands/feature_command_test.dart`
- [x] T017 [P] [US1] Update/remove legacy `zfa generate` tests in `test/commands/generate_command_test.dart`, `test/regression/cli_command_test.dart`, and `test/cli/cli_edge_cases_test.dart` for v5 behavior

### Implementation for User Story 1

- [x] T018 [US1] Extend `lib/src/commands/make_command.dart` with `--format=json`, `--from-json`, `--from-stdin`, `--preset`, `--with`, `--without`, `--plan`, and `--explain`
- [x] T019 [US1] Refactor `lib/src/commands/feature_command.dart` into a preset wrapper over the planning layer and remove independent orchestration semantics
- [x] T020 [US1] Delete `lib/src/commands/generate_command.dart` and remove its registration from `lib/src/cli/cli_runner.dart`
- [x] T021 [US1] Remove any remaining runtime references to `generate` in CLI help text and public command registration under `lib/src/cli/`
- [x] T022 [US1] Remove the debug print from `lib/src/commands/feature_command.dart`

**Checkpoint**: `make` is the only canonical generation API in v5.

---

## Phase 4: User Story 2 — Deterministic Plugin Orchestration with `.zfa.json` Defaults (Priority: P1)

**Goal**: Plugin execution becomes deterministic and config-driven, without hidden self-activation.

**Independent Test**: A temp project with `.zfa.json` defaults and explicit plugin exclusions resolves the exact expected plugin set and only those plugins execute.

### Tests for User Story 2 ⚠️

- [x] T023 [P] [US2] Add tests for `.zfa.json` plugin defaults in `test/core/plugin_system/plugin_manager_test.dart`
- [x] T024 [P] [US2] Add tests for explicit plugin exclusion/negation in `test/commands/make_command_test.dart`
- [x] T025 [P] [US2] Add tests proving `CodeGenerator` and CLI resolve the same plugin set in `test/regression/compare_outputs_test.dart`

### Implementation for User Story 2

- [x] T026 [US2] Redesign `lib/src/config/zfa_config.dart` into a single v5 config schema with plugin defaults, presets, aliases, UI/layout defaults, entity policy, and fixed-domain/Zorphy-only constraints
- [x] T027 [US2] Update `lib/src/cli/plugin_loader.dart` so disabled/default plugin behavior is compatible with the unified v5 config
- [x] T028 [US2] Add `configKey` participation for any public plugins missing project-default support under `lib/src/plugins/**`
- [x] T029 [US2] Remove plugin self-activation assumptions in plugin implementations under `lib/src/plugins/**` where registration currently implies generation
- [x] T030 [US2] Add entity-first precondition validation to the planning/validation path for entity-aware plugin sets
- [x] T031 [US2] Remove public support for custom domain-root/domain-output overrides across `lib/src/commands/`, `lib/src/config/`, and relevant plugin/config parsing surfaces
- [x] T032 [US2] Remove non-Zorphy entity toggles and generation branches from the canonical v5 workflow under `lib/src/commands/`, `lib/src/config/`, and `lib/src/plugins/`

**Checkpoint**: Plugin selection is explicit, normalized, and consistent across all generation entrypoints.

---

## Phase 5: User Story 3 — Persistent Agent Memory and Blueprints in `.zfa/` (Priority: P1)

**Goal**: Every generation run leaves reusable project memory and architectural context for future agents.

**Independent Test**: Run a generation command and verify `.zfa/plans`, `.zfa/runs`, `.zfa/context.json`, and related artifacts are created and readable.

### Tests for User Story 3 ⚠️

- [x] T033 [P] [US3] Add tests for plan persistence in `test/core/plugin_system/plan_store_test.dart`
- [x] T034 [P] [US3] Add tests for `.zfa` run artifact creation in `test/integration/zfa_memory_integration_test.dart`
- [x] T035 [P] [US3] Add tests for project context/agent contract export in `test/core/project/project_context_test.dart`

### Implementation for User Story 3

- [x] T036 [US3] Migrate `lib/src/core/plugin_system/plan_store.dart` from `.zuraffa/plans` to `.zfa/plans`
- [x] T037 [US3] Create `lib/src/core/project/project_context_store.dart` for `.zfa/context.json`
- [x] T038 [US3] Create `lib/src/core/project/run_store.dart` for `.zfa/runs/*.json`
- [x] T039 [US3] Create `.zfa/blueprints/`, `.zfa/decisions/`, and `.zfa/manifests/` persistence helpers under `lib/src/core/project/`
- [x] T040 [US3] Add automatic run artifact writing after successful generation in `lib/src/core/plugin_system/plugin_manager.dart`
- [x] T041 [US3] Add a generated agent contract file such as `.zfa/AGENT_CONTRACT.md` describing generated/manual zones, fixed domain root, Zorphy-only assumptions, and required `zfa` workflow

**Checkpoint**: New agents can recover prior plans, outputs, and architectural rules from `.zfa/`.

---

## Phase 6: User Story 4 — Platform-Aware Layouts and Shells (Priority: P1)

**Goal**: Zuraffa supports framework-level platform/device-aware UI extension points with shared logic and clean layout divergence.

**Independent Test**: Generate an adaptive feature and verify shared presenter/controller/state plus mobile/tablet/desktop/macOS layout files and shell selection logic exist.

### Tests for User Story 4 ⚠️

- [x] T042 [P] [US4] Add unit tests for platform/device layout fallback logic in `test/presentation/platform_layout_resolver_test.dart`
- [x] T043 [P] [US4] Add integration test for adaptive feature generation in `test/integration/platform_layout_generation_test.dart`
- [x] T044 [P] [US4] Add regression test that generated shared logic is reused across layout variants in `test/regression/platform_layout_structure_test.dart`

### Implementation for User Story 4

- [x] T045 [US4] Create `lib/src/presentation/platform/device_class.dart`
- [x] T046 [US4] Create `lib/src/presentation/platform/platform_class.dart`
- [x] T047 [US4] Create `lib/src/presentation/platform/platform_context.dart`
- [x] T048 [US4] Create `lib/src/presentation/platform/platform_layout_resolver.dart`
- [x] T049 [US4] Create `lib/src/presentation/shells/app_shell.dart` and platform/device-specific shell abstractions under `lib/src/presentation/shells/`
- [x] T050 [US4] Extend presentation generation builders under `lib/src/plugins/view/`, `lib/src/plugins/presenter/`, `lib/src/plugins/controller/`, and `lib/src/plugins/state/` to scaffold `pages/<feature>/layouts/`
- [x] T051 [US4] Extend `lib/src/presentation/responsive_view.dart` or introduce a new adaptive base view to incorporate platform + device fallback instead of width-only breakpoints
- [x] T052 [US4] Add v5 config/preset switches for adaptive/platform layout generation in `lib/src/config/zfa_config.dart` and `lib/src/core/planning/preset_registry.dart`
- [x] T053 [US4] Add a validation/quickstart note in the spec docs that a downstream app like `Developer/zik_zak` should be used to validate macOS vs mobile shell divergence once accessible

**Checkpoint**: Zuraffa has a framework-level answer for mobile/tablet/desktop/macOS layout divergence.

---

## Phase 7: User Story 5 — Cohesive Documentation, Prompts, and Reliability Defaults (Priority: P1)

**Goal**: All docs/prompts teach the same workflow and the default suite is hermetic.

**Independent Test**: Grep-based checks confirm no official docs recommend `zfa generate`, and the default suite excludes local MinIO dependencies.

### Tests for User Story 5 ⚠️

- [ ] T054 [P] [US5] Add documentation reference checks in `test/regression/docs_command_consistency_test.dart`
- [ ] T055 [P] [US5] Add test gating/isolation for MinIO/local-service tests in `test/core/artifact_publisher_test.dart` or a new external-integration test harness
- [ ] T056 [P] [US5] Add a regression test for robust project root resolution in subprocess/temp-dir scenarios in `test/regression/cli_command_test.dart`

### Implementation for User Story 5

- [ ] T057 [US5] Replace `zfa generate` references in `README.md`
- [ ] T058 [US5] Rewrite `CLI_GUIDE.md` around `zfa make` as canonical and `zfa feature` as wrapper
- [ ] T059 [US5] Rewrite `AGENTS.md` to require `zfa entity create` → `zfa make` → `zfa build`, explicitly documenting fixed `lib/src/domain` and Zorphy-only assumptions
- [ ] T060 [US5] Rewrite `SKILL.md` to align with the same canonical workflow and manual UI zones
- [ ] T061 [US5] Update website docs under `website/docs/` to remove stale/contradictory `feature`/`generate` guidance and invalid `make` plugin examples
- [ ] T062 [US5] Add `.zfa`/agent-memory documentation to README and website docs
- [ ] T063 [US5] Gate MinIO/local-infra tests out of the default suite, e.g. by tags, environment variables, or moving them into a dedicated external integration suite
- [x] T064 [US5] Create a robust project root resolver under `lib/src/core/project/project_root.dart` and replace brittle `Directory.current` bootstrapping in `lib/src/commands/`, `lib/src/config/`, `lib/src/cli/`, and `lib/src/plugins/feature/capabilities/`

**Checkpoint**: Docs, prompts, and default tests are coherent and trustworthy.

---

## Phase 8: Polish & Cross-Cutting Validation

**Purpose**: Final cleanup, migration confidence, and release readiness for v5.

- [ ] T065 [P] Remove or hide placeholder/no-op public plugin surfaces that should not be promoted in v5, notably ambiguity between `lib/src/plugins/gql/` and `lib/src/plugins/graphql/`
- [ ] T066 [P] Add release/migration guide content for v4 → v5 under `doc/` and `website/docs/`
- [ ] T067 [P] Run targeted command/docs grep checks to ensure no official v5 references to `zfa generate` remain
- [ ] T068 Run hermetic `flutter test` suite excluding local-infra tests and confirm pass
- [ ] T069 Run targeted CLI/integration/regression tests for `make`, feature wrapper, `.zfa` persistence, adaptive layouts, fixed-domain assumptions, and Zorphy-only flows
- [ ] T070 Run `dart analyze` on all modified source/test/doc-support files
- [ ] T071 Validate end-to-end quickstart: create entity, run `zfa make`, run `zfa build`, verify `.zfa/` artifacts and generated structure

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1**: Start immediately
- **Phase 2**: Depends on baseline/audit results from Phase 1 — **blocks all major implementation**
- **Phase 3**: Depends on Phase 2
- **Phase 4**: Depends on Phase 2; should proceed after canonical planning exists
- **Phase 5**: Depends on Phase 2; `.zfa` persistence should share normalized planning metadata
- **Phase 6**: Depends on Phase 2; can begin after planning/config can represent adaptive/platform options
- **Phase 7**: Depends on Phases 3–6 enough to document the final v5 contract accurately
- **Phase 8**: Depends on all prior phases

### User Story Dependencies

- **US1 (Canonical make / remove generate)**: first major delivery after the planning layer
- **US2 (Deterministic config/orchestration)**: depends on US1 planning core, but can progress in parallel after Phase 2
- **US3 (`.zfa` memory)**: depends on normalized plan contract
- **US4 (Platform-aware layouts)**: depends on canonical planning/config but is otherwise independent from docs work
- **US5 (Docs/reliability)**: depends on locking the v5 contract from US1–US4

### Within Each User Story

- Write/update tests first
- Make the minimal architecture changes to satisfy the normalized plan contract
- Validate CLI + programmatic parity before broad rollout
- Update docs only after command/config behavior is stable enough to describe accurately

### Parallel Opportunities

- Phase 1 audit tasks can run in parallel
- Phase 2 planning model/tests can be split across files and run in parallel
- US3 `.zfa` persistence and US4 platform-aware layout scaffolding can proceed in parallel after Phase 2
- Doc rewrites across README/CLI guide/website/skills can run in parallel once v5 command semantics are locked
- Final grep-based validation and targeted analysis/test runs can run in parallel

---

## Implementation Strategy

### MVP First (V5 foundation, not full polish)

1. Complete Phase 1 baseline/audits
2. Complete Phase 2 unified planning layer
3. Complete Phase 3 canonical `make` + delete `generate`
4. Complete Phase 4 deterministic plugin/config parity
5. **STOP and VALIDATE**: `make` is canonical, programmatic parity exists, CLI is robust
6. Add `.zfa` persistence (Phase 5)
7. Add platform-aware shells/layouts (Phase 6)
8. Rewrite docs and tighten reliability (Phase 7)
9. Finish Phase 8 release validation

### Incremental Delivery

1. **Foundation** → one plan contract
2. **Command unification** → one public API
3. **Persistence** → one memory system
4. **Platform-aware UI** → one maintainable multi-platform story
5. **Docs/reliability** → one coherent product story

### Parallel Team Strategy

With multiple developers:

1. Developer A: planning layer + plugin manager + code generator parity
2. Developer B: CLI command migration (`make`, `feature`, removal of `generate`)
3. Developer C: `.zfa` persistence and agent contract artifacts
4. Developer D: platform-aware layout/shell architecture
5. Developer E: docs/website/skills migration + reliability test isolation

---

## Notes

- This is a deliberate v5 breaking-change initiative.
- The command/API simplification is a feature, not a regression.
- `.zfa/` is a first-class product surface for humans and agents, not just an internal cache.
- Platform-aware presentation support is required to make multi-platform downstream apps maintainable.
- A downstream validation pass against `Developer/zik_zak` should be added during implementation as soon as workspace access is available.
