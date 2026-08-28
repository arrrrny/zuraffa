---
feature: speckit-cli-commands-10-missing
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 49e049c4
behaviors: 3
proven: 0
likely: 3
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool; deliberate mutant 1/1 caught
mutants_survived: 0
suite: 2 passed, 0 failed (parity test only; ~45s cold)
---

# TDD Verification: Speckit CLI Commands missing from extension manifest

**Verdict: PASS_WITH_GAPS.** Every acceptance criterion is covered by a test that
exercises the real CLI entry point, no `HIGH` smells, and the parity test catches a
regression (deliberate mutant caught). Gaps: test-first evidence is `LIKELY` because
the branch is not yet committed (no git ordering to corroborate the red), and
mutation was sampled on one of three behaviors only.

## Test-first evidence

| Behavior | Class  | Evidence                                                                  |
| -------- | ------ | ------------------------------------------------------------------------- |
| A1       | LIKELY | cycle 1 records red (14 missing) with output; test file + 14 docs added uncommitted, so history order unverifiable |
| A2       | LIKELY | shape invariant added with the suite; never went red in isolation (guards new docs), covered by green |
| A3       | LIKELY | "0 missing" is the same assertion as A1's `expect(missing, isEmpty)`; covered, no distinct red |

## Findings

Ordered by severity. No `HIGH` findings.

| #   | Severity | Finding                                                                                 | Evidence                                      |
| --- | -------- | --------------------------------------------------------------------------------------- | --------------------------------------------- |
| 1   | MED      | A1 and A3 are redundant: A3 ("0 missing") re-asserts A1's `expect(missing, isEmpty)`.   | `extension_command_parity_test.dart:96`       |
| 2   | MED      | Mystery guest: test shells `dart run bin/zfa.dart manifest` and reads on-disk `extension.yml`; deterministic but ~40s and couples to a full CLI compile | `extension_command_parity_test.dart:35`       |
| 3   | LOW      | Hardcoded irregular alias mapping (method_append, feature/scaffold, private-method) encoded in the test; drifts if the extension re-irregularizes a plugin | `extension_command_parity_test.dart:23`       |

## Mutation results

No mutation tool in the profile; deliberate mutant on the highest-risk behavior (A1),
the guard that the whole fix depends on.

| Mutant                                  | Behavior | Survived | Judgment                                  |
| --------------------------------------- | -------- | -------- | ----------------------------------------- |
| removed `provides` entry `cache.adapter` | A1       | No       | Parity test failed with `cache/adapter` missing; restored, green |

One behavior sampled (A1); A2 and A3 were not mutated because A1 already exercises
the same parity path and A2 is a doc-shape invariant. Not exhaustive.

## Traceability

| Criterion | Tests            | End to end |
| --------- | ---------------- | ---------- |
| AC1       | `A1`             | Yes (real `zfa manifest`) |
| AC2       | `A2`             | Yes (reads generated `.md` files) |
| AC3       | `A1`, `A3`       | Yes (parity == 0) |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Git history ordering: the fix is on an uncommitted branch, so `PROVEN` could not be
  established; evidence is `LIKELY`. Committing the test and docs together before PR
  would raise this to `PROVEN` (the cycle log already records the red).
- Full repository suite: only the scoped parity test was run (~45s); `dart test`
  across the repo was not run to keep the cycle fast.
- Coverage tooling: unavailable; branch coverage of the extension files not measured.
- No `plan.md` exists for this bug, so the inner loop was not planned; outer-only
  acceptance behaviors were audited.
