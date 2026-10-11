feature: 1550-reset-stale-corpus-baseline-cache
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
behaviors: 4
proven: 4
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 2 (the issue's fix list items 1 and 2; item 3 is out of scope per the brief)
criteria_covered: 2
mutation_score: n/a # mutation testing not run on this sandbox: the step-spawner's OOM guard kills spawned children at ~300 MB RSS (bug_1345's `resource-limit exit -6` reproduces it); the still-green guard is the hand-built analog — reverting either fix re-fails the pinned tests (B1/B2 re-fail on a surviving corpus cache; B3 re-fails on the runner-error classification)
mutants_survived: 0
suite: fast tier of test/plugins/tdd chunked (models 81, helpers+corpus_economics 53, services 923, commands 533, top-level 217+302 = 2109 passed / 0 failed) + corpus-adjacent command tests 33; dart analyze on changed files: No issues found!; dart format applied
---

# TDD Verification: reset invalidates the corpus baseline cache; compose refuses stale green premises (#1550)

**Verdict: PASS.** `zfa tdd reset` now invalidates the corpus-wide
baseline cache (`.zfa/corpus/run-baseline.json`, spec 069 T004) and the
feature-local `specs/<feature>/tdd/run-baseline.json` alongside the
registry + run-state — announced before acting and reported in the
verdict (`invalidated_caches`) — so the next run re-captures the suite
baseline live instead of resuming from a pre-reset snapshot that claims
the dropped behaviors are green (B1, B1b, B2). Compose now verifies its
green-unit premise against the registry: a unit the cycle-log advertises
green whose registry record is absent refuses with
`outcome=stale-evidence` and a re-derive remedy, never
`outcome=runner-error` (B3).

## Cycle evidence (fresh from real runs)

| phase | command | evidence |
| ----- | ------- | -------- |
| red | `dart test --preset=all test/plugins/tdd/bug_1550_reset_stale_corpus_baseline_test.dart` (pre-fix tree) | `+1 -3` — B1 fails (corpus cache survives reset), B2 fails (`suite baseline: corpus-wide reuse (fingerprint match; spec 069 T004)` printed by the POST-reset run — the issue's exact signature), B3 fails (`outcome=runner-error` for the stale green premise); B1b idempotence guard passes |
| green | same command on the fix | `+4` — all pass (rerun after `dart format` also green) |
| verify | fast tier of `test/plugins/tdd` chunked with kernel cleanup; `dart analyze $(git diff --name-only HEAD -- '*.dart')`; `dart format` | 2109 + 33 = 2142 passed, 0 failed; analyzer `No issues found!`; format applied |

Regression scopes exercised directly: `composition_targets_test` (24
incl. U3 pinning the sibling `missing-anchor-subject` case as unchanged),
`compose_command_test`, `baseline_cache_test` (fingerprint mechanics
untouched), `bug_1380` (reset ownership rules untouched), `bug_1264`,
`bug_1331` ×2, `bug_1324`, `bug_1162`, `make_command_test`,
`corpus_run_plan_test`, `bug_1512`, tdd `json_flag_test` (the additive
`invalidated_caches` verdict detail breaks nothing).

Pre-existing failures observed, each reproduced IDENTICALLY on a stashed
pristine master and therefore out of scope for this fix: `bug_840` ×5
(expects the pre-#969 raw-JSON verdict line), `test/json_flag_test.dart`
(suite load error), `bug_1345` SC-1 (the sandbox OOM guard killing the
spawned compose child — `resource-limit exit -6` at ~300 MB RSS).

## Rubric notes

- Test-first: genuine red → green. The three failing tests were written
  and observed failing BEFORE the lib change; the fix landed and the
  same suite went green with no test edits in between.
- Assertion strength: B1 asserts file absence for BOTH caches, the
  `verdict=reset` line, exit 0, AND the pre-acting announcement; B2
  asserts the driver-level reuse line is absent AND the suite spy fired
  again (a live re-capture, not a skipped baseline); B3 asserts the
  `stale-evidence` outcome, the absence of `runner-error`, the named
  unit, and exit 1. B1b pins idempotence (no crash when the caches are
  already gone).
- Honesty guards: the corpus cache fingerprint logic and the run state
  machine are untouched (constraints), so `baseline_cache_test`,
  `bug_1264`, `bug_1331`, and `bug_1324` staying green is the no-scope-
  creep proof.
