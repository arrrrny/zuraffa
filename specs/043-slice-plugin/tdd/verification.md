---
feature: 043-slice-plugin
verdict: FAIL
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 1f403b30
behaviors: 95
proven: 90
likely: 0
test_after: 5
no_test: 0
high_smells: 3
criteria_total: 27
criteria_covered: 27
mutation_score: 6/8 caught # scope: deliberate mutants, 8 high-risk behaviors sampled, no mutation tool wired
mutants_survived: 2 # both mapped to HIGH findings (A10, A9)
suite: feature scope 145 passed, 0 failed, 19s; repo-wide (chunked) 48 dirs green, test/cli 138 passed 1 failed (the parity regression, finding 1)
---

# TDD Verification: Slice Plugin (043)

**Verdict: FAIL.** Three HIGH vacuous assertions (two of them mechanically
confirmed by surviving deliberate mutants) and one repo-wide test broken by
the feature — the extension command-parity test — that the feature-scoped
loop never ran.

The loop's discipline is otherwise strong: 90 of 95 behaviors have recorded
red evidence corroborated by per-cycle commits; all 27 acceptance criteria
have command-level end-to-end tests; the process boundaries are cleanly
seamed and deterministic. The failures below are specific and fixable, and
the remediation tasks are appended to `tasks.md`.

## Test-first evidence

Per-cycle commits pair each batch of tests with the source that turns them
green (the profile's sanctioned shape); the history is not squashed, so
every recorded red is corroboratable. The five exceptions are honest
test-after entries the cycle log itself flags.

| Behavior(s) | Class      | Evidence                                                                        |
| ----------- | ---------- | ------------------------------------------------------------------------------- |
| U1-U8       | PROVEN     | cycles 3-4: stub reds + compile reds recorded; commits 6f58f586 pair test+source |
| U9-U19      | PROVEN     | cycles 5-7: +0 -15 stub batch red recorded; commit 6c433d2e                     |
| U20-U28     | PROVEN     | cycle 8: +0 -17 stub red recorded; commit d94d7a40                               |
| U29-U36     | PROVEN     | cycle 9: +0 -13 stub red recorded; commit 44acbb2e                               |
| U37-U44, U67-U68 | PROVEN | cycle 11: +0 -8 stub red recorded; commit f8a04aee                               |
| U45-U50     | PROVEN     | cycle 16: +0 -6 stub red recorded; commit 01416b1e                               |
| U51-U53     | PROVEN     | cycle 18: placeholder red + compile red recorded; commit de1486fc               |
| U54-U64     | PROVEN     | cycle 19: load-failure reds recorded; commit 95078767                           |
| A1-A4       | PROVEN     | cycle 10: +0 -8 placeholder red recorded; commit 44acbb2e                        |
| A5-A8       | PROVEN     | cycle 12: placeholder red recorded; commit f8a04aee                              |
| A9-A10      | PROVEN     | cycle 13: +0 -4 placeholder red recorded; commit ca4d5255                        |
| A16-A19     | PROVEN     | cycle 17: +0 -4 placeholder red recorded; commit 01416b1e                        |
| A20-A22     | PROVEN     | cycle 18: placeholder red recorded; commit de1486fc                              |
| A23-A27     | PROVEN     | cycle 19: placeholder red recorded; commit 95078767                              |
| A11-A12     | TEST_AFTER | cycle 14: "red: none — passed on first run"; source landed in d94d7a40 (cycle 8), tests in ca4d5255. Mitigated: unit reds U23-U26 recorded in cycle 8, and MUTANT-A11 (dropped second entry) was caught by all three tests |
| A13-A15     | TEST_AFTER | cycle 15: "red: none — passed on first run"; depth source landed in cycle 8-9, tests in ca4d5255. Mitigated: unit reds U23-U25/U31 recorded; MUTANT-A13 caught by A13/A15 |

No pre-existing test in the repository was modified or weakened by the
feature's diff (verified: the range touches only new slice test files, new
fixture data, and an `analysis_options.yaml` exclude for the test fixture
directory — test DATA, following the examples/ precedent from spec 025; no
test is excluded from running or analysis). `tasks.md` and the test list
agree: 113/113 tasks ticked, 95/95 behaviors DONE, no unticked task with a
DONE behavior and no ticked task without one.

## Findings

Ordered by severity. Each smell finding was produced by a fresh-context
smell pass and re-verified line-by-line by the auditor against the source
before inclusion.

