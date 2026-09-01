---
feature: tdd-run-cannot-bootstrap-from-evidence
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: ea399d96
behaviors: 4
proven: 0
likely: 3
test_after: 1
not_applicable: 0
no_test: 0
high_smells: 0
criteria_total: 2
criteria_covered: 2
mutation_score: n/a # no mutation tool run; the revert-to-pre-fix mutant was caught by 3/3 new tests
mutants_survived: 0
suite: fast tier 2509 passed / 0 failed (61 chunks OK, 5 slow-tier-only folders skipped); slow driver tier: run_command_test.dart 24/24 (21 pre-existing + 3 new), sc_013 4/4, sc_014 4/4, sc_015 3/3, sc_018 e2e 1/1, corpus_run_command_test 23/23; dart analyze 0 issues; dart format 0 diffs on touched files
---

# TDD Verification: [zfa tdd run] cannot bootstrap from existing evidence — run-state.json starts all pending even when all done (#682)

**Verdict: PASS_WITH_GAPS.** The bug is real on master `ea399d96` and is
fixed on this branch. `_reconcile()` was asymmetric (FR-003 applied in one
direction only): a `done` claim without evidence demoted, but a `pending`
behavior WITH evidence stayed `pending`, so a brownfield project with
complete red+green evidence in `tdd/cycle-log.md` and no (or an
all-pending) `run-state.json` re-drove every already-proven behavior from
`gen` — exactly the issue's report. The fix adds the symmetric promotion:
`pending` behaviors are promoted to their evidence-backed state
(red+green → `done`, green-only → `green`, red-only → `red`, none →
`pending`), with one deliberate exception found during verification: a
behavior pinned by a LIVE in-flight marker is never promoted, because the
crashed run's step must re-enter and re-certify there (the committed A5
resume contract, spec 049). Test + fix land in one commit (repo
convention), so git ordering alone proves only `LIKELY`; the red was
observed in-session before the fix and is quoted below.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — bootstrap from complete cycle-log evidence when run-state.json is absent: all behaviors promoted to done, zero step spawns, exit 0, state persisted | LIKELY | RED (pre-fix, in-session): `Actual: <1>` exit, `run: feature=090-run-driver result=stopped pending=3 red=0 green=0 done=0 stopped_at=B-001:gen` — the driver re-generated a proven behavior and stopped (the issue's symptom). GREEN (post-fix): exit 0, `result=complete pending=0 red=0 green=0 done=3`, `3 already done — skipping`, `stepInvocations()` empty, run-state.json persisted with `done`. The gen outcome was scripted to `error` so a pre-fix run cannot pass by regenerating |
| B2 — the literal issue-title scenario: an all-pending run-state.json with full evidence promotes to all-done, exit 0, zero spawns | LIKELY | RED: failed pre-fix (regenerated, stopped at gen). GREEN: exit 0, `result=complete ... done=3`, no invocations |
| B3 — promotion is evidence-graded: red+green → done (skipped), red-only → red (re-driven from make, never gen), no evidence → pending | LIKELY | RED: failed pre-fix. GREEN: exit 1 with `result=stopped pending=1 red=0 green=0 done=2 stopped_at=B-003:gen`; invocations exactly `['make B-002', 'refactor B-002', 'gen B-003']` — B-001 never re-driven, B-002 resumed at make honoring its red evidence |
| B4 — promotion never overrides a live in-flight marker (resume contract A5/U23 preserved) | TEST_AFTER | guard written during the green phase after the first promotion draft broke `sc_014` A5 (see findings); sc_014 A5 passes: the marked behavior re-enters at its in-flight step (`verify-red B-002` first, no redundant `gen B-002`) |

No pre-existing test was weakened in substance: the only pre-existing
assertion changed is sc_014 A5's step-count pin `hasLength(7)` →
`hasLength(3)` (finding 1) — its discriminating assertions (re-enter at
`verify-red B-002`, no redundant `gen B-002`, exit 0) are untouched and
still pass. No assertion was loosened, no test renamed out of reach, no
threshold lowered.

## Findings

Ordered by severity.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The first promotion draft (promote `pending` unconditionally, mirroring the assessment snippet literally) broke the committed A5 contract: in A5 case 2, B-002 (pending, red-only evidence, live `verify-red` in-flight marker) was promoted to `red`, and in A5's second invocation B-003 — whose red+green evidence had accumulated from case 1 — was promoted to `done` and never driven, so the resume ran 3 steps instead of 7. Root cause: promotion and the in-flight resume contract interact; a live marker means the crashed step must re-run and re-certify. Fix: promotion skips behaviors pinned by a live marker; A5's stale step-count pin updated 7 → 3 with a rationale comment (re-driving the now-proven B-003 from gen is exactly what #682 forbids). The discriminating A5 assertions were kept | sc_014 A5 failed pre-refinement (`Bad state: No element` on `stepInvocations().first`, then `Actual: ['verify-red B-002','make B-002','refactor B-002'] has length of <3>`); passes post-refinement; all 24 run_command_test tests green after the change |
| 2 | LOW | Pre-existing asymmetry, out of #682's scope: a claimed `green` (or `red`) state is not demoted when its evidence later goes missing — only `done` claims demote and only `pending` claims promote. FR-003's "evidence beats state" is thus still partial for mid-cycle claims; noted for a future reconciliation pass | `run_command.dart` `_reconcile()`: the `done` branch demotes; `green`/`red` claims fall through unchanged (pre-existing behavior, unchanged by this fix) |

## Mutation results

No mutation tool run. One deliberate mutant — the exact pre-fix code
(revert `_reconcile`'s promotion branch, i.e. `claimed == done` only) —
was applied in-session BEFORE the fix (that is the recorded RED run) and
caught by all 3 new tests; restoring the fix (the normal green path)
re-ran the full driver tier green.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| promotion branch removed (pre-fix `_reconcile`: demote-only) | B1, B2, B3 | No | 3/3 new tests failed pre-fix — B1/B2 on exit code + summary line, B3 on invocation order; green post-fix |

1 mutant sampled, 1 caught, 0 survived. The in-flight-marker guard (B4) is
additionally exercised by the pre-existing sc_014 A5 contract test.

## Traceability

| Issue criterion | Behaviors | Tests |
| --------------- | --------- | ----- |
| Brownfield project with complete evidence and no run-state.json: `zfa tdd run` skips proven behaviors and exits 0 | B1, B3 | `bug #682: bootstraps from complete cycle-log evidence when run-state.json is absent`, `promotion is evidence-graded ...` |
| All-pending run-state.json with full evidence: promoted, not regenerated | B2 | `bug #682: promotes an all-pending run-state.json when full evidence exists` |

Both criteria are exercised through the real entry point (`RunCommand.run()`
driven in-process via `CliRunner`, with the four step commands spawned as
the fixture's real fake-zfa sub-processes). No test traces to nothing.

## What was not audited

- The `flutter`-tagged tier, and the slow tiers beyond the driver/scenario
  suites listed above (`--preset=all` full run was deliberately avoided on
  this 2-core/4GB agent per dart_test.yaml's own warning).
- `mutation_test` scores — not configured/run for this command.
- `zfa tdd run` against a real brownfield project on disk with 26
  behaviors (the issue's size) — the fixture scales the same semantics
  down to 3 behaviors; no behavioral difference is expected from row
  count, but it was not measured.
- CI workflows; all counts are from local runs in this session
  (Dart 3.13.2 / Flutter 3.47.2 stable, Linux x64).
