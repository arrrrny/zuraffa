# TDD Verification — Spec 1538 (void-returning contracts emit a compiling guard)

- **Feature**: `1538-void-returning-contract-compile-fix` (issue #1538 — the
  UNIT lane's IIFE capture returns a void expression from an
  `Object? Function()` closure for void-returning declared contracts;
  `verify-red` dead-ends at compile-error before the designed
  vacuous-guard → hand-step transition)
- **Generated**: FRESH from the actual run in this session (2026-09-13) —
  not a copy of a prior verification.
- **Command path**: `/speckit.specify` → `/speckit.plan` → `/speckit.tasks` →
  `/speckit.tdd.plan` (test list) → `/speckit.tdd.run` (red → green, evidence
  logs recorded) → `/speckit.implement` (none needed — single behavioural
  task) → `/speckit.tdd.verify` (this audit).
- **Scope note**: single-point fix in
  `BehaviorTestWriter._captureInvocation`
  (`lib/src/plugins/tdd/services/behavior_test_writer.dart`) only — the
  contract lane (`contract_test_writer.dart`), the parameter grammar
  (`ContractParam.parse` / `UnitContractShape`), the subject stub signature,
  and the state machine (`run_driver_core.dart`) are untouched. The lib diff
  is pure insertion: 29 lines added, 0 deleted, 1 file.

## Verdict: **PASSED** (gate green, 2/2 mutants killed)

