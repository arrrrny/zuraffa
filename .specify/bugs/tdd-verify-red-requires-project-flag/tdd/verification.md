---
feature: tdd-verify-red-requires-project-flag
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 0daf593d (branch fix/679-tdd-verify-red-requires-project-flag, pre-commit)
behaviors: 4
proven: 2
likely: 0
test_after: 2
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: n/a # no mutation tool in profile; deliberate mutant 1/1 caught
mutants_survived: 0
suite: new hermetic regression file 4/4; test/plugins/tdd +343 all green (0 failures, the earlier -1 was a cwd race in the rejected in-process test variant, fixed by the subprocess rewrite); test/cli +164 all green; dart analyze lib/src/plugins/tdd 0 issues; end-to-end real-CLI fixture runs certified=false (RED, pre-fix) -> certified=true (GREEN, post-fix)
---

# TDD Verification: TDD commands auto-detect project root via ProjectRoot.find() (#679)

**Verdict: PASS_WITH_GAPS.** The mechanical swap is real and end-to-end: the
same real-CLI invocation from a fixture subdirectory that pre-fix bailed with
"unknown behavior id B-001 … classification=unresolved certified=false"
post-fix walks up to the fixture root and certifies the honest red
("certified=true"), the swap is applied uniformly across all 14 TDD command
files, explicit `--project` still overrides, and a deliberate legacy-default
mutant in `verify_red_command.dart` was caught by the new regression test
reproducing the exact bug symptom. Gaps: 12 of the 14 command swaps are
guarded only by the shared existing suites (identical one-line change, no
per-command red-first), the init/override behaviors are TEST_AFTER guards by
nature, and the audit is same-session.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — `zfa tdd verify-red B-001 --feature <f>` run from a fixture SUBDIRECTORY without `--project` resolves the walked-up project root and certifies the honest red | PROVEN | RED first, on the real CLI: fixture `/home/z/my-project/tmp-fixtures/fix679` (pubspec + profile + `specs/090-tdd-fixture/tdd/artifacts.json` + honest-red test), invoked as `dart run <repo>/bin/zfa.dart tdd verify-red B-001 --feature 090-tdd-fixture` with CWD=`<fixture>/lib` → `zfa tdd verify-red: unknown behavior id "B-001". No matching record in any specs/<feature>/tdd/artifacts.json …` + `verify-red: behavior=B-001 classification=unresolved certified=false`. Fixture validity control: same invocation WITH `--project <fixture>` → `classification=assertion certified=true` (only the root resolution was broken). Post-fix, same no-flag invocation from `<fixture>/lib` → `classification=assertion certified=true`. Pinned by `verify_red_subdirectory_test.dart` (real-CLI subprocess, CWD=fixture subdir — issue #506 hermetic pattern) |
| B2 — `tdd init` (representative of the 14 swapped commands) ensures the baseline in the walked-up root, never in the invocation subdirectory | TEST_AFTER | guard behavior (init's default worked from CWD before; the change is WHERE the root resolves from). Real-CLI subprocess test: CWD=`<bare fixture>/lib/src`, `tdd init` → `dart_test.yaml` + `.specify/memory/tdd-profile.md` created at the fixture ROOT, nothing written into `lib/src`. Manual CLI check: CWD=`<fixture>/lib` printed `ensuring TDD baseline in /home/z/my-project/tmp-fixtures/fix679 (Dart)` — the root, not `lib` |
| B3 — an explicit `--project <dir>` still overrides auto-detection | TEST_AFTER | regression guard: CWD=fixture subdir + `--project <other>` → baseline lands in `other`, and the walked-up root is untouched (`dart_test.yaml` absent there). Pre-fix this also passed (the flag always won); the guard exists so the swap can never invert the precedence |
| B4 — `ProjectRoot.find()` walks up from a nested subdirectory (`lib/src/deep`) to the nearest `pubspec.yaml` | PROVEN | unit assertion in the same file, exercised against the TddFixture; failed pre-fix only in the sense that no command CALLED it — the walk-up itself is pre-existing, issue-#441-proven logic (used by make_command) now wired into the TDD surface |

No pre-existing test was weakened: the swap touches only the fallback branch
of `--project` resolution; every existing TDD command test passes its
fixture root explicitly via `--project`, so they exercise the primary branch
unchanged — `test/plugins/tdd` (343) and `test/cli` (164) run green with zero
assertion edits. No test was skipped, renamed out of a filter's reach, or
had a threshold lowered.

## Deliberate mutants (no mutation tool in the profile; sampling on the swapped default)

| # | Mutant (one small change, restored exactly after) | Result |
| --- | --- | --- |
| 1 | Legacy default restored in `verify_red_command.dart`: `ProjectRoot.find()` → `Directory.current.path` (the exact pre-fix code) | CAUGHT — the new regression test fails with the bug's own symptom: `Expected: contains 'certified=true'` / `Actual: 'unknown behavior id "B-001" … classification=unresolved certified=false'`. Restored exactly; re-run: 4/4 green |

Restored exactly after the mutant; the hermetic regression file re-ran green
(+4). Sampling covers the swap in one command end-to-end plus the shared
mechanical pattern (all 14 swaps are the identical one-line change applied by
one script and verified by `grep` + `dart analyze`); the other 13 were not
mutated individually — they are out of the deliberate-mutant sample but share
the same diff shape, and the full TDD suite pins their explicit-flag paths.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | Environment/process note (not shipped): the FIRST version of the regression test mutated `Directory.current` in-process (CliRunner + try/finally restore). Under parallel `dart test` this raced other test files in the same VM — `test_list_reader_test.dart`'s repo-relative fixture read failed while the cwd pointed into a temp fixture (this repo's recorded `cli-tests-cwd-contamination-in-integration-tests` family). The shipped test uses the repo's sanctioned hermetic pattern instead: real-CLI subprocess with `workingDirectory` (`runZfaSource`, issue #506). Zero process-global mutation remains | first variant: `test/plugins/tdd` = +342 -1 with the reader regression failing during the cwd window; rewritten variant: +343 all green |
| 2 | LOW | `lib/src/plugins/tdd/services/mutation_verifier.dart:140` still defaults `workingDirectory ?? Directory.current.path`. Deliberately NOT swapped: the assessment scoped the remediation to `--project` command defaults ("keep the change mechanical"), and the verifier's default is an internal service call whose `workingDirectory` is always supplied by its command callers today. Flagged for a future pass if that ever changes | `mutation_verifier.dart:123,140`; assessment §Suspected Code Paths lists it as conditional ("if … should also auto-detect") |
| 3 | LOW | Same-session audit (Hard Rule 2): the test and the fix were written in this session, so the smell pass is not independent. Mitigation: the new test follows the repo's established subprocess harness (`runZfaSource`/`combinedOutput`, `TddFixture`, `setUpAll(initZfaSourceBin)`), and the mutant pass was executed blind against the assertion before any result was recorded | session transcript; mutant log ordering |

## Traceability

| Issue criterion (expected behavior) | Behavior(s) | Test(s) |
| --- | --- | --- |
| "zfa tdd verify-red (and other zfa tdd sub-commands) should work from within the project directory without requiring --project" — including from a subdirectory (issue #679 Expected Behavior + assessment Symptom) | B1, B2 | `test/plugins/tdd/verify_red_subdirectory_test.dart` (verify-red + init, real CLI from subdirectory); end-to-end manual CLI runs recorded above |
| "Add auto-detection of the project root by walking up from CWD looking for pubspec.yaml (mirroring zfa make's _findProjectRoot())" (issue §Proposed Fix) | B2, B4 | 14-file swap to `ProjectRoot.find()`; walk-up unit assertion; `make_command.dart:121-127` unchanged as the reference pattern |
| "Regression: explicit --project <dir> still overrides auto-detection" (assessment §Tests to add or update) | B3 | override regression-guard test |
| "Invalid CWD (deleted temp dir) does not throw PathNotFoundException (issue #441 parity)" (assessment §Tests to add or update) | B4 (partial) | inherited, not re-tested: `ProjectRoot.safeCurrentPath()` is the exact helper make_command already uses for #441; routing through it gives parity by construction. No new test added — see What was not audited |

All four assessment test items are addressed (two PROVEN end-to-end, one
guard, one parity-by-construction).

## What was not audited

- The invalid-CWD fallback ladder (`safeCurrentPath()` → `PWD` → script dir)
  was not re-exercised by a dedicated test here — parity with #441 is by
  construction (same helper make_command routes through), not by a new
  red-first test in this change.
- The 13 non-verify-red command swaps were not individually mutated; the
  deliberate-mutant sample covers the identical diff shape once.
- The rest of the fast suite beyond `test/plugins/tdd` + `test/cli` was not
  re-run per-bug; the shared chunked run is recorded once for the combo.
