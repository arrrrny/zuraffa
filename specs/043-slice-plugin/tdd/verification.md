---
feature: 043-slice-plugin
verdict: FAIL
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: f35f0ee6
behaviors: 95
proven: 90
likely: 0
test_after: 5
no_test: 0
high_smells: 0
criteria_total: 27
criteria_covered: 27
mutation_score: 8/8 caught # scope: deliberate mutants over 8 high-risk behaviors; both round-1 survivors now caught
mutants_survived: 0
suite: feature scope 145 passed, 0 failed, 18s; extension parity 2 passed; analyze clean; repo-wide chunked run in round 1 (48 dirs green, test/cli 1 failure now fixed)
---

# TDD Verification: Slice Plugin (043) — round 2 (post-remediation)

**Verdict: FAIL.** One condition, and only one, still triggers the rubric's
FAIL row: A11-A15's acceptance tests postdate their implementation
(`TEST_AFTER` at the acceptance level). It is a documented, playbook-sanctioned
ordering gap — the playbook's first-run rule (mutant check) was applied at
the time, the underlying behaviors are `PROVEN` at unit level, and the
deviation is recorded in the test list's *Accepted deviations* section. It
cannot be cleared retroactively, so under this rubric the verdict stays
`FAIL` permanently; every other FAIL condition is cleared and every finding
from round 1 (commit `de99a6b5`) is remediated with proof.

Round 1 verdict was `FAIL` with 3 HIGH smells, 2 surviving mutants, and 1
repo-wide regression. This round re-read every remediated site from disk,
re-ran the suites fresh, and re-ran both surviving mutants.

## Test-first evidence

Unchanged from round 1 (the ordering of history cannot be remediated):
90 of 95 behaviors `PROVEN` — each cycle's red is recorded in the cycle log
with command and decisive output, and the per-cycle commits pair the tests
with the source that turned them green (the history is not squashed).

| Behavior(s) | Class      | Evidence                                                                        |
| ----------- | ---------- | ------------------------------------------------------------------------------- |
| U1-U8       | PROVEN     | cycles 3-4 stub/compile reds; commit 6f58f586                                   |
| U9-U19      | PROVEN     | cycles 5-7 +0 -15 stub batch red; commit 6c433d2e                               |
| U20-U28     | PROVEN     | cycle 8 +0 -17 stub red; commit d94d7a40                                        |
| U29-U36     | PROVEN     | cycle 9 +0 -13 stub red; commit 44acbb2e                                        |
| U37-U44, U67-U68 | PROVEN | cycle 11 +0 -8 stub red; commit f8a04aee                                        |
| U45-U50     | PROVEN     | cycle 16 +0 -6 stub red; commit 01416b1e                                        |
| U51-U53     | PROVEN     | cycle 18 placeholder + compile reds; commit de1486fc                            |
| U54-U64     | PROVEN     | cycle 19 load-failure reds; commit 95078767                                     |
| A1-A4       | PROVEN     | cycle 10 +0 -8 placeholder red; commit 44acbb2e                                 |
| A5-A8       | PROVEN     | cycle 12 placeholder red; commit f8a04aee                                       |
| A9-A10      | PROVEN     | cycle 13 +0 -4 placeholder red; commit ca4d5255                                 |
| A16-A19     | PROVEN     | cycle 17 +0 -4 placeholder red; commit 01416b1e                                 |
| A20-A22     | PROVEN     | cycle 18 placeholder red; commit de1486fc                                       |
| A23-A27     | PROVEN     | cycle 19 placeholder red; commit 95078767                                       |
| A11-A12     | TEST_AFTER | cycle 14 "red: none — passed on first run"; source d94d7a40 predates tests ca4d5255. Playbook first-run rule applied (MUTANT-A11 caught by all three tests); unit-level reds U23-U26 recorded in cycle 8; deviation recorded in the test list |
| A13-A15     | TEST_AFTER | cycle 15 "red: none — passed on first run"; same shape. MUTANT-A13 caught by A13/A15; unit reds U23-U25/U31 recorded; deviation recorded in the test list |

No pre-existing repository test was modified or weakened across the feature
range (re-checked after remediation: the only non-slice test-tree change is
the new `.specify` extension registration that FIXES the parity gate).

## Findings (round 1 → round 2)

All twelve round-1 findings remediated in cycle 21 (commit `f35f0ee6`); each
remediation site was re-read from disk this round. No new findings.

