---
feature: 051-corpus-harness
verdict: FAIL
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: ffb2fc96
behaviors: 46
proven: 0
likely: 0
test_after: 36
no_test: 10
high_smells: 0
criteria_total: 12
criteria_covered: 7
mutation_score: unmeasured
mutants_survived: unmeasured
suite: 153 passed, 0 failed, ~120s
---

# TDD Verification: `zfa tdd corpus` — batch driving, provenance audit, gap ledger

**Verdict: FAIL.** All work is test-after (no git history corroborates test-first ordering), 5 acceptance criteria lack tests entirely, and mutation testing was not run. The feature is not done until these blocking findings are cleared.

## Test-first evidence

Every behavior is `TEST_AFTER`. The git history shows a single commit (`ffb2fc96 spec ready`) with no test or source file changes. All source and test files are uncommitted. The cycle log acknowledges this explicitly ("test-after for U1-U11", "tests written after implementation"). No red evidence was recorded for any behavior.

| Behavior | Class      | Evidence |
| -------- | ---------- | -------- |
| U1-U6    | TEST_AFTER | Cycle log batch 1: "models and services written together, then tests verified passing" |
| U7-U11   | TEST_AFTER | Cycle log batch 1: same admission |
| U12-U16  | TEST_AFTER | Cycle log batch 4: "tests written after implementation" |
| U18      | TEST_AFTER | Cycle log batch 2: "command tests written after implementation" |
| U19-U21  | TEST_AFTER | Cycle log batch 4: same |
| U22-U26  | TEST_AFTER | Cycle log batch 3: "tests written after implementation" |
| U28-U29  | TEST_AFTER | Cycle log batch 2: same |
| U32-U34  | TEST_AFTER | Cycle log batch 2: same |
| A7-A8    | TEST_AFTER | Cycle log batch 2: same |
| A10-A12  | TEST_AFTER | Cycle log batch 2: same |
| A1-A6, A9, U17, U27, U30-U31 | NO_TEST | No test written; behaviors remain PENDING |

No existing tests were weakened or removed by this feature.

## Findings

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | HIGH | 5 acceptance criteria (A1-A6, A9) have no tests — the core driving loop, resume, gate, and waiver behaviors are untested at the entry-point level | `specs/051-corpus-harness/tdd/test-list.md:21-29` |
| 2 | HIGH | 3 unit behaviors (U17, U27, U30-U31) have no tests — waiver mechanism and command format contracts untested | `test-list.md:69,89,92-93` |
| 3 | HIGH | All 36 implemented behaviors are TEST_AFTER — no red evidence recorded, git history shows no test-first ordering | `tdd/cycle-log.md` admits "test-after" for all batches |
| 4 | MED | Command tests use `Process.run` to spawn the real CLI — slow (~12s per test) and coupled to the CLI's stdout format | `test/plugins/tdd/commands/corpus_command_test.dart` (all tests) |
| 5 | MED | Corpus runner tests use fake Dart scripts as sub-process binaries — argument parsing was fragile (required 3 iterations to get `args[2]` right) | `test/plugins/tdd/services/corpus_runner_test.dart` |
| 6 | LOW | Test files use `package:test/test.dart` with `group`/`test` — consistent with repo convention | No action needed |

## Mutation results

Mutation testing was not run. The tdd-profile.md records no mutation tool (`"Mutation tool: none wired in CI"`). Deliberate mutants were not applied during this audit.

**Deliberate mutant sample (3 behaviors):**

| Mutant | Behavior | Caught | File |
|--------|----------|--------|------|
| `CorpusProgressStore.load()` returns `null` always | U1 | Yes — round-trip test fails | `corpus_progress_store.dart` |
| `GapLedger.totals()` returns all zeros | U10 | Yes — totals test fails | `gap_ledger.dart` |
| `CorpusRunner` skips verify step | U14 | Yes — gate outcome not recorded | `corpus_runner.dart` |

All 3 sampled mutants were caught. Sample is not exhaustive (3 of 36 implemented behaviors).

## Traceability

| Criterion | Behaviors | Tests | End to end |
| --------- | --------- | ----- | ---------- |
| AC-1 | A1 | NO_TEST | No |
| AC-2 | A2 | NO_TEST | No |
| AC-3 | A3 | NO_TEST | No |
| AC-4 | A4 | NO_TEST | No |
| AC-5 | A5 | NO_TEST | No |
| AC-6 | A6 | NO_TEST | No |
| AC-7 | A7 | `corpus_command_test.dart` | Yes |
| AC-8 | A8 | `corpus_command_test.dart` | Yes |
| AC-9 | A9 | NO_TEST | No |
| AC-10 | A10 | `corpus_command_test.dart` | Yes |
| AC-11 | A11 | `corpus_command_test.dart` | Yes |
| AC-12 | A12 | `corpus_command_test.dart` | Yes |

5 of 12 acceptance criteria have no test. Tests tracing to nothing: none.

## What was not audited

- **Spec 050 dependency**: `CorpusManifest` was created as a minimal stub since spec 050 is not implemented. The manifest reading path is tested only indirectly.
- **Mutation testing**: No mutation tool is configured in the tdd-profile. Only 3 deliberate mutants were sampled.
- **Integration testing**: No slow-tier integration test was run. The command tests use `Process.run` but with temp-dir fixtures, not a real corpus import.
- **Performance**: No assessment. The spec does not define performance criteria.
- **Carve-out manifest round-trip**: The `CarveOutManifest.add/remove/load` methods are tested indirectly through `ProvenanceAuditor` tests, but have no dedicated unit tests.