| #  | Severity | Finding | Evidence |
| -- | -------- | ------- | -------- |
| 1  | HIGH | **Repo-wide regression**: the slice plugin's `cut_slice` capability appears in `zfa manifest` but is not registered in the speckit zuraffa extension, breaking the command-parity gate. The feature-scoped loop never ran `test/cli/`, so this shipped red through 20 cycles. | `test/cli/standard/extension_command_parity_test.dart` fails: "every zfa manifest command is registered in the speckit extension"; `zfa manifest` lists `slice/cut_slice`; `.specify/extensions/zuraffa/extension.yml` has no slice entry |
| 2  | HIGH | Vacuous assertion — the A10 "modified file is flagged" check cannot fail: `'modified'` is a substring of `'unmodified'`, so the assertion passes even when NO file is ever flagged modified. Confirmed mechanically: deliberate mutant M2 (inspect always prints `unmodified`) survived the whole `slice_list_inspect_test.dart` file. | `test/plugins/slice/slice_list_inspect_test.dart:99`; output format at `lib/src/plugins/slice/slice_command.dart:527-530` |
| 3  | HIGH | Vacuous assertion — the A9 "file count is shown" check asserts only `contains('files')`, a literal of the format string; a wrong count passes. Confirmed mechanically: deliberate mutant M5 (`list` always prints `0 files`) survived. | `test/plugins/slice/slice_list_inspect_test.dart:59`; format at `slice_command.dart:476` |
| 4  | HIGH | Vacuous assertions — the U20/U21/U26 "exactly once" dedup pins assert Dart Map/Set invariants: `nodes` is a `Map<String, FileGraphNode>` (keys unique by language semantics) and `includedRel()` returns a `Set`. No implementation change can fail them; the real dedup property is only pinned downstream (A11/A12, where the DI registration count has teeth). | `test/plugins/slice/engine/import_graph_walker_test.dart:99-110` (U20), `:146` (U21), `:229-233` (U26); `lib/src/plugins/slice/models/file_graph.dart:45` |
| 5  | MED | TEST_AFTER acceptance behaviors A11-A15 (see the evidence table): the acceptance tests were written after the multi-entry and depth source, compensated by recorded unit reds and caught mutants but not test-first at the acceptance level. | cycles 14-15 in `tdd/cycle-log.md`; source commit d94d7a40 precedes test commit ca4d5255 |
| 6  | MED | Non-deterministic expectation — the A9 date check computes the expected year from the real clock; a run straddling midnight Dec 31 fails spuriously, and month/day are unpinned. | `test/plugins/slice/slice_list_inspect_test.dart:57` |
| 7  | MED | Leaky value pin — `contains('1 file')` also matches `'11 file(s) copied back'`, `'21 file(s)'`, …; a merge bug copying 11/21/31 files false-passes the "exactly one file merged" claim. | `test/plugins/slice/slice_e2e_test.dart:119`; message format at `lib/src/plugins/slice/merger/slice_merger.dart:219` |
| 8  | MED | Redundant same-level pair — A26 and U58 both drive `zfa slice export` on a broken slice through a `CommandRunner`; the single bug "verify gate removed" fails both. (Each does pin a distinct negative: no gh call vs. no tarball on disk.) | `test/plugins/slice/slice_export_integration_test.dart:205-240`, `test/plugins/slice/capabilities/export_slice_capability_test.dart:32-77` |
| 9  | LOW | Duplicated setup — the fixture-copy/runner/teardown boilerplate is copy-pasted across 10 test files; the profile's `helpers/` convention is the natural home for one factory. | e.g. `slice_cut_integration_test.dart:30-41`, `slice_polish_test.dart:24-33`, and 8 more listed in the smell pass |
| 10 | LOW | Overclaiming name — "cut reports started/step/completed progress" never asserts the step observable (`[====> ] n/m`); a regression dropping all step reporting passes. | `test/plugins/slice/slice_polish_test.dart:165` |
| 11 | LOW | Weak set pin — U9 uses `contains` twice where the sibling test uses `equals([...])`; spurious extra extractions pass. | `test/plugins/slice/engine/service_locator_analyzer_test.dart:53-54` |
| 12 | LOW | Truthiness where values exist (`isNotEmpty` for name/version) and three leaked temp dirs per run (`createTempSync` never cleaned). | `test/plugins/slice/slice_plugin_registration_test.dart:20-26,33-48,55-56` |

