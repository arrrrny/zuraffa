# Tasks: ControlledWidget with FragmentBuilder for Granular Rebuilds (038-controlled-widget-fragment)

**Input**: Design documents from `/specs/038-controlled-widget-fragment/` — `spec.md`, `plan.md`.

**Prerequisites**: `plan.md` (required), `spec.md` (required).

**Tests**: Mandatory. Every behavior in `tdd/test-list.md` (A1..A4, U1..U26) gets a failing test observed before its implementation task runs; behavior ids appear in brackets on each task and are load-bearing for `/speckit.tdd.run`.

**Organization**: MVP-first. Phase 1 scaffolds, Phase 2 lays the shared mount foundation, Phase 3 delivers the P1 user stories (US1–US3: lifecycle, slice-scoped rebuilds, state builders), Phase 4 the P2 stories (US4–US5: UI signals, generation), Phase 5 the P3 story (US6: backward compat) and verification. Edge cases (FR-008) are folded into the story phases where they naturally land.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1..US6)
- Exact file paths in descriptions

## Path Conventions

- Runtime library: `lib/src/state/widgets/`
- Generator: `lib/src/state/generator/view_template_generator.dart`
- Tests mirror source: `test/state/widgets/`
- Barrel: `lib/zuraffa.dart`

---

## Phase 1: Setup

- [x] T001 Verify branch `038-controlled-widget-fragment` created from master; `dart pub get` green; no `dependency_overrides` in `pubspec.yaml`
- [x] T002 Baseline: `dart test test/state` green (68 tests) and `dart analyze lib/` clean before any change; record counts for the SC-004 comparison

---

## Phase 2: Mount Foundation (Blocking Prerequisites)

**⚠️ CRITICAL**: All user-story work depends on the host/context layer existing.

- [x] T003 [U1] [U2] [U3] RED test `test/state/widgets/widget_host_test.dart`: `WidgetHost` mounts a `ControlledWidget` subclass → `onInit` fires exactly once, controller is non-null before `onInit` (FR-001/FR-007); `unmount()` → `onDispose` exactly once, second unmount is a no-op; build(context) invoked exactly once on mount
- [x] T004 [U4] [U5] GREEN `lib/src/state/widgets/widget_host.dart`: `WidgetHost`, `ViewContext` (attach/detach tracking, ancestor validation), `FragmentContextError` with actionable message; attach with a null/detached context throws `FragmentContextError` (FR-008 edge: outside-context usage)
- [x] T005 [U6] [U7] RED+GREEN `lib/src/state/widgets/controlled_widget.dart` + `test/state/widgets/controlled_widget_test.dart`: `ControlledWidget<C>` abstract base — `final C controller`, `onInit`/`onDispose` no-op defaults, `Object? build(ViewContext)` (FR-001); controller available before `onInit` re-asserted at contract level (FR-007)

**Checkpoint**: mount layer + base class exist, `dart analyze lib/src/state/widgets/` clean, widget_host + controlled_widget tests green.

---

## Phase 3: P1 User Stories — Granular Rebuilds (MVP)

- [x] T006 [U8] [U9] RED test `test/state/widgets/fragment_builder_test.dart` (US2, FR-002): two fragments bound to two slices via `SlicePresenter.bind`; slice A emits → fragment A `rebuildCount` +1, fragment B unchanged; slice B emits → only B rebuilds; both change in same turn → each rebuilds exactly once (SC-002 rebuild counting)
- [x] T007 [U8] [U13] [U17] GREEN `lib/src/state/widgets/fragment_builder.dart`: `FragmentBuilder<S>` — `slice`, `builder(context, data)`, attach/detach, per-emission rebuild, `rebuildCount`, `output`, `state`; rebuild after detach is a no-op (FR-008: disposed-controller/in-flight async)
- [x] T008 [U10] [U11] [U12] [U14] RED+GREEN state builders (US3, FR-003): `onLoading`/`onError(context, AppFailure)`/`onEmpty` optional builders; precedence error → loading-without-data → empty → data; slice idle→loading→error→empty→data transitions each render exactly the right builder; omitting a state builder falls through (no forced UI — spec assumption)
- [x] T009 [U12] [U15] [U16] [U18] [U19] RED+GREEN fragment edge cases (FR-008): null/default slice data renders empty builder; empty `Iterable`/`Map`/`String` counts as empty; runtime type mismatch (`SignalSlice<dynamic>` emitting non-`S` into `FragmentBuilder<S>`) surfaces a clear validation failure via `onError`, no crash; rapid successive emissions rebuild once per emission (deterministic, documented in dartdoc); slice disposed mid-attach → defined terminal behavior, no crash
- [x] T010 [U20] [U21] [U22] RED+GREEN `lib/src/state/widgets/signal_builder.dart` + `test/state/widgets/signal_builder_test.dart` (US4, FR-004, FR-008): `SignalBuilder<T>` — `signal`, `builder(context, value)`; only the bound builder rebuilds on signal change; disposed signal renders fallback without errors; nearby `FragmentBuilder` unaffected by signal changes

