---
feature: slice-di-import-escapes-sandbox (bug #596)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 11de4bfc
behaviors: 11
proven: 11
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: unmeasured # no mutation tool wired (tdd-profile.md); deliberate-mutant fallback used
mutants_survived: 0 # 1 deliberate mutant sampled (import target reverted to nodePath) — caught by A3b
suite: slice suite 156 passed, 0 failed; fast-suite chunks 59/59 runnable PASS; dart analyze clean
---

# TDD Verification: slice cut DI imports escape the sandbox (bug #596)

**Verdict: PASS_WITH_GAPS.** All 11 behaviors affected by the regression are
PROVEN green and every remediation criterion is covered, but the audit is not
clean-`PASS`: the fix commit landed on master without the focused
sandbox-boundary test the assessment required (remediated by this branch, so
its red evidence is session-local via deliberate mutant, not git history), and
mutation strength is unmeasured because no mutation tool is wired in CI.

## Scope resolution (Phase 0 deviation, recorded)

`check-prerequisites.sh --json --paths-only` errors with "Feature directory not
found" — this work is a **bug**, not a spec feature; no `SPECIFY_FEATURE_DIRECTORY`
or `.specify/feature.json` exists. Per the bug extension's convention
("per-bug reports stored under `.specify/bugs/<slug>/`"), `FEATURE_DIR` resolves
to `.specify/bugs/slice-di-import-escapes-sandbox/` and this report is written to
`FEATURE_DIR/tdd/verification.md`. Template stack: no `.specify/templates/overrides/`,
no `.specify/presets/` → rubric resolved from the extension's own copy.

## Provenance of the fix (decisive context)

- Buggy target `target: nodePath` was introduced with the slice plugin in
  `d964801d` (feat 043, #595).
- The remediation line `target: p.join(sandboxDir, rel)` (where
  `rel = p.relative(nodePath, from: projectRoot)`) **already exists on master**:
  `git log -S` attributes the change to `222785f3` ("test fixes (#600)", dated
  2026-08-30, same day as the assessment). That commit touched
  `cut_slice_capability.dart` (+ the committed bug records) but **no slice test
  files**.
- Therefore the RED sweep at HEAD could not reproduce the 11 failures: the
  regression was already fixed before this branch. This is recorded honestly
  instead of being fabricated into a fake red.

## Session run log (all commands actually executed)

| # | Command | Outcome |
| --- | --- | --- |
| 1 | `dart test --preset=all test/plugins/slice/slice_verify_integration_test.dart -j 2` (pre-change) | 4 passed (incl. A16/T102, A18/T104) |
| 2 | `dart test --preset=all test/plugins/slice/runner/slice_runner_test.dart -j 2` (pre-change) | 5 passed (incl. U51, U52/A22 T108, A20 T106) |
| 3 | `dart test --preset=all test/plugins/slice/slice_export_integration_test.dart -j 2` (pre-change) | 5 passed (incl. A23 T109, A24 T110, A25 T111, A27 T113) |
| 4 | `dart test --preset=all test/plugins/slice/slice_e2e_test.dart -j 2` (pre-change) | 1 passed (T075) |
| 5 | `dart test --preset=all test/plugins/slice/slice_polish_test.dart -j 2` (pre-change) | 9 passed (incl. T074 export progress) |
| 6 | `dart test --preset=all ... --plain-name "A3b" -j 2` (new test, first iteration) | FAILED — assertion literal expected `import 'usecases/…'` but generator emits `./`-prefixed sibling `import './usecases/…'`; assertion string corrected (test-side only) |
| 7 | `dart test --preset=all ... --plain-name "A3b" -j 2` (after fix) | PASS |
| 8 | Deliberate mutant: `target: p.join(sandboxDir, rel)` → `target: nodePath`, re-run A3b | FAILED with the exact #596 signature: `import '../../../../../../lib/src/di/usecases/get_product_usecase_di.dart' escapes the slice sandbox via a relative path traversal` |
| 9 | Restore mutant (exact); `git diff --stat lib/` | empty — zero lib diff vs HEAD; A3b re-run: PASS |
| 10 | `dart test --preset=all test/plugins/slice/ -j 2` (full slice suite, Flutter 3.47.2 installed) | **156 passed, 0 failed** |
| 11 | `dart analyze` | No issues found |
| 12 | Fast-suite chunks (official invocation `dart test <dir> --exclude-tags flutter`, kernel caches cleared between chunks) | 59/59 runnable chunks PASS; 5 folders contain only `slow`-tagged suites → `exit 79` no-match (nothing ran, by design of the fast tier) |
| 13 | `dart format .` then `git diff --stat` | 1 file reformatted (the new test); zero remaining formatting diffs |

Disk hygiene: kernel caches cleared between every chunk; scratch/test-fixture
projects live in per-test temp dirs removed by `tearDown`; `df -h` never dropped
below ~55% free during the cycle.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| U51: `flutter run -t <main_slice>` from project root | PROVEN | red verbatim in `assessment.md` (commit `222785f3`); test pre-dates fix; green in run #2 |
| U52/A22 (T108): extra flags pass through verbatim | PROVEN | same red source; green in run #2 |
| A20 (T106): direct runner API launches from root | PROVEN | same red source; green in run #2 |
| A23 (T109): tar.gz export with filtered pubspec | PROVEN | same red source; green in run #3 |
| A24 (T110): github export pushes SLICE.md as README | PROVEN | same red source; green in run #3 |
| A25 (T111): repo name auto-generated | PROVEN | same red source; green in run #3 |
| A27 (T113): import pulls repo back over sandbox | PROVEN | same red source; green in run #3 |
| T074: export reports progress | PROVEN | same red source; green in run #5 |
| T075: cut → verify → modify → merge lifecycle | PROVEN | same red source; green in run #4 |
| A16 (T102): complete slice verifies clean | PROVEN | same red source; green in runs #1 and #10 |
| A18 (T104): `--analyze` runs dart analyze on sandbox | PROVEN | same red source; green in runs #1 and #10 |

Weakened-existing-test audit: `git diff --stat` for this branch is exactly
`test/plugins/slice/slice_cut_integration_test.dart | 69 ++++++` — additions
only; no assertion removed, loosened, renamed out of a filter, skipped, or
config threshold lowered.

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | MED | Fix commit `222785f3` landed without the focused sandbox-boundary test the assessment required ("add a focused unit test asserting that every import in a freshly generated slice_di.dart resolves inside the sandbox"), leaving the #596 regression lock test-after. Remediated on this branch by `A3b (issue #596)`; its red evidence is the deliberate mutant (session-local), not git history. | `git show --stat 222785f3` (no test files); `assessment.md` §Tests to add or update |
| 2 | LOW | `A4b (issue #605)` shells out to `flutter pub get` and fails with `ProcessException: No such file or directory` on Dart-only agents. Environmental, pre-existing on clean HEAD (verified via stash roundtrip); resolved here by installing Flutter 3.47.2. | `test/plugins/slice/slice_cut_integration_test.dart:426` |
| 3 | LOW | `tools/run_tests_chunked.sh` marks all-slow folders (test/benchmark, test/core/dependencies, test/integration, test/plugins/tdd/scenarios, test/property) as failed via `dart test` exit 79 ("No tests match") although nothing ran; the runnable 59 chunks all pass. Pre-existing runner behavior, out of #596 scope. | chunk state logs from run #12 |

No HIGH smells in the new/changed test (self-audit disclosed: the same session
wrote the test, so independence is limited). Rubric items checked: not
tautological (asserts `p.isWithin(sandboxRoot, …)`, file existence, and the
exact sibling import), not vacuous (guards `relativeImports.length >= 4` so a
cut that lost registrations cannot pass), no doubled subject (drives the real
`SliceCommand` through `CommandRunner`, not internal helpers), repository style
follows the `A4b (issue #605)` precedent with shared harness helpers
(`freshSliceProject`/`captureOutput`), fresh temp project per test via
setUp/tearDown, deterministic, ~seconds runtime.

## Mutation results

Scope: the single high-risk line the bug assessment identifies. Tool: none wired
(per `.specify/memory/tdd-profile.md`), deliberate-mutant fallback per rubric.

| Mutant | Behavior | Survived | Judgment |
| --- | --- | --- | --- |
| `cut_slice_capability.dart:324` `target: p.join(sandboxDir, rel)` → `target: nodePath` | A16 boundary property (slice_di imports stay in-sandbox) | No | Caught by `A3b (issue #596)` with the production error signature; mutant restored exactly, suite re-run green |

Sampling is 1 of 1 high-risk behaviors for this bug; overall mutation score
remains unmeasured.

## Traceability

| Remediation criterion (assessment.md / issue.md) | Tests | End to end |
| --- | --- | --- |
| Freshly cut `slice_di.dart` imports resolve inside the sandbox (no `../` escape) | `A3b (issue #596)`, `A16 (T102)`, `T075` | Yes — real `zfa slice cut` invocation |
| verify / export / run recovered (11 tests) | runs #1–#5, #10 | Yes |
| `ImportVerifier` not weakened | `git diff` (verifier untouched), `import_verifier_test.dart` green in run #10 | Yes |
| `lib/src/di/` mirror happens at all relevant depths | `A3` (T089) asserts the usecase DI files mirrored; `A3b` additionally asserts every generated import's target file exists in the sandbox | Yes |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Mutation strength beyond the single sampled deliberate mutant; no mutation
  tool (e.g. mutation_test) was run against the changed files.
- Coverage was not measured (opt-in per `tdd-profile.md`, not a gate).
- The 5 all-slow chunk folders' slow tiers were not executed (fast-suite pass
  excludes them by design); only the bug's slow tests and the slice suite were
  run with the slow tier included.
- Real device launch behavior of `slice run` (tests mock `Process.run`).
- Remediation tasks: the bug directory has no `tasks.md`; finding #1 is
  remediated by this branch itself, findings #2–#3 are informational and out of
  #596 scope, so no remediation section was appended.