| Gate | Result |
|------|--------|
| Preflight (baseline before change) | ✅ `dart analyze` full repo: 112 issues, ALL info-level — 0 errors / 0 warnings; `dart pub get` clean (no dependency_overrides) |
| Test-first evidence | ✅ RED logs captured with the fix NOT yet written: `tdd/red-1538-fast.log` (fast tier, exit 1 — A1/A2 fail: "does not contain 'Object? result;'" / "does not contain 'result = null;'") and `tdd/red-1538-c1.log` (`--preset=all`, exit 1 — C1 fail with the pair's exact compile error) |
| Red-phase evidence (the issue reproduced) | ✅ C1's emitted pair fails to LOAD: `u3_test.dart:28:18: Error: Can't return a value from a void function.` + `u3_test.dart:37:14: Error: This expression has type 'void' and can't be used.` — the void-expression-in-closure compile error class the issue names (`use_of_void_result`) |
| Green | ✅ `tdd/green-1538.log` — `--preset=all` (slow tier included), exit 0, `+6: All tests passed!` (A1/A2/A3/B1/B2/C1), captured AFTER `dart format` so the evidence matches the final bytes |
| Test-smell rubric | ✅ no sleeps/order deps; isolated `Directory.systemTemp` fixtures with `tearDown` deletion; content pins assert the exact emission tokens (`Object? result;`, `result = null;`, `result = error;`, absent `return subject.` / `final result`); characterization guards (B1/B2, A3) pin the non-void and detector surfaces; the slow C1 proves the pair by RUNNING it, mirroring bug #1512's compile-proof convention |
| Regression sweep (touched surface) | ✅ 30/30: `behavior_test_writer_test.dart` (root) + `behavior_test_writer_persistence_833_test.dart` + `bug_1512_acceptance_vacuous_composition_test.dart` + `bug_1443_void_contract_seam_test.dart`; 62/62: `subject_writer_test.dart` + `unit_contract_shape_1489_test.dart` + `issue_1308_vacuous_guard_remedy_test.dart` + `issue_1308_vacuous_guard_remedy_driver_test.dart` + `bug_1259_vacuous_green_test.dart` + `bug_1513_contract_lane_flutter_imports_test.dart` + `bug_1363_contract_stub_dup_args_test.dart` + `bug_1500_wire_contract_subject_test.dart`; 31/31: `gen_namespacing_827_test.dart` + `generation_planner_test.dart` + `make_command_test.dart`; 11/11 passing in the slow `services/behavior_test_writer_test.dart` (see Known pre-existing drift) |
| Mutation testing (changed file) | ✅ 2/2 mutants killed (`tdd/mutation-1538.log`): M1 void branch removed (revert mutant) → A1+A2 fail; M2 `result = null;` dropped → A1+A2 fail; pristine restored → all green. C1's kill of the revert mutant is additionally proven by the red-phase logs |
| Acceptance-criteria coverage | ✅ SC-1→A1+A2, SC-2→B1+B2 (+ the #1512 unit guardrails passing unchanged), SC-3→A3, SC-4→C1, SC-5→`dart analyze` gate (see below) |
| `dart analyze` (changed files + full repo) | ✅ Changed files: "No issues found!" — full repo: 112 issues, ALL info (identical to baseline: 0 errors / 0 warnings / 112 pre-existing infos) |
| `dart format` | ✅ `Formatted 2 files (0 changed)` for both changed files (format-clean; re-run idempotent). Repo-wide `dart format .` deliberately NOT applied: master carries pre-existing format drift in unrelated files (same handling as spec 1468 — out of this fix's scope) |
| Disk housekeeping | ✅ `.dart_tool/test/` + `dart_test.kernel.*` removed before and after the verify runs; peak usage 1.6 G / 9.9 G |

## 1. Test-first evidence (this session, branch `feat/1538-void-returning-contract-compile-fix`)

Order of operations, before any implementation existed:

1. Wrote `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart`
   (A1/A2/A3/B1/B2/C1) against the spec's success criteria — content pins
   through `BehaviorTestWriter(contractShape: …).write()` +
   `SubjectWriter(contractShape: …).write()` into temp trees.
2. First run (fast tier): **A1 and A2 failed for the right reason** — the
   emitted void test still carried the IIFE capture
   (`final result = (() {` … `return subject.subject_u1(r'sample');`) with
   no `Object? result;` / `result = null;` statements. B1/B2 (non-void
   characterization) and A3 (detector surface) passed as expected — the
   marker machinery was already correct; the compile error was what broke
   the chain. Evidence: `tdd/red-1538-fast.log` (exit 1).
3. Slow tier (`--preset=all`): **C1 failed with the exact issue symptom** —
   the emitted pair did not LOAD:
   `Error: Can't return a value from a void function.` /
   `Error: This expression has type 'void' and can't be used.`
   Evidence: `tdd/red-1538-c1.log` (exit 1).
4. Applied the single-point fix in `_captureInvocation` only: when
   `!acceptance && shape != null && shape.declaredReturn.trim() == 'void'`,
   the capture is the statement-based void-safe form; helpers/args
   composition unchanged; acceptance + default IIFE branches keep their
   bytes.
5. Suite went green: `+6: All tests passed!` (`tdd/green-1538.log`,
   exit 0, `--preset=all`, post-format bytes).

## 2. Red → green (cycle log)

- **RED (evidence `tdd/red-1538-fast.log`, `tdd/red-1538-c1.log`):** exit 1 —
  A1/A2 fail on the missing void-safe capture; C1 fails on the pair's
  compile error (the issue's `verify-red → compile-error` dead end,
  reproduced mechanically).
- **GREEN (evidence `tdd/green-1538.log`):** exit 0 — `+6: All tests
  passed!` after the void branch landed in `_captureInvocation`.
- **Refactor:** none required — the fix is the spec-mandated single point;
  post-green both changed files were formatted (`0 changed` re-run) and
  re-analyzed (`No issues found!`).

## 3. Mutation sampling (changed file)

| Mutant | Change | Result |
|--------|--------|--------|
| M1 | void branch removed (behaviour reverts to the pre-fix IIFE for void returns) | KILLED — A1 (`does not contain 'Object? result;'`), A2 fail; C1 would fail loading (proven at red) |
| M2 | void branch emits `// mutant: completion not recorded` instead of `result = null;` | KILLED — A1/A2 fail on the missing completion record |
| Pristine | fix restored | all green |

Log: `tdd/mutation-1538.log`.

## 4. Acceptance-criteria coverage (SC → evidence)

- **SC-1** (compiling void-safe guard emission) → A1 (scalar params),
  A2 (entity params + placeholder helpers, the issue's exact
  `subject.subject_u3(_arg0(), _arg1())` symptom shape), C1 (compile proof).
- **SC-2** (non-void generation byte-for-byte) → B1 (scalar: IIFE + typed
  assertion, no marker, no void statements), B2 (entity return: IIFE +
  marker guard); the #1512 unit guardrail pins (`final result = (() {`, no
  `final Object? result`) still pass; contract lane / acceptance lane
  suites untouched and green.
- **SC-3** (vacuous-guard → hand-step transition, not compile-error) → A3:
  the void test carries `vacuousGuardComment`, `contentIsVacuousGreen` and
  `contentCarriesVacuousGuardMarker` both true (the run driver's
  `stopped_at=<id>:hand` classification inputs, unchanged machinery), and
  no typed outcome assertion is emitted.
- **SC-4** (the pair compiles and fails through an assertion) → C1:
  `dart test` on the emitted pair exits non-zero (honest red) with
  Expected/Actual output and no `compile-time error` / `use_of_void_result`
  / `undefined name`.
- **SC-5** (`dart analyze` no new issues) → full-repo analyze identical to
  baseline (112 infos, 0 errors, 0 warnings); changed files clean.

## 5. Known pre-existing drift (NOT this fix's scope)

`test/plugins/tdd/services/behavior_test_writer_test.dart::BehaviorTestWriter
test name is the PURE description — the behavior id is not echoed (bug #871)`
fails on pristine master identically (verified via `git stash` → same
Expected/Actual → `git stash pop`): the current binary emits
`test('A1 — <description>')` while that pin expects the pure description.
Unrelated to void contracts (the pinned behavior is the test NAME, not the
capture); documented here rather than silently skipped, and left untouched
per the single-point constraint.
