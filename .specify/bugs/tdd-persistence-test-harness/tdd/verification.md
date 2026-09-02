---
feature: tdd-persistence-test-harness
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 17a40434 (branch fix/833-tdd-persistence-test-harness, pre-commit)
behaviors: 5
proven: 4
likely: 0
test_after: 0
guards: 1
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: n/a # no mutation tool in profile; deliberate mutant 1/1 caught
mutants_survived: 0
suite: new harness suite test/testing 15/15 green on real hive_ce 2.19.3; reader/writer/plan persistence suites 5/5/3 green; full fast suite chunked (tools/run_tests_chunked.sh) 68/68 chunks green (one flake — test/commands U12 doctor — passed 15/15 in isolation and its chunk re-ran 92/92 green); dart analyze 47 issues == master baseline 47 (zero new); dart format 12/12 changed files 0 diffs (two PRE-EXISTING files drift under the SDK 3.13 formatter — proven identical on a clean master stash, reverted, out of scope); end-to-end real-CLI repro: `zfa tdd gen U1` on a `[persistence]`-marked row pre-fix generated a plain test (5/5 harness probes MISSING) -> post-fix generates the harness-backed test (5/5 probes PRESENT)
---

# TDD Verification: persistence test harness — Hive CE temp-box lifecycle + corrupted-box recovery (#833)

**Verdict: PASS.** Every remediation item is pinned by a red-first suite
running against the REAL `hive_ce` package: the harness suite failed to load
before the fix (the library did not exist), the reader/writer/plan suites
failed red on the missing `[persistence]` contract, and the bug's own
reproduction (a persistence-marked behavior generating a harness-less test)
was captured on the pre-fix CLI and re-captured green post-fix. A deliberate
mutant that reverts the clock injection in `TtlCachePolicy.isValid` was
caught by the suite and the tree restored exactly (re-run 15/15 green). The
audit is same-session (Hard Rule 2 disclosure below) and the record files
for this bug were reconstructed from the brief — both recorded as findings.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — a fresh temp-directory Hive box set is bootstrapped PER TEST and torn down PER TEST, never shared (`PersistenceTestHarness.bootstrap/teardown`) | PROVEN | RED first: `test/testing/persistence_test_harness_test.dart` failed to LOAD pre-fix (library absent — the harness did not exist anywhere in the package). Post-fix green on real Hive: bootstrap opens the box set in a fresh `Directory.systemTemp` dir; teardown closes boxes and deletes the dir (`existsSync == false`); a second lifecycle gets a DIFFERENT temp dir with EMPTY boxes (no data inheritance); double bootstrap refused by `StateError`; teardown-without-bootstrap is a safe no-op. 5/5 in the lifecycle group |
| B2 — TTL assertions advance the injected test clock virtually (`TestClock.advanceTime`), no real sleeps; `TtlCachePolicy` accepts the clock and keeps the real-time default without it | PROVEN (+1 guard) | RED first (same load failure). Post-fix: `advanceTime(6h)` moves `now` exactly 6h while the wall stopwatch stays <1s; clocks do not leak between instances; `TtlCachePolicy(ttl: 6h, clock: clock.call)` is valid fresh, EXPIRED after a virtual 7h advance with wall time <1s — no `Future.delayed`/`sleep` anywhere. Guard: the no-clock constructor still passes with real `DateTime.now` (backward compatibility, passes pre-fix by nature) |
| B3 — corruption drills: a pre-corrupted box fixture opens through the recovery path (clear + re-fetch) and destroys nothing outside the temp box | PROVEN | RED first (same load failure). Post-fix on real hive_ce 2.19.3: `seedCorruptedBox` writes garbage frames into the box file inside the temp dir (refuses an OPEN box); `openWithRecovery` observes Hive's own "Recovering corrupted box." path, asserts the recovered box is EMPTY (clear + re-fetch) and fails with `CorruptionDrillFailure` when the recovery contract is violated (a healthy box with a live row fails the drill — the drill only passes over a genuine corrupted fixture). Isolation: a sentinel file OUTSIDE the temp dir and a sibling OPEN box ('prices', byte-for-byte snapshot) survive the drill untouched. 4/4 in the drill group |
| B4 — registrar gate: init-time registration failure surfaces as a deterministic red at bootstrap, never a runtime read crash (spec 005 US3-AC3) | PROVEN | RED first (same load failure). Post-fix: a `registerAdapters` callback that throws → `bootstrap()` rethrows `RegistrarGateError('init-time adapter registration failed: duplicate typeId 42')` with the harness left un-bootstrapped and its temp dir destroyed; a missing `expectedTypeIds` entry surfaces the same gate error at init; a healthy registrar passes and boxes open. The gate runs BEFORE any box opens, so the red is deterministic at init |
| B5 — the plan MARKS persistence-kind behaviors (`[persistence]` tag), the shared reader parses + strips it, and `zfa tdd gen` emits the harness-backed test | PROVEN | RED first, captured three ways pre-fix: (1) real-CLI reproduction — `zfa tdd gen U1` on a marked 4-col row generated a plain test with 5/5 harness probes MISSING and the raw tag leaking into the description; (2) reader suite red (`BehaviorRow` had no `persistence` field — load failure); (3) writer + plan suites red on the missing field/marking. Post-fix: reader parses the tag in the canonical 4-col and gen-legacy 6-col dialects, case-insensitively, never as prose ('mentions the word persistence' stays unmarked); the writer emits the harness-backed shape for marked behaviors (imports `package:zuraffa/zuraffa.dart`, `PersistenceTestHarness`, `TestClock`, per-test `bootstrap/teardown`, `advanceTime`, no `Future.delayed`/`sleep`) and keeps the plain shape byte-compatible for unmarked ones; plan marks persistence-worded criteria and re-plans idempotently; the post-fix CLI repro shows 5/5 probes PRESENT and a clean description |