Properties beyond the catalogue: isolation is strong (every fixture test
copies the committed fixture into a fresh temp dir via the sanctioned
helper and cleans up — finding 12's leak is the one exception);
determinism is strong (all process boundaries seam-injected; the real
clock appears exactly once, finding 6); specificity is generally high but
weak exactly where findings 2, 3, 7, and 11 point; the suite is fast
(feature scope 19s) and largely insensitive to refactoring (assertions
target on-disk artifacts, exit codes, and manifest contents).

## Mutation results

No mutation tool is wired (per the profile), so deliberate mutants were
applied to the highest-risk behaviors — data-loss paths, gates, and the
behaviors the smell pass flagged. Each mutant was restored exactly and the
suite re-run green before moving on.

| Mutant | Behavior under test | Caught | Judgment |
| ------ | ------------------- | ------ | -------- |
| M1: conflict decision inverted to safeCopy (silent overwrite of concurrently-changed files) | U39, U43, A7 | Yes — 4 tests | 3-way conflict detection has teeth |
| M2: inspect never reports `modified` | A10 | **No — survived** | HIGH: survivor inside a DONE behavior; confirms finding 2 |
| M3: PubspecFilter keeps every dependency | U54 | Yes | filter pinned |
| M4: export verify gate removed | U58, A26 | Yes — both | FR-020 gate pinned |
| M5: `slice list` always prints `0 files` | A9 | **No — survived** | HIGH: survivor inside a DONE behavior; confirms finding 3 |
| M6: shared-file confirmation gate dropped | U42 | Yes | shared-write protection pinned |
| MUTANT-A11 (cycle log): only first entry walked | A11-A12 | Yes — 3 tests | multi-entry pinned at acceptance level |
| MUTANT-A13 (cycle log): depth gate returns true | A13, A15 | Yes — 2 tests | depth levels pinned |

Sampled: 8 behaviors of 95. Not exhaustive; recorded so the section cannot
be read as more than it is.

## Traceability

All 27 acceptance scenarios in `spec.md` (US1-S1 … US8-S5) map to exactly
one acceptance behavior each (A1-A27), every claimed test exists in the
suite and runs (145 feature tests), and every criterion is exercised
through the real CLI entry point (`CommandRunner` → `SliceCommand` →
capability → real files on disk), not just units with doubles.

| Criterion group | Behaviors | End to end |
| --------------- | --------- | ---------- |
| US1 (cut) S1-S4 | A1-A4 | Yes — real cut on the fixture |
| US2 (merge) S1-S4 | A5-A8 | Yes — real merge, real file system |
| US3 (list/inspect) S1-S2 | A9-A10 | Yes, but the pinning assertions are findings 2-3 |
| US4 (multi-entry) S1-S2 | A11-A12 | Yes — TEST_AFTER noted (finding 5) |
| US5 (depth) S1-S3 | A13-A15 | Yes — TEST_AFTER noted (finding 5) |
| US6 (verify) S1-S4 | A16-A19 | Yes — real verification; `dart analyze` through an injectable launcher |
| US7 (run) S1-S3 | A20-A22 | To the process boundary (no Flutter SDK in the env; command construction asserted through the seam, per the documented test-list assumption) |
| US8 (export/import) S1-S5 | A23-A27 | To the process boundary (no network; gh/git through the seam, per the documented test-list assumption) |

Untested criteria: none. Tests tracing to nothing: none — every feature
test file maps to test-list behaviors or to the documented polish tasks
(T071-T076), which are task-tracked rather than behavior-tracked.

## What was not audited

- The audit was run by the same session that wrote the tests — it is not
  independent. Mitigations applied per Hard Rule 2: every test and source
  file cited below was re-read from disk, the smell pass was delegated to
  a fresh-context subagent, and every subagent finding was re-verified
  line-by-line before inclusion.
- Mutation strength is a sample (8 behaviors), not a score; no mutation
  tool is wired in this repository.
- Coverage was not measured (opt-in per the profile, not a gate).
- The slow-tagged suites (`test/integration`, `test/property`,
  `test/benchmark`) run no tests under the default tag selector and were
  not forced.
- Real `flutter run` launches and real GitHub pushes were never executed
  (no Flutter SDK, no network in the environment); US7/US8 are verified to
  the process seam only, as the test list documents.
- Performance and load behavior: no criterion, no test, not assessed.
