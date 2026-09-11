---
feature: 1517-func-stale-honest-red-header
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: dfa137c9
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool run; the still-red guard (B3) is the hand-built mutant — reverting the gate re-fails B1/B2 evidence
mutants_survived: 0
suite: fast tier chunked 103/103 chunks (98 OK / 5 slow-tier-only SKIP / 0 FAIL); dart analyze on changed files: No issues found; dart format applied
---

# TDD Verification: func fill reconciles the honest-red header claims (#1517)

**Verdict: PASS.** The `zfa tdd func` dummy fill now leaves the subject
file claiming the state it actually contains: after a declared bool stub
is filled with `return true;` the header and doc comment carry the
scaffolded-dummy claim and zero `honest red` / `UnimplementedError` /
`MINIMAL COMPILABLE` text, with `behavior_id`, `source_criterion`, the
description, the declared-signature fence and the `Declared parameters:`
trace line byte-identical (B1). The legacy no-arg fill reconciles the
same way (B2). The still-red scaffold — a non-renderable declared return
that keeps `throw UnimplementedError('implement per declared signature:
…')` — keeps its honest-red claims, proving the gate rewrites only false
claims (B3).

## Cycle evidence (fresh from real runs)

| phase | command | evidence |
| ----- | ------- | -------- |
| red | `dart test test/plugins/tdd/commands/bug_1517_func_stale_honest_red_header_test.dart` at deb68abe | `+1 -2` — U-1517-1/U-1517-2 fail on the stale claims (printed subject shows `return true;` under the untouched honest-red header); U-1517-3 guard passes |
| green | same command after the func_command.dart fix | `+3` — all pass |
| verify | chunked fast suite (103 chunks) + func regressions (29/29) + analyzer (`No issues found!`) + format | 0 failures; the only `--preset=all` failures (bug_1259 U4/U5/U6, SC-017) fail identically on a stashed clean master (spawn the real `zfa` binary) — pre-existing, unrelated |

## Rubric notes

- Test-first: genuine red → green (the two failing tests were written and
  observed failing BEFORE the lib change; commits deb68abe → dfa137c9).
- Assertion strength: B1/B2 assert absence of every stale marker AND
  presence of the scaffolded-dummy claim AND byte-level preservation of
  five trace lines AND the dummy body itself; B3 asserts the inverse
  state keeps its claims.
- Mutation analog: reverting the `!scaffolded.contains('UnimplementedError')`
  gate (rewriting on still-red fills too) fails B3; deleting the rewrite
  entirely fails B1/B2 — the suite discriminates both directions.
- No test smells: no sleeps, no order dependence, temp fixtures disposed
  in tearDown, exit codes reset.