No pre-existing test was weakened: the `TtlCachePolicy` change is an optional
named parameter (all existing call sites compile unchanged — the full
`test/core` + `test/plugins` chunks ran green with zero assertion edits);
the reader change adds a field defaulted to `false` and only strips a tag
when one is present (the existing dialect suites — `test_list_reader_test`,
`plan_gen_contract`, `sc_019_legacy_dialect_migration` — ran green in the
chunked run). No test was skipped, renamed out of a filter's reach, or had a
threshold lowered.

## Deliberate mutants (no mutation tool in the profile; sampled on the clock injection)

| # | Mutant (one small change, restored exactly after) | Result |
| --- | --- | --- |
| 1 | `TtlCachePolicy.isValid` ignores the injected clock: `final now = _clock();` → `final now = DateTime.now();` (the exact regression: TTL silently falls back to real time) | CAUGHT — `TtlCachePolicy expires virtually under the injected clock` fails: the fresh entry reads valid but the virtual 7h advance cannot expire it (real time never moved). Restored exactly (`cp` of the pre-mutant file); re-run: 15/15 green |

The mutant targeted the single most regression-prone seam of this fix (the
clock indirection, whose failure mode is invisible without the virtual-time
assertion). The other seams are covered structurally: the reader's
`extract` is pinned by the prose-vs-tag discrimination tests, the writer's
shape by the probes asserts, the gate by the error-type asserts.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | Same-session audit (Hard Rule 2): the tests and the fix were written in this session, so the smell pass is not independent. Mitigation: the harness suite runs against the real `hive_ce` package (no mocks), the mutant pass was executed blind against the assertion before any result was recorded, and the red evidence was captured from the actual pre-fix tree before implementation started | session transcript; RED run log (+1 -5 across the four new suites) |
| 2 | MED | The bug's source records (`.specify/bugs/tdd-persistence-test-harness/{issue,assessment}.md`) were NOT on `master` and GitHub issue #833 was unreachable when this branch was cut. Both records were reconstructed verbatim from the bug brief and committed with the fix, flagged with a provenance note inside the assessment | `git log --all --grep 833` empty; `gh api repos/arrrrny/zuraffa/issues/833` → null; assessment provenance block |
| 3 | LOW | The generated persistence test imports `package:zuraffa/zuraffa.dart`, so its first-run compile requires the user project to depend on zuraffa — true for every project `zfa tdd` targets, but a bare fixture (no zuraffa dep) cannot run the generated persistence test. The writer persistence tests are therefore content assertions; the honest-red e2e (`dart test` on a generated pair) stays pinned for the PLAIN shape in the existing `behavior_test_writer_test`. If `zfa tdd init` ever scaffolds projects without zuraffa, this seam needs a re-look | `test/plugins/tdd/services/behavior_test_writer_persistence_833_test.dart` header comment; existing e2e tests use plain-shaped pairs only |
| 4 | LOW | `dart format` under the SDK 3.13.3 formatter reformats two PRE-EXISTING files (`migrate_paths_command.dart`, `gen_namespacing_827_test.dart`) that this fix never touched — a formatter-version drift present on a clean master (verified via stash + format + diff on the baseline). Reverted here to honor the one-PR-minimality constraint; the change set itself formats stable (12 files, 0 changed) | baseline format run: "Formatted 2 files (2 changed)" on master; post-revert `git diff --name-only` = 7 files, all bug-related |
| 5 | LOW | One flake in the chunked run (`test/commands/doctor_checks_test.dart` U12, cwd-sensitive doctor integration): passed 15/15 in isolation on this branch and its chunk re-ran 92/92 green. Pre-existing family (the repo records `cli-tests-cwd-contamination-in-integration-tests`); not touched by this fix | chunk log line 570; isolation re-run output |

