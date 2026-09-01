---
feature: tdd-make-fails-unit-behaviors
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 029f6785
behaviors: 3
proven: 0
likely: 3
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool; deliberate mutant 1/1 caught (6 failing assertions across 2 tiers)
mutants_survived: 0
suite: fast tier chunked 2351 passed / 2 pre-existing failures; planner 20/20; make --preset=all 24 passed / 2 pre-existing; tdd scenarios (real-pipeline tiers) green except pre-existing
---

# TDD Verification: `zfa tdd make` fails on unit behaviors (U5+) (#718)

**Verdict: PASS_WITH_GAPS.** The unit-behavior dispatch is now keyed on the
behavior id's kind encoding (`U<n>`), routed to the plain-function generator
(`zfa tdd func`) before any description-keyed branch can hijack it, and the
routing contract is pinned at three independent tiers: exact-argv unit pins on
the planner, an end-to-end `zfa tdd make U5` repro that fails with the issue's
verbatim `generation-error` signature when the dispatch regresses, and the
real-pipeline plan→run e2e (sc_018) that drives a `U<n>` behavior green through
`bin/zfa.dart`. A deliberate mutant replaying the original bug was caught by
both the unit and e2e tiers. Gaps: test-first evidence is `LIKELY` (red ran
before the fix in-session, but test + fix land in one commit so git ordering
cannot independently prove it), and mutation was a single deliberate mutant,
not a scored run.

## Test-first evidence

| Behavior | Class  | Evidence |
| -------- | ------ | -------- |
| B1 — a unit behavior (`U<n>`) plans `tdd func <id>` + `build` regardless of entity/CRUD keyword prose; non-unit ids keep description-keyed routing | LIKELY | cycle-log Cycle 1 records the red (`['make', 'u5', '--no-entity']` instead of `['tdd', 'func', 'U5']`) before the fix; test + fix land in one commit, so history ordering is `LIKELY`, corroborated by the log |
| B2 — end-to-end `zfa tdd make U5` goes green through the func step and NEVER dispatches `make <slug>` | LIKELY | cycle-log Cycle 1 records the e2e red with the issue's verbatim signature (`plan: 2 step(s)` / `target test still fails after generation (exit 1)` / `outcome=generation-error`); green after fix |
| B3 — the real pipeline drives a plan-written `U<n>` behavior to DONE (sc_018 real-pipeline e2e) | LIKELY | sc_018 passed pre-fix for a different route (entity branch + `tdd wire`); post-fix it passes with the func route (all-DONE, exit 0, 5m22s). Its assertion change is an assertion-TIGHTENING to the functional stub marker, documented in the log |