| # | Round 1 finding | Severity | Remediation and proof |
| - | --------------- | -------- | --------------------- |
| 1 | Extension command-parity regression (slice capability unregistered) | HIGH | `extension.yml` provides entry + `commands/slice/cut_slice.md`; `dart test test/cli/standard/extension_command_parity_test.dart` -> 2 passed (the failing test was the red) |
| 2 | Vacuous A10 modified-flag assertion | HIGH | Full status-line pin (`'$viewRel — modified'` + an untouched file `— unmodified`); re-run mutant M2 → A10 now fails (was surviving) |
| 3 | Vacuous A9 file-count assertion | HIGH | Count pinned from the manifest (`'$fileCount files'`); re-run mutant M5 → A9 now fails (was surviving) |
| 4 | Vacuous U20/U21/U26 Map/Set-uniqueness pins | HIGH | Exact expected closure sets; a missing OR extra file now fails the test |
| 5 | A11-A15 TEST_AFTER | MED | Accepted and recorded (test-list *Accepted deviations*, task T125); not retroactively clearable — the standing FAIL condition |
| 6 | Real clock in A9 date expectation | MED | Expectation now reads the manifest's `createdAt`; no `DateTime.now()` in the file |
| 7 | `'1 file'` substring leak in e2e | MED | Anchored `RegExp(r'(^|\s)1 file\(s\) copied back')` — `'11 file(s)'` can no longer match |
| 8 | Redundant same-level pair A26/U58 | MED | Documented as intentional distinct-negative coverage in both files (no gh call pre-verify vs. no tarball on disk) |
| 9 | Duplicated setUp/tearDown across 10 files | LOW | `helpers/slice_test_harness.dart` (`freshSliceProject` / `disposeSliceProject`); all 10 files converted; 145 tests pass unchanged |
| 10 | Progress test name overclaimed the step marker | LOW | `RegExp(r'\[=+> *\] \d+/\d+')` now asserted |
| 11 | U9 `contains` allowed spurious extractions | LOW | Exact list `equals(['GetProductUseCase', 'FetchSettingsUseCase'])` |
| 12 | Truthiness assertions + leaked temp dirs | LOW | Value assertions (`'Slice'`, `'1.0.0'`); temp dirs tracked and deleted in tearDown |

Also fixed during remediation: four pre-existing analyzer warnings in the
feature's test tree (two unused imports, one dead local, one dartdoc
escape). `dart analyze lib/src/plugins/slice/ test/plugins/slice/` is clean.

## Mutation results

Deliberate mutants over the 8 highest-risk behaviors (no mutation tool is
wired; per the profile and rubric). The two round-1 survivors were re-run
against the strengthened tests.

| Mutant | Behavior | Round 1 | Round 2 |
| ------ | -------- | ------- | ------- |
| M1: conflict decision inverted to safeCopy | U39/U43/A7 | caught (4 tests) | unchanged |
| M2: inspect never reports `modified` | A10 | **survived** | **caught** (T115) |
| M3: PubspecFilter keeps every dependency | U54 | caught | unchanged |
| M4: export verify gate removed | U58/A26 | caught (both) | unchanged |
| M5: `slice list` prints `0 files` | A9 | **survived** | **caught** (T116) |
| M6: shared-file confirmation gate dropped | U42 | caught | unchanged |
| MUTANT-A11: only first entry walked | A11/A12 | caught (3 tests) | unchanged |
| MUTANT-A13: depth gate returns true | A13/A15 | caught (2 tests) | unchanged |

Every mutant was restored exactly and the suite re-run green before moving
on. Sample: 8 behaviors of 95; recorded so the section cannot be read as
exhaustive.

## Traceability

Unchanged from round 1: all 27 acceptance scenarios map to A1-A27, every
claimed test exists and runs, every criterion is exercised through the real
CLI entry point. US7 (run) and US8 (export/import) are verified to the
process seam only (no Flutter SDK, no network in this environment) — the
test list documents this as a planning assumption. Untested criteria: none.
Tests tracing to nothing: none.

## What was not audited

- The audit was run by the same session that wrote the tests and the
  remediation — not independent. Round 1's smell pass was delegated to a
  fresh-context subagent with every finding re-verified line-by-line; round
  2's pass covered the remediation diff by direct cold re-reading of every
  changed site (the diff is remediation-only, no new production behavior).
- Mutation strength is a sample (8 behaviors), not a score; no mutation
  tool is wired in this repository.
- Coverage was not measured (opt-in per the profile, not a gate).
- The slow-tagged suites (`test/integration`, `test/property`,
  `test/benchmark`) run no tests under the default tag selector and were
  not forced.
- Real `flutter run` launches and real GitHub pushes were never executed;
  US7/US8 are verified to the process seam only.
- Performance and load behavior: no criterion, no test, not assessed.

## Remediation status

No new remediation tasks: the single standing FAIL condition (finding 5) is
the accepted deviation recorded via T125 and is not actionable — the tests
cannot be un-written and re-run before code that already exists. Everything
actionable from round 1 is cleared (T114-T125 all done, commit `f35f0ee6`).