## Traceability

| Issue criterion (expected behavior) | Behavior(s) | Test(s) |
| --- | --- | --- |
| Remediation 1 — "every Hive-touching test gets a fresh temp directory box set, torn down per test — generated into the test by zfa tdd gen when the plan marks the behavior persistence-kind" | B1, B5 | `test/testing/persistence_test_harness_test.dart` (lifecycle group) + `test/plugins/tdd/services/behavior_test_writer_persistence_833_test.dart` (harness wiring probes) + real-CLI repro (pre-fix MISSING → post-fix PRESENT) |
| Remediation 2 — "TTL assertions use a zfa test clock (advanceTime) — no real sleeps in the suite" | B2 | `test/testing/persistence_test_harness_test.dart` (TestClock + TtlCachePolicy clock groups); writer probes assert no `Future.delayed`/`sleep` in generated tests |
| Remediation 3 — "adapter opens a pre-corrupted box fixture and asserts the recovery path (clear + re-fetch per spec edge cases)" | B3 | `test/testing/persistence_test_harness_test.dart` (corruption drills group, real hive_ce recovery path) |
| Remediation 4 — "init-time registration failure surfaces as a deterministic red, not a runtime read crash (spec 005 US3-AC3)" | B4 | `test/testing/persistence_test_harness_test.dart` (registrar gate group) |
| Hard constraints — per-test not shared (B1 second-lifecycle test); clock isolated from other features (B1/B2 instance-leak test); drills never destroy data outside the temp box (B3 sentinel test); minimal change, one PR (diff = 7 modified + 7 new files, one bug) | B1–B3 | per-test rows above; `git diff --stat` on the branch |

All four remediation items are addressed red-first (four PROVEN end-to-end
on the real Hive package, one PROVEN across the plan→gen pipeline with the
negative-compatibility guards noted).

## What was not audited

- The generated persistence test's first-run behavior inside a REAL user
  project (pub-get + verify-red on a zuraffa-dependent fixture) — out of the
  cloud-agent disk budget per dart_test.yaml; covered indirectly by the
  content pins plus the honest-red e2e that exists for the plain shape.
- The five named specs (005, 006, 089, 091, 092) are corpus artifacts of the
  consuming project, not files in this repo — their migration to the marker
  is the corpus owner's follow-up; this PR ships the TOOL contract
  (mark → parse → generate → harness) they will adopt.
- `DailyCachePolicy` still reads `DateTime.now()` directly — the bug names
  TTL only; widening the clock to the daily policy was deliberately left out
  of the minimal change.
- The remaining 67 chunk folders beyond the touched-area suites were run
  once via the shared chunked runner (recorded once for the branch), not
  re-run per behavior.
