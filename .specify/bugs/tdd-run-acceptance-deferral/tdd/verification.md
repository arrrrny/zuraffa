---
feature: tdd-run-acceptance-deferral
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 9319b13c
behaviors: 5
proven: 0
likely: 3
test_after: 2
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: n/a # no mutation tool; deliberate mutants 2/2 caught
mutants_survived: 0
suite: fast tier 2649 passed / 0 failed / 1 skipped (chunked per directory); slow tdd driver+scenarios 26+7+1+1 passed / 0 failed; dart analyze 0 issues
---

# TDD Verification: `zfa tdd run` blocks on acceptance behaviors — no outside-in deferral (#625)

**Verdict: PASS_WITH_GAPS.** The deadlock is fixed by lazy deferral: phase 1
drives the master uniform cycle in list order and defers an acceptance
behavior only when its `make` reports `unexpressible` — the planner's
by-design refusal of acceptance prose — with the `[run] A1 make -> deferred
(phase 2)` marker; phase 2 re-attempts make + refactor for the deferred
behaviors, where `unexpressible` is a real, honest stop with the units DONE.
The red was observed in-session before the fix (4 tests failing for the right
reason), the real-pipeline e2e (SC-018) is master-identical under the final
design, and 2/2 deliberate mutants on the deferral branch were caught. Gaps:
test + fix land in one commit (repo convention) so git ordering alone proves
only `LIKELY`; 2 of 5 behaviors are TEST_AFTER pins written during the green
phase; and the real-pipeline interaction with `refactor`'s unskippable
full-suite preflight (finding 1) is documented, not fixed — the fix is
confined to the run driver by the bug's hard constraints.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — 1 acceptance + 1 unit: acceptance make unexpressible defers, unit completes, acceptance flips green at phase 2, feature DONE exit 0 | LIKELY | failed pre-fix for the RIGHT reason (driver ran `make A1` before `gen U1`; honest-stop variant deadlocked with `['gen A1','verify-red A1','make A1']`, U1 never started); green post-fix with the exact 9-invocation two-phase sequence, `[run] A1 make -> deferred (phase 2)`, `[run] A1 make -> green (phase 2)`, `result=complete done=2`. Cycle: session transcript; test + fix in one commit, so `LIKELY` not `PROVEN` |
| B2 — acceptance unexpressible at phase 2 honest-stops at A1:make with the unit DONE | LIKELY | pre-fix: stopped at A1:make with `pending=1 red=1 done=0` (the reported deadlock, U1 pending); post-fix: `result=stopped pending=0 red=1 green=0 done=1 stopped_at=A1:make`, state `{A1: red, U1: done}` — bounded, resumable progress |
| B3 — deferral is scoped to the unexpressible signature; any other acceptance make failure still stops (FR-007) | TEST_AFTER | scoping pin written during the green phase (no red-first run); corroborated by deliberate mutant 1 (below), which made exactly this test fail |
| B4 — resume across the phase boundary: acceptance sits RED while the unit completes first; kill during an acceptance make re-enters at the in-flight step | LIKELY (resume) / TEST_AFTER (in-flight) | resume test failed pre-fix on invocation ORDER (`make A1` before `make U1` — list-order re-entry, no deferral); post-fix `['make A1','make U1','refactor U1','make A1','refactor A1']`, A1 RED between phases. The in-flight test passed pre-fix (list order coincides) — a guard, not red-first |
| B5 — no regression: expressible acceptance prose completes master-identically | NOT_APPLICABLE (pre-existing guard) | SC-018 (real-pipeline plan→run e2e, entity-bearing acceptance prose): verified passing on pristine master `9319b13c` (stash/pop), failing under the abandoned eager-deferral design (A1's deferred red test blocked U1's `refactor` full-suite preflight), passing again under the final lazy design. The suite's existing 20 driver tests (all-unit) pass unchanged |

No pre-existing test was weakened: no assertion removed, loosened, renamed
out of reach, skipped, or filtered; no threshold lowered. The only touched
test infrastructure is `helpers/tdd_fixture.dart` (fake zfa gained
multi-attempt outcome configs — additive; single-line configs behave exactly
as before, all pre-existing fixture consumers pass).

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | Real-pipeline interaction (documented, not fixed — "fix ONLY in the run driver" constraint): while an acceptance behavior sits deferred-RED, a UNIT behavior's `refactor` runs the full-suite preflight (spec 048 FR-001/FR-002, unskippable) which includes the red acceptance test, so the run honestly stops at `U1:refactor outcome=not-green` instead of driving the unit to DONE. Compared to pre-fix, progress still improves (A1 certified red + U1 green instead of `stopped_at=A1:make done=0`), the stop is honest and resumable, and `make`'s drift check means a genuinely-unexpressible acceptance behavior will honest-stop at phase 2 anyway — but a corpus project that wants units to reach DONE must either scope its profile `suite` template (project-authored) or amend spec 048. Recommended follow-up, outside this fix's file scope | `refactor_command.dart:148-167` (preflight refusal); interaction verified by reading the real step contracts, consistent with SC-018's mechanics |
| 2 | MED | Phase 2 re-attempts `make` for a genuinely-unexpressible acceptance behavior although the planner is pure (description-based) and must return `unexpressible` again — the re-attempt is the by-design honest-stop certification ("unexpressible at phase 2 is a real, honest stop") but costs one planner call + one drift-check test run per deferred behavior per run | `generation_planner.dart` (pure, description-keyed); accepted per the brief's contract |
| 3 | LOW | The fake zfa's multi-attempt configs count invocations from the fake's log file; a future change to the log format would silently alter attempt semantics (test-infra coupling, fixture-only) | `tdd_fixture.dart` fake script, `ATTEMPTS=$(grep -c ...)` |
| 4 | LOW | The deferral branch duplicates the `advance(row.id, state)` + save pattern of the honest-stop path (three call sites in `_driveBehavior` share the shape); extracted helpers would shrink the method further | `run_command.dart` `_driveBehavior` |