No pre-existing test was weakened. The two retargeted pins (bug-696 group
`U5/U6/U7` → `B-005/B-006/B-007`; bug-657 U11 `U3` → `B-003`) keep their
original assertions byte-for-byte — only the behavior id moved, because `U*`
ids no longer reach the CRUD branch the #696 fix serves; the #696
name-derivation contract stays pinned on the ids that still exercise it
(U-718e additionally pins the dashed `U-6` CRUD contract). sc_018's
`isNot(contains('UnimplementedError'))` became
`isNot(contains('throw UnimplementedError'))` — the file-level text check was
stricter than the functional contract it proxies (func's documented
declaration-only replacement leaves the gen stub's prose doc comment); the
functional marker distinguishes an unimplemented stub from a scaffolded one in
both directions.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | Two make-level tests are stale relative to bug #657's function-verb list and fail at the branch base (`B-200` "parse bespoke DSL syntax" now plans `tdd func` → `generation-error`, not `unexpressible`; "names the verb" likewise). Pre-existing, verified at base, NOT fixed here per the one-bug-one-PR constraint — but they assert outcomes the planner can no longer produce for ANY input, so they will stay red until retargeted or retired | `make_command_test.dart` US4 bug-657 + spec-052 A11/U17 |
| 2 | MED | `zfa tdd func` leaves the gen stub's `/// Throws [UnimplementedError] until the real implementation lands.` doc comment in place (declaration-only replacement contract). Functionally harmless (test green, run loop DONE), but the stale prose misleads readers AND makes func's own `hasUnimplementedError` idempotency probe report "unrecognized shape" instead of `already-implemented` on a resumed pipeline | `func_command.dart` `_stubSignature`/replacement; surfaced by routing real gen-shaped stubs through func |
| 3 | LOW | sc_018's stub assertion is now a functional marker rather than a full-file text scan; a stub variant that throws UnimplementedError indirectly (e.g. via a helper) would slip past it | `sc_018_plan_run_loop_e2e_test.dart` |

## Mutation results

No mutation tool in the profile; deliberate mutant on the highest-risk
behavior (B1/B2 — the dispatch the whole fix depends on).

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| `_unitBehaviorId` pattern `^U\d+$` → `^X\d+$` (unit dispatch disabled — the original bug replayed) | B1 + B2 | No | 5 of 6 planner pins failed (U-718a re-produced `['make', 'u5', '--no-entity']`) AND the e2e make repro failed with `outcome=generation-error` exit 1; U-718e correctly unaffected (it pins non-unit routing, untouched by the mutant). Restored exactly; planner 20/20 and make 24/2-green re-confirmed |

1 mutant sampled, 1 caught. Not exhaustive beyond the dispatch site; the
func-surface plan builder was already pinned by the bug-657 group.

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| Issue #718 acceptance: `zfa tdd run` no longer stops at the first unit behavior with `outcome=generation-error` | B1 (planner pins), B2 (make e2e), B3 (sc_018 real-pipeline loop) | Yes — B3 runs the real `bin/zfa.dart` through plan→run to all-DONE |
| Assessment remediation: unit behaviors (U*) route by kind/prefix to the #657/#660 plain-function surface, not the entity generator | B1, B2 | Yes — B2 asserts the fake-zfa log carries `tdd func` and zero `make <slug>` lines |
| No regression for acceptance/legacy ids (#696 name derivation, #642 composition) | U-718e + bug-696 group + sc_021 composition e2e (passed) | Yes — sc_021 runs the real pipeline |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Git history ordering: test + fix land in one commit (repo convention per
  the #609 verification), so `PROVEN` is unreachable; evidence is `LIKELY`
  with the cycle log as corroboration.
- Full-suite execution environment: the repo-wide fast tier was run chunked
  per directory (`tools/run_tests_chunked.sh` semantics; a single
  `dart test test` kernel cache overflows this sandbox). Fast tier: 2351
  passed / 2 failed, both pre-existing at base (`refactor_passes_test.dart`
  U2 + bug-#689 entrypoint, verified with the branch changes stashed).
  Slow-only folders (benchmark, integration, property, core/dependencies,
  tdd scenarios) are excluded from the fast tier by design; the affected
  slow tiers were run explicitly: `make_command_test.dart --preset=all`
  24/2 (both pre-existing, verified at base), scenarios sc_001–sc_021 green
  except sc_011 A6 + sc_012 A1/A9 (verified pre-existing at base),
  generation_planner 20/20.
- `dart analyze`: no issues on the full repo with the branch applied.
  `dart format`: zero diffs on the four touched files; two unrelated files
  with pre-existing formatting drift elsewhere in the repo were left
  untouched (out of scope).
- Coverage tooling: not run; branch coverage of the planner not measured.
- The run driver was NOT modified (assessment open question: #718 vs #693
  same-root-cause). Current code has no `drift` outcome to misclassify —
  already-green is the `skipped` transition (issue #694) and the run driver
  advances past it — so #718 is the dispatch-side bug only; #693's
  run-side concern is not reproducible against this tree.
- The stale `/// Throws [UnimplementedError]` doc comment left by func
  (finding 2) was not fixed: it is func-command behavior, outside this
  bug's make-dispatch scope. Flagged for a follow-up.
- The two stale make-level tests (finding 1) were not retargeted: they
  fail identically at the branch base and fixing them would blur this
  PR's diff. Flagged for a follow-up.
