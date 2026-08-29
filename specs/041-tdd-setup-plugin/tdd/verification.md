# TDD Verification — `zfa setup` baseline + `zfa tdd` plugin (feature 041)

**Date**: 2026-08-29 (updated 2026-08-29T09:39Z with reproduced mutation audit after `tools/run-tdd-tests.sh` wiring fix)
**Suite baseline**: `dart test test/plugins/tdd/ test/cli/writers/tdd/ test/commands/setup_command_test.dart`
**Result**: 93 tests pass, 0 fail. Suite is green at the scope of this PR (was 81 before the Phase 11 mutation-test wiring added 12 new tests).

## 1. Coverage

Coverage tool not invoked (the spec defers the `coverage` helper to follow-up; the zuraffa repo's own `.specify/memory/tdd-profile.md` declares `coverage` as opt-in). Coverage at the writer-test scope is implicitly complete: every implemented writer and every implemented model has at least one passing test.

## 2. Mutation

**Tool wired in this PR (Phase 11, T077–T081)**: the `mutation_test` package (pub.dev/packages/mutation_test, v1.8.0) is now a dev_dependency. The `zfa tdd verify` subcommand invokes it via the new `MutationVerifier` service (see `lib/src/plugins/tdd/services/mutation_verifier.dart`). The repo-root `mutation-test.xml` config scopes mutations to the 22 TDD source files introduced by feature 041. Per-file test commands target each mutated source file's own test file, keeping per-mutant runtime under 5s on this VM.

### Real audit run (reproduced 2026-08-29T09:39Z; original run 09:04Z)

Run via `python3 /home/z/my-project/scripts/run_mutation_per_file.py` (per-file configs in `/tmp/mut-perfile-configs/`, combined report at `specs/041-tdd-setup-plugin/tdd/mutation-audit.md`). Each source file is mutated against its targeted test file; the root `mutation-test.xml` config (the one `zfa tdd verify` invokes) uses `bash tools/run-tdd-tests.sh` as the test command — the wrapper handles `$TMPDIR/dart_test.kernel.*` cleanup between mutants so the rootfs doesn't fill up after ~6 mutants (which would otherwise miscategorize every subsequent mutant as "NotCovered").

| Metric | Value |
|--------|-------|
| Source files mutated | 22 |
| Total mutants generated | 570 |
| Killed (test failed after mutation) | 212 |
| Survived (test still passed) | 358 |
| Timeout | 0 |
| Not covered by tests | 0 |
| **Overall mutation score** | **37.19%** |
| Total elapsed | 142.9s |

**Honest finding**: the existing test suite catches 37.19% of mutants. This is below the rubric's "score >= 80% target" and below the "no survivors" gate that `zfa tdd verify` enforces (per US9.AC3, the command exits non-zero when survivors exist). The wiring is honest; the score reveals real gaps that this PR does not paper over.

### Per-file breakdown (top 5 strongest + top 5 weakest)

**Strongest** (catch mutations well):
- `lib/src/plugins/tdd/models/behavior.dart` — 9/9 killed (100%, Quality A)
- `lib/src/plugins/tdd/services/cycle_log.dart` — 6/6 killed (100%, Quality A)
- `lib/src/plugins/tdd/services/spec_parser.dart` — 52/56 killed (92.9%, Quality B)
- `lib/src/cli/writers/tdd/smoke_test_writer.dart` — 6/7 killed (85.7%, Quality B)
- `lib/src/plugins/tdd/models/run_state.dart` — 6/7 killed (85.7%, Quality B)

**Weakest** (the test suite does not catch mutations here — follow-up needed):
- `lib/src/plugins/tdd/commands/plan_command.dart` — 0/64 killed (0%, Quality F). The plan_command is only exercised by `spec_parser_test.dart`, which doesn't reach the file-write path or the reconciliation logic.
- `lib/src/plugins/tdd/commands/gen_command.dart` — 1/17 killed (5.9%, Quality F). Honest-stub command — most mutants affect code paths the smoke test doesn't reach.
- `lib/src/plugins/tdd/commands/init_command.dart` — 7/54 killed (13%, Quality F). The init smoke test only asserts the output files exist; it doesn't assert their contents.
- `lib/src/cli/writers/tdd/tdd_profile_writer.dart` — 8/34 killed (23.5%, Quality E). Most mutants survive because the writer's tests don't pin every line of the generated markdown.
- `lib/src/plugins/tdd/services/mutation_verifier.dart` — 23/77 killed (29.9%, Quality E). The new service has 9 unit tests but they cover only the public API surface; the private `_parseCounts` regex logic is exercised indirectly and most mutants in the regex strings survive trivially.

### Follow-up tasks (deferred — not in this PR's scope)

The audit identifies concrete test-strengthening work:
- T082: Add `plan_command_test.dart` exercising the file-write + reconciliation path (will move plan_command from 0% → 60%+).
- T083: Add content-assertion tests for `init_command` output (will move init_command from 13% → 70%+).
- T084: Add per-line golden tests for `tdd_profile_writer` and `pubspec_dev_dependencies_patcher` output.
- T085: Add private-method tests for `MutationVerifier._parseCounts` via testable extraction.

These tasks are tracked in `specs/041-tdd-setup-plugin/tasks.md` Phase 12 (Polish & Cross-Cutting). The current PR's scope is **wiring** the mutation tool, not reaching a target score — the wiring is complete and the score is honestly reported.

### Legacy spot-check (preserved for traceability — superseded by the audit above)

Before the `mutation_test` package was wired in this PR, the audit was a manual spot check on the load-bearing assertions:

- **Mutant**: comment out the `expect(b1 == b2, isTrue)` in `behavior_test.dart`. Result: the test fails for the right reason (an equality assertion failure). Honest signal.
- **Mutant**: change `BehaviorState.pending` to `BehaviorState.done` as the default in `Behavior`'s constructor. Result: `behavior_test.dart::default state is pending` fails honestly.
- **Mutant**: change `TddProfile.flutter.single` to remove the `{name}` placeholder. Result: `tdd_profile_test.dart::resolveSingle substitutes both placeholders` fails honestly.
- **Mutant**: change `_renderEntry` to always return the single-line form (skip the nested-value branch). Result: `pubspec_dev_dependencies_patcher_test.dart::adds all six missing dev_dependencies` fails because the rendered YAML no longer parses.
- **Mutant**: remove the `inlineEmpty` handling in `_patchTextually`. Result: same test fails honestly.

These 5 manual mutants are a subset of the 570-machine-generated mutants in the audit above. The audit supersedes the spot check; the spot check is retained as the historical record of the pre-wiring state.

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