**Checkpoint**: SC-001 (lifecycle, no manual wiring) and SC-002 (isolated rebuilds) provable in tests.

---

## Phase 4: P2 User Stories — Generation

- [x] T011 [U23] [U25] RED test `test/state/widgets/sc_003_generated_view_compiles_test.dart` (US5, FR-005, SC-003): `ViewTemplateGenerator.generateView(..., pureDart: true)` emits a view that imports only `package:zuraffa/zuraffa.dart`, extends `ControlledWidget`, uses `FragmentBuilder` per use-case slice and `SignalBuilder` per UI signal; the emitted file passes `dart analyze` in a temp package depending on zuraffa; the emitted view mounts under `WidgetHost` and renders slice data end-to-end
- [x] T012 [U23] [U24] GREEN generator: add opt-in `pureDart` mode to `generateView` in `lib/src/state/generator/view_template_generator.dart`; default Flutter emission stays byte-identical (assert in test against current golden content — existing `test/state/v6_cli_generation_test.dart` must stay green unmodified)
- [x] T013 [U26] Fill the three export slots in `lib/zuraffa.dart`: `src/state/widgets/controlled_widget.dart`, `src/state/widgets/fragment_builder.dart`, `src/state/widgets/signal_builder.dart`, plus `widget_host.dart` for the host/context types; `dart analyze lib/` clean

---

## Phase 5: P3 User Story — Backward Compat + Verification

- [x] T014 [U24] RED+GREEN `test/state/widgets/sc_004_pre_v6_compat_test.dart` (US6, FR-006, SC-004): pre-v6 pattern (SlicePresenter + combinedState, full-widget rebuild against plain Signal/SignalSlice APIs, no widget layer) compiles and behaves identically before/after the feature; full `dart test test/state` re-run — no regressions vs T002 baseline
- [x] T015 [U1] [U2] [U13] SC-001 acceptance test `test/state/widgets/sc_001_typed_controller_lifecycle_test.dart`: a developer-style flow — subclass with typed presenter, mount, onInit triggers slice refresh, data arrives, fragment renders — with zero manual subscription/lifecycle wiring
- [x] T016 [U26] `dart analyze` full repo: no NEW issues vs master baseline (pre-existing examples/mcp_demo + zikzak_session errors excluded); `dart test test/state test/core` green
- [x] T017 Update `specs/038-controlled-widget-fragment/tdd/cycle-log.md` and write `tdd/verification.md`; commit all spec-kit artifacts (spec.md, plan.md, tasks.md, tdd/test-list.md, tdd/verification.md) with `spec(038):` prefix; implementation commits use `feat(038):`/`test(038):`/`fix(038):`

---

## Verification Tracker

| Criterion | Task | Verification |
|-----------|------|--------------|
| SC-001 scaffold → running view < 5 min, no manual wiring | T015 | acceptance test mounts a generated-style view with typed controller |
| SC-002 slice change rebuilds only its subtree | T006 | rebuild counting, two fragments, cross-change isolation |
| SC-003 generated views compile + use v6 pattern | T011 | `dart analyze` on generated pure-Dart view + mount end-to-end |
| SC-004 pre-v6 views unchanged | T014 | combined-state pattern test + full state suite re-run |
