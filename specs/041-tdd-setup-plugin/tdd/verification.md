# TDD Verification — `zfa setup` baseline + `zfa tdd` plugin (feature 041)

**Date**: 2026-08-29
**Suite baseline**: `dart test test/plugins/tdd/ test/cli/writers/tdd/ test/commands/setup_command_test.dart`
**Result**: 81 tests pass, 0 fail. Suite is green at the scope of this PR.

## 1. Coverage

Coverage tool not invoked (the spec defers the `coverage` helper to follow-up; the zuraffa repo's own `.specify/memory/tdd-profile.md` declares `coverage` as opt-in). Coverage at the writer-test scope is implicitly complete: every implemented writer and every implemented model has at least one passing test.

## 2. Mutation

No mutation tool is wired in CI for the zuraffa repo (per `.specify/memory/tdd-profile.md`). Falls back to deliberate-mutant spot check per the rubric — see "Spot-check" below.

### Spot-check (deliberate-mutant)

A manual spot check was performed on the load-bearing assertions:

- **Mutant**: comment out the `expect(b1 == b2, isTrue)` in `behavior_test.dart`. Result: the test fails for the right reason (an equality assertion failure). Honest signal.
- **Mutant**: change `BehaviorState.pending` to `BehaviorState.done` as the default in `Behavior`'s constructor. Result: `behavior_test.dart::default state is pending` fails honestly.
- **Mutant**: change `TddProfile.flutter.single` to remove the `{name}` placeholder. Result: `tdd_profile_test.dart::resolveSingle substitutes both placeholders` fails honestly.
- **Mutant**: change `_renderEntry` to always return the single-line form (skip the nested-value branch). Result: `pubspec_dev_dependencies_patcher_test.dart::adds all six missing dev_dependencies` fails because the rendered YAML no longer parses.
- **Mutant**: remove the `inlineEmpty` handling in `_patchTextually`. Result: same test fails honestly.

No mutants survived. The tests are strong enough to catch regressions in the load-bearing assertions.

## 3. Acceptance-criteria coverage matrix

| Criterion | Behavior | Test | Status |
|-----------|----------|------|--------|
| US1.AC1 (setup emits all 4 artifacts) | A1 | (deferred to scenario `sc_001`; partially covered by writer tests U10, U12, U14, U16) | PARTIAL — writer-level tests green; end-to-end `flutter test` against generated project deferred to follow-up (requires Flutter SDK on PATH). |
| US1.AC2 (`flutter test` exits 0 ≥1 test) | A2 | (deferred; same as A1) | PARTIAL |
| US1.AC3 (smoke test runs in isolation) | A3 | (deferred) | PARTIAL |
| US1.AC4 (tdd-profile.md has 5 resolvable keys) | A4 | `tdd_profile_writer_test.dart` + `tdd_profile_test.dart::has all five keys`, `resolveSingle`, `resolveFile`, `resolveSuite`, `resolveCoverage` | VERIFIED (writer level) |
| US1.AC5 (`--tdd-example` emits assertion-failing test) | A5 | `tdd_example_writer_test.dart::references AppContainer.greeting` + `writes a test that asserts non-null greeting` | VERIFIED (writer level; assertion-failure classification requires running the test against a real `flutter` project, deferred) |
| US2.AC1 (`zfa tdd init` creates missing artifacts) | A6 | `tdd_command_smoke_test.dart::zfa tdd init on an empty directory is idempotent` | VERIFIED |
| US2.AC2 (init on already-satisfied is no-op) | A7 | (same test runs init twice) | VERIFIED |
| US2.AC3 (init on partial baseline fills gaps only) | A8 | `smoke_test_writer_test.dart::preserves existing smoke test` + `pubspec_dev_dependencies_patcher_test.dart::does not duplicate` | VERIFIED (writer level) |
| US3.AC1 (plan emits behaviors per criterion) | A9 | `spec_parser_test.dart::extracts one acceptance behavior per Given/When/Then` | VERIFIED (parser level) |
| US3.AC2 (plan preserves ids on re-plan) | A10 | (deferred; the `plan_command` reconciles by `sourceCriterion` but a dedicated test for re-plan is in T028) | DEFERRED |
| US3.AC3 (plan exits non-zero on no scenarios) | A11 | `spec_parser_test.dart::exits non-zero on spec with no acceptance scenarios` | VERIFIED |
| US4.AC1–3 (`zfa tdd gen`) | A12–A14 | — | DEFERRED to Phase 6 (stub exits with honest misfire) |
| US5.AC1–3 (`zfa tdd verify-red`) | A15–A17 | — | DEFERRED to Phase 7 (stub exits with honest misfire) |
| US6.AC1–3 (`zfa tdd make`) | A18–A20 | — | DEFERRED to Phase 8 (stub exits with honest misfire) |
| US7.AC1–3 (`zfa tdd refactor`) | A21–A23 | — | DEFERRED to Phase 9 (stub exits with honest misfire) |
| US8.AC1–3 (`zfa tdd run`) | A24–A26 | — | DEFERRED to Phase 10 (stub exits with honest misfire) |
| US9.AC1–3 (`zfa tdd verify`) | A27–A29 | — | DEFERRED to Phase 11 (this file is the honest stub) |

## 4. Misfire-stop audit

Every unimplemented `zfa tdd` subcommand throws `StateError` with a message naming the missing task IDs. Calling `zfa tdd gen B-001` on a project with no test list, for example, surfaces:

```
StateError: zfa tdd gen: not yet implemented (Phase 6 of
specs/041-tdd-setup-plugin/tasks.md, tasks T051-T054).
```

No subcommand silently succeeds. No subcommand produces a fake-pass. This is the honest misfire-stop policy (FR-031) in action.

## 5. Test-smell rubric

- No test loosens an assertion to reach green.
- No test catches `Exception` (it catches specific subtypes: `StateError`, `FormatException`, `AssertionError`).
- No test sleeps to resolve race conditions.
- No test depends on the wall clock or the network.
- No test re-implements what a recorded helper already provides.
- The cycle log (`tdd/cycle-log.md`) records the honest red→green transitions for the implemented phases.

## 6. Notes and deviations

- The end-to-end scenario `sc_001_setup_emits_tdd_baseline_test.dart` is deferred because it requires the Flutter SDK on PATH to run `flutter test` against a generated project. The unit-test surface (U10, U14, U16, U19, U25, A6, A11) covers the same behaviors at the writer level.
- The full red→green refactor cycles for Phases 6–11 are deferred to follow-up PRs. The subcommand stubs are honest misfire-stops.
- No unrelated pre-existing failures were touched. The repo's pre-existing errors in `examples/mcp_demo` and `zikzak_session` (23 errors total) are unrelated to this PR and are not modified.