## Mutation results

No mutation tool in the profile; deliberate mutants on the deferral branch in
`run_command.dart` — the highest-risk logic this fix added. One at a time,
restored exactly (byte-identical via saved copy), suite re-run green after
each restore.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| drop the `result.outcome == 'unexpressible'` guard (deferral would engage on ANY failed acceptance make) | B3 | No | scoping test failed: `make A1 boom` deferred instead of stopping (`Expected: ['gen A1','verify-red A1','make A1']` vs actual with `gen U1` started); restored, suite green |
| drop the `deferralAllowed` (phase 1 only) guard (phase 2 would defer instead of honest-stopping) | B2 | No | honest-stop test failed: phase-2 unexpressible deferred, loop exited with non-DONE behaviors (`internal error`), summary never matched `result=stopped ... stopped_at=A1:make`; restored, 26/26 green |

2 mutants sampled, 2 caught, 0 survived. Both probe the same deferral branch;
other branches (reconciliation, concurrency, evidence misfire) are covered by
pre-existing tests and were not mutated here — not exhaustive beyond this
site.

## Traceability

| Criterion (assessment) | Tests | End to end |
| ---------------------- | ----- | ---------- |
| Feature with 1 acceptance + 1 unit: acceptance deferred, unit completes, acceptance flips green, feature DONE exit 0 | B1 (`run_command_test.dart`), SC-013 acceptance-only variant | Driver-level via the repo's scripted fake `--zfa-bin` harness (the canonical surface for driver contracts, specs 049 U19-U29); real-pipeline e2e is SC-018 for the expressible-acceptance path |
| Acceptance unexpressible at phase 2 → honest stop with `stopped_at=A1:make` | B2 | Yes (driver contract, fake harness) |
| Resume across the phase boundary (acceptance in RED after interruption) | B4 (SC-014 ×2) | Yes (in-flight marker re-entry is exercised with a real dead pid) |
| No new failures on the existing suite (hard constraint) | B5 (SC-018 + all pre-existing driver/scenario tests + chunked fast tier) | Yes — SC-018 runs the real `bin/zfa.dart` pipeline end to end |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Git history ordering: test + fix land in one commit (repo convention: a red
  test is committed alongside the implementation that turns it green), so
  `PROVEN` is unreachable; the red was observed in-session pre-fix and the
  session transcript is the corroboration.
- Suite execution environment: the repo-wide fast tier was run CHUNKED per
  directory (`dart test` single-invocation kernel compilation exceeds this
  sandbox's disk/timeout budget; leaked kernel caches were cleaned and disk
  verified ≥80% free after each phase). Fast tier totals: 2649 passed /
  0 failed / 1 skipped across tdd (+220), core+commands+cli+state+utils+
  config+domain+graphql+dda+mcp+migration+logging+session+scripts+
  package_sdk+agent+app_update+benchmark+biometrics+clipboard+device+i18n+
  property+secure_storage+share (+1557), 16 small plugin dirs (+320),
  benchmark+mcp+shadcn+tui+xray+skeleton+slice+usecase (+548),
  regression+integration dirs (+4, everything else in those dirs is
  slow-tagged and excluded by the default tier per `dart_test.yaml`).
- The heavy slow tiers (`--preset=regression/integration/property/benchmark`
  corpus runs that spin temp projects with `dart pub get` + `build_runner`)
  were NOT run — `dart_test.yaml` itself marks them "NOT for CI / cloud
  agents"; the slow-tier surface actually touched by this fix (all six
  `run` scenarios + SC-017 + SC-018) WAS run green (26+7+1+1).
- Pre-existing environment quirk, unrelated to this fix and present on
  pristine master: `mcp_server_plugin_test.dart` passes but leaves a
  dangling SSE server child that holds the invoking shell's pipe open
  (verified passing `+14: All tests passed!` on master `9319b13c`).
- Coverage tooling: not run (profile marks it opt-in, not a gate); branch
  coverage of `_driveBehavior` not measured.
- Finding 1's spec-048 amendment and any corpus profile `suite` scoping:
  explicitly out of scope here; recorded as the recommended follow-up.
