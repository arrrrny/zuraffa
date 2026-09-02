---
feature: tdd-mutation-pin (bug #755)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 7eb14fb0
behaviors: 8
proven: 0
likely: 8
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 0 # no mutation tool in CI per .specify/memory/tdd-profile.md
mutants_survived: 0
deliberate_mutants_run: 3 # all caught; see "Mutation results" below
suite: 17 passed, 0 failed, <1s (patcher test file, --preset=all)
---

# TDD Verification: Bug #755 — tdd-mutation-pin

**Verdict: PASS_WITH_GAPS.** Every behavior the bug requires is covered by an
explicit assertion, every deliberate mutant was caught, and the change is
isolated to the two `static const Map<String, String>` literals named in the
issue. The verdict is `PASS_WITH_GAPS` rather than `PASS` for three reasons
listed individually under "What was not audited": (a) no mutation tool is
wired into CI (per the project's TDD profile), so test strength was measured
by 3 deliberate mutants rather than exhaustive mutation; (b) the test file
carries `@Tags(['slow'])`, so the new tests are NOT exercised by the default
`dart test` / `tools/run_tests_chunked.sh` tier — they run only under
`dart test --preset=all` or `--preset=regression`; (c) the single-commit
history cannot independently corroborate test-first ordering, so each
behavior is `LIKELY` (cycle log records the red) rather than `PROVEN`.

## Test-first evidence

| Behavior | Class  | Evidence                                                                                                                                                                                                                                                                                                                                                                                                                             |
| -------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B-01     | LIKELY | Cycle 1 red recorded in `tdd/cycle-log.md` with verbatim failing output (`Expected: '^1.8.0' / Actual: '^1.0.0'`). Single-commit history cannot corroborate test-before-source order.                                                                                                                                                                                                                                              |
| B-02     | LIKELY | Cycle 1 red recorded; same single-commit caveat.                                                                                                                                                                                                                                                                                                                                                                                    |
| B-03     | LIKELY | Cycle 1 red recorded (`Expected: '^1.15.1' / Actual: '^1.6.0'`).                                                                                                                                                                                                                                                                                                                                                                    |
| B-04     | LIKELY | Cycle 1 red recorded.                                                                                                                                                                                                                                                                                                                                                                                                                |
| B-05     | LIKELY | Cycle 1 red recorded (`Expected: false / Actual: <true>` for `flutterDevDependencies.containsKey('mocktail')`).                                                                                                                                                                                                                                                                                                                     |
| B-06     | LIKELY | Cycle 1 red recorded.                                                                                                                                                                                                                                                                                                                                                                                                                |
| B-07     | LIKELY | Cycle 1 red recorded; end-to-end test writes a real pubspec to a tmpdir and re-reads it via `loadYaml` to assert the written values.                                                                                                                                                                                                                                                                                                |
| B-08     | LIKELY | Cycle 1 red recorded; end-to-end test as above, Dart mode.                                                                                                                                                                                                                                                                                                                                                                           |

**Weakened existing tests check.** Three pre-existing tests in
`test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart` were
updated because they encoded the OLD buggy contract:

| Test (line)                       | Before                                       | After                                                                  | Verdict            |
| --------------------------------- | -------------------------------------------- | ---------------------------------------------------------------------- | ------------------ |
| `adds all six missing ...` (29)   | `added.length == 7`; `mocktail` expected true | `added.length == 6`; `mocktail` expected **false**; new `containsKey('mocktail') isFalse` assertion | Tightened, not weakened |
| `does not duplicate existing entries` (73) | `mocktail: ^1.0.0` pre-declared, `added.length == 5` | `build_runner: ^2.4.0` pre-declared, `added.length == 4` | Same shape, different dep; no assertion removed |
| `creates dev_dependencies block when missing` (114) | `added.length == 7` | `added.length == 6`                                                    | Tightened, not weakened |

No assertions were removed, loosened, replaced by truthiness, or renamed
out of a filter's reach. No tests were skipped, pending, or excluded. No
coverage or mutation thresholds were lowered.

## Findings

Ordered by severity. Each finding cites `file:line` and the change that
would address it. The auditor did not fix any of these — the report is
the product.

| #   | Severity | Finding                                                                                                                                               | Evidence                                              |
| --- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| 1   | MED      | The new bug-#755 test group is in a file tagged `@Tags(['slow'])`, so the default `dart test` and `tools/run_tests_chunked.sh` runners skip it. The pinned contract is therefore not exercised by CI's default fast tier. | `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart:1` |
| 2   | LOW      | Cycle log was written in the same session that wrote the tests, so the red evidence is self-reported rather than independent. The `LIKELY` classification reflects this. | `tdd/cycle-log.md` (entire file)                      |
| 3   | LOW      | The bug-fix branch has no `spec.md`/`plan.md`/`tasks.md` (only `issue.md` + `assessment.md`), so traceability to numbered acceptance criteria is approximate — criteria were derived from the issue body. | `.specify/bugs/tdd-mutation-pin/` (folder)            |

No `HIGH` smells were found in the new tests. The new tests are
behavior-named, assert specific values (not truthiness), have no
doubles (the patcher is a pure synchronous class operating on the
filesystem), and do not re-implement the source's logic.

## Mutation results

No mutation tool is wired into CI (`.specify/memory/tdd-profile.md`:
"Mutation tool: none wired in CI. `/speckit.tdd.verify` Phase 4 falls
back to deliberate-mutant sampling per the rubric."). Three deliberate
mutants were run against the highest-risk behaviors; all were caught
and the suite was confirmed green after each restore.

| Mutant                                                                                                       | Behavior | Survived | Judgment                                                                                              |
| ------------------------------------------------------------------------------------------------------------ | -------- | -------- | ----------------------------------------------------------------------------------------------------- |
| `pubspec_dev_dependencies_patcher.dart:35` `mutation_test: '^1.8.0'` → `'^1.0.0'` (flutter map)              | B-01, B-07 | No       | Caught by `flutterDevDependencies pins mutation_test at ^1.8.0` and `flutter-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml`. |
| `pubspec_dev_dependencies_patcher.dart:42` `coverage: '^1.15.1'` → `'^1.6.0'` (dart map)                     | B-04, B-08 | No       | Caught by `dartDevDependencies pins coverage at ^1.15.1` and `dart-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml` (which also asserts coverage). |
| `pubspec_dev_dependencies_patcher.dart:32` re-add `'mocktail': '^1.0.0'` to flutter map                       | B-05, B-07 | No       | Caught by `flutterDevDependencies does NOT include mocktail`, `flutter-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml`, and `adds all six missing dev_dependencies`. |

Sampling is not exhaustive: only 3 mutants were run, on the three
distinct contract changes (mutation_test pin, coverage pin, mocktail
removal). Mutants on `dartDevDependencies['mutation_test']`,
`dartDevDependencies['mocktail']`, `flutterDevDependencies['coverage']`
were not run; their assertion shape mirrors the ones sampled and the
same tests catch them by symmetry.

## Traceability

Criteria derived from `issue.md` (the "Suggested fix" + "Secondary
wart" sections) and `assessment.md` ("Proposed Remediation"). The
"Secondary wart" (blank-line preservation in `_patchTextually`) was
NOT addressed — see "What was not audited".

| Criterion                                                           | Tests                                                                | End to end |
| ------------------------------------------------------------------- | -------------------------------------------------------------------- | ---------- |
| C-1: `mutation_test` pin bumped to `^1.8.0` in both maps            | B-01, B-02, B-07, B-08                                                | Yes        |
| C-2: `coverage` pin bumped to latest (`^1.15.1`) in both maps       | B-03, B-04, B-07, B-08                                                | Yes        |
| C-3: `mocktail` removed from both maps (unused by generated tests)  | B-05, B-06, B-07, B-08                                                | Yes        |
| C-4: fix ONLY the version pins in `pubspec_dev_dependencies_patcher.dart` | diff stat: 4 files changed, only 2 source/test files + 2 tdd-cycle artifacts | Yes (by inspection of `git diff --stat master..HEAD`) |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- **Mutation was not exhaustive.** Only 3 deliberate mutants were run
  (one per distinct contract change). Symmetric mutants on the Dart
  map's `mutation_test` and the Flutter map's `coverage` were not run;
  they are caught by symmetric tests by inspection, but were not
  mechanically verified.
- **The bug's "Secondary wart" was not addressed.** Issue #755 also
  notes that `_patchTextually` splices new dev_dependencies without
  blank-line preservation, leaving the following top-level key glued
  directly against the last entry. The hard constraint ("fix ONLY the
  version pins") excluded this from scope; no test asserts on the
  blank-line shape, and the fix does not touch `_patchTextually`.
- **CI fast-tier coverage.** The new tests live in a `@Tags(['slow'])`
  file. CI's default `dart test` and `tools/run_tests_chunked.sh` skip
  them; they run only under `dart test --preset=all` (or `--preset=regression`).
  Finding #1 above records this. A follow-up to split the new tests
  into a fast-tier file (or strip the file-level `@Tags(['slow'])`)
  would close the gap.
- **Performance / load behavior.** Not applicable: the patcher is a
  pure synchronous file-system class with no performance criterion.
- **Independent audit.** The audit was run by the same session that
  wrote the tests. The red evidence is verbatim from the actual test
  run captured in this session, but the rubric's "Read cold" hard
  rule prefers a fresh-context subagent for the smell pass; none was
  available in this CLI-only environment. Finding #2 records this.
