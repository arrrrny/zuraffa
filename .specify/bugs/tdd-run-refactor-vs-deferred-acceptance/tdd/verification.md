---
feature: tdd-run-refactor-vs-deferred-acceptance
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 11de4bfc
behaviors: 6
proven: 0
likely: 4
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: n/a # no mutation tool; deliberate mutants 2/3 caught, 1 judged equivalent
mutants_survived: 0
suite: fast tier 2110 passed / 0 failed (chunked per directory); slow tdd tier 155 passed / 0 failed (incl. SC-018 real-pipeline e2e); dart analyze 0 issues; dart format clean
follow_up: https://github.com/arrrrny/zuraffa/issues/642 # phase-2 acceptance-make composition gap, filed from this verification
---

# TDD Verification: `zfa tdd run` defers acceptance `make` but not `refactor` — features deadlock at U1:refactor (#635)

**Verdict: PASS_WITH_GAPS.** The half-applied deferral is completed: phase 1
now defers ANY behavior's `refactor` while an acceptance behavior sits RED —
decided BEFORE the spawn, because the real spec 048 FR-001 preflight's
`not-green` refusal IS the deadlock — with the `[run] U1 refactor ->
deferred (phase 2)` marker; phase 2 first re-attempts the deferred acceptance
makes (list order; `unexpressible` remains a real, honest stop) and then runs
`refactor` per behavior on the now-fully-green suite, keeping refactor's
absolute-green contract met by construction rather than relaxed. The red was
observed in-session before the fix: a scratch reproduction of the exact bug
report (1 acceptance + 1 unit, fake `refactor U1 -> not-green` standing in
for the real preflight) printed the assessment's deadlock signature verbatim
(`result=stopped pending=0 red=1 green=1 done=0 stopped_at=U1:refactor`,
exit 1), and 5 committed tests (1 new, 4 rescheduled) failed pre-fix for the
right reason — `refactor U1` still invoked in phase 1. The real-pipeline e2e
(SC-018, expressible acceptance) passes master-identically, every pre-existing
driver pin passed unchanged, and deliberate mutants probe the new branch.
Gaps: test + fix land in one commit (repo convention) so git ordering alone
proves only `LIKELY`; and the follow-up the assessment predicted is now
confirmed and filed (#642) — in the real pipeline a deferred acceptance make
cannot actually flip green at phase 2, because the generation planner is pure
and description-keyed, so the phase-2 flip is exercised only through the
scripted fake; not blocking, per the brief.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — 1 acceptance + 1 unit: unit refactor DEFERS while the acceptance sits red; phase 2 flips acceptance green, refactors every behavior per behavior on the fully-green suite; feature all-DONE exit 0 | LIKELY | new `bug 635` driver test failed pre-fix for the RIGHT reason (actual invocations contained `refactor U1` between `make U1` and `make A1` — the scheduling bug); green post-fix with the exact 9-invocation sequence, `[run] U1 refactor -> deferred (phase 2)`, `[run] A1 refactor -> clean (phase 2)`, `[run] U1 refactor -> clean (phase 2)`, `result=complete done=2`. The scratch repro additionally reproduced the real deadlock signature verbatim pre-fix (see verdict). Test + fix in one commit, so `LIKELY` not `PROVEN` |
| B2 — acceptance unexpressible at phase 2 is an honest stop at A1:make with the unit GREEN (its refactor deferred, never attempted) | LIKELY | updated honest-stop test failed pre-fix (actual: `refactor U1` attempted, U1 left `done`, `red=1 green=0 done=1`); post-fix: invocations end at `make A1`, `result=stopped pending=0 red=1 green=1 done=0 stopped_at=A1:make`, state `{A1: red, U1: green}` — bounded, resumable, and the doomed refactor was never spawned |
| B3 — acceptance-only feature: phase 2a re-attempts every deferred make in list order, phase 2b refactors on the green suite | LIKELY | updated SC-013 test failed pre-fix on order (`refactor A1` before `make A2`); post-fix `[..., make A1, make A2, refactor A1, refactor A2]`, `result=complete done=2` |
| B4 — resume across the phase boundary: acceptance RED + unit RED re-drive, unit refactor defers, then completes; kill during an acceptance make re-enters at the in-flight step | LIKELY (resume) / NOT_APPLICABLE (in-flight guard) | updated SC-014 boundary test failed pre-fix on order; post-fix `['make A1','make U1','make A1','refactor A1','refactor U1']`. The in-flight test (A1 red in-flight make + U1 DONE) passed pre- and post-fix unchanged — `['make A1','refactor A1']` — a guard, not red-first |
| B5 — no regression: unit-only features still run refactor PER BEHAVIOR in phase 1 as before | NOT_APPLICABLE (pre-existing guards) | U19 (exact 4-step-per-behavior order), U20–U24, U26–U29, SC-013 A1/A3, SC-014 A4/A5, SC-015, SC-016 all passed pre-fix AND post-fix byte-identical expectations — the deferral condition never fires without a RED acceptance |
| B6 — no regression: expressible acceptance prose completes master-identically (real pipeline) | NOT_APPLICABLE (pre-existing guard) | SC-018 (plan → run e2e with the REAL `bin/zfa.dart` pipeline, entity-bearing acceptance): passed post-fix in 4:14, `result=complete done=2` exit 0, both subjects wired, exactly one red+green evidence entry per behavior. An expressible acceptance reaches DONE in phase 1 before any unit runs, so no acceptance is RED when its own refactor comes due |

No pre-existing test was weakened: no assertion removed, loosened, renamed
out of reach, skipped, or filtered; no threshold lowered. The two `bug 625`
tests and the SC-013/SC-014 phase-boundary tests were RESCHEDULED to the
corrected contract — their pre-fix expectations encoded the bug being fixed
(`refactor U1` executed in phase 1 against a knowingly-red suite), which the
fake zfa masked by always succeeding; each was re-run red before the fix and
green after, with the honest-stop semantics they guard (FR-007, bounded
resumable stops) strengthened, not loosened.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | Phase-2 acceptance make cannot actually flip green against the units in the real pipeline: the generation planner is pure and description-keyed (`plan()` inspects only the behavior description), so a genuinely-unexpressible acceptance make is unexpressible at phase 2 too — the re-attempt is the honest-stop certification, and the flip-green path exists only in the scripted fake. This is the follow-up the #625 assessment predicted; CONFIRMED by reading `generation_planner.dart` and `make_command.dart` during this verification and FILED as issue #642. Not blocking this fix (the brief scopes this PR to step scheduling) | `generation_planner.dart` `plan()`/`_unexpressibleReason`; `make_command.dart` (no phase context passed); #642 |
| 2 | LOW | Transient test-isolation flake observed once during verification: `wire_command_test.dart` U-W7 failed in one full-folder parallel fast-tier run (1 in 6 on this branch), passed in isolation, on 4 subsequent folder re-runs, and on pristine master (3/3). The file and the behavior it pins are untouched by this diff; a filesystem-isolation race under load, not a regression | session run logs; `git diff` shows no `wire` changes |
| 3 | LOW | `deferralAllowed` on the refactor-deferral guard is not load-bearing: with the two-stage phase 2, phase 2a always flips (or honest-stops) every red acceptance before the refactor pass runs, so the guard is false in phase 2b by construction — deliberate mutant 2 (dropping it) proved EQUIVALENT. Retained as defensive intent documentation mirroring the make deferral | mutation table below; `run_command.dart` phase 2a/2b ordering |
| 4 | LOW | The pre-spawn refactor deferral duplicates the `advance(row.id, state)` + save pattern already shared by the honest-stop and make-deferral paths (four call sites in `_driveBehavior` now share the shape); extracted helpers would shrink the method | `run_command.dart` `_driveBehavior` |

## Mutation results

No mutation tool in the profile; deliberate mutants on the new deferral
branch in `run_command.dart` — the highest-risk logic this fix added. One at
a time, restored exactly (byte-identical via md5-verified saved copy), suite
re-run green after each restore.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| drop the `_hasRedAcceptance` guard (every refactor in every phase defers) | B5 | No | 19 failures across U19–U21, SC-013 A1: unit-only features never ran refactor (`gen A1, verify-red A1, make A1, gen U1...` with `refactor` missing); restored, suite green |
| drop the `deferralAllowed` guard (phase 2 could defer refactors) | B1/B2 | YES — equivalent | phase 2a always flips or honest-stops every red acceptance before phase 2b runs, so `_hasRedAcceptance` is false in the refactor pass by construction; the mutant changes no observable behavior (see finding 3). Judged equivalent, not a test gap |
| replace `_hasRedAcceptance(rows, updated)` with `row.kind == unit` (the remediation's literal "phase 1 drives units through make only", misread as kind-based rather than suite-based) | B5 | No | 7 failures across U19/U22/U23/U28 and SC-014 A4/A5: unit-only refactor ordering changed (refactor no longer per-behavior in phase 1); restored, suite green |

3 mutants sampled: 2 caught, 1 judged equivalent, 0 true survivors. All probe
the same new branch; reconciliation, concurrency, and evidence-misfire
branches are covered by pre-existing tests and were not mutated here — not
exhaustive beyond this site.

## Traceability

| Criterion (assessment) | Tests | End to end |
| ---------------------- | ----- | ---------- |
| Acceptance-bearing feature drives to all-DONE: defer make + refactor → phase-2 acceptance green → final refactor per behavior → exit 0 | B1 (`run_command_test.dart`), B3 (SC-013 acceptance-only variant), B4 (SC-014 resume variant) | Driver-level via the repo's scripted fake `--zfa-bin` harness (the canonical surface for driver contracts, specs 049 U19–U29); real-pipeline e2e for the expressible path is SC-018 (B6) |
| Unit-only features still run refactor per behavior as before (no regression) | B5 (U19–U29, SC-013 A1/A3, SC-014 A4/A5, SC-015, SC-016) | Yes — exact invocation-order pins, unchanged from master |
| Refactor's absolute-green preflight untouched (spec 048 FR-001) | `git diff` scope (refactor_command.dart: 0 changes) + B1 (refactor runs only on the fully-green suite by construction) | Yes — the fix defers scheduling; the preflight contract itself is never relaxed |
| Other step failures still stop honestly (FR-007) | B2 + U24 failure matrix + SC-015 | Yes |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Git history ordering: test + fix land in one commit (repo convention: a red
  test is committed alongside the implementation that turns it green), so
  `PROVEN` is unreachable; the red was observed in-session pre-fix (5 failing
  committed tests + the verbatim scratch deadlock repro) and the session
  transcript is the corroboration.
- Suite execution environment: the repo-wide fast tier was run CHUNKED per
  directory (`tools/run_tests_chunked.sh` + per-chunk completion for the
  chunks derailed by the known dangling-SSE quirk in `test/plugins/mcp`, see
  below): 2110 passed / 0 failed across 57 chunks with tests; `test/property`
  contains no fast-tier tests (0 ran, by tier design). The slow TDD tier was
  run in 5 batches: 155 passed / 0 failed, including all six `run` scenarios,
  every command suite, and the SC-018 real-pipeline e2e. Heavy presets
  (`--preset=regression/integration/property/benchmark` corpus runs that spin
  temp projects with `dart pub get` + `build_runner`) were NOT run —
  `dart_test.yaml` marks them "NOT for CI / cloud agents"; the slow-tier
  surface touched by this fix WAS run green.
- Known environment quirk (pre-existing, on master too): the
  `test/plugins/mcp` chunk's SSE server test leaves a dangling child that
  consumes the chunk runner's subsequent output, derailing a single
  `run_tests_chunked.sh` invocation after that chunk; the remaining chunks
  were completed individually and all passed. Already documented in the #625
  verification.
- Finding 2's flake: 1 occurrence in 6 parallel full-folder runs on this
  branch; root cause not chased (untouched file, passes in isolation, on
  re-runs, and on master 3/3).
- Coverage tooling: not run (profile marks it opt-in, not a gate); branch
  coverage of `_driveBehavior` and `_hasRedAcceptance` not measured.
- Finding 1's composition surface (a phase-2-capable acceptance make):
  explicitly out of scope here; filed as #642 with a suggested direction.
