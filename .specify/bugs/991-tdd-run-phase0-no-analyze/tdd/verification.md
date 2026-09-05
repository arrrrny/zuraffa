---
feature: .specify/bugs/991-tdd-run-phase0-no-analyze (bug #991, pinned per bug extension TDD mode)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 77e69f2 + fix session working tree (branch fix/991-tdd-run-phase0-no-analyze, pre-PR)
behaviors: 6
proven: 6
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 2/2 caught # scope: the phase-0 build spawn in run_command.dart — M1 (gate reverted to bare build) killed by U-991, M2 (genuine-build-failure stop neutered) killed by U-991b; manual deliberate mutants, each killed by a named test
mutants_survived: 0
suite: "bug-829 group 6/6 (2 new #991 tests + 4 amended/unaffected controls); run_command_test.dart full file 41 passed / 1 failed (bug #691 — pre-existing on clean master, reproduced with the fix stashed); chunked fast suite 74/74 chunks (70 PASS / 4 SKIP no-fast-tier / 0 FAIL); dart analyze: identical to master (345 pre-existing issues, 0 new, none in touched files); dart format: 0 diffs (`dart format lib test` clean, `--set-exit-if-changed` exit 0)"
---

# TDD Verification: bug #991 — `zfa tdd run` phase-0 build fails on any `dart analyze` warning (no `--no-analyze` forwarded)

**Verdict: PASS.** The red→green cycle is real and captured verbatim on both
new behaviors, the failure the issue reports is reproduced deterministically
at the driver level (identical output shape to the issue's repro), both
deliberate mutants were killed, the honest-stop contract survives intact,
and the no-regression surface (analyze stays out of phase 0 but everywhere
else it was) is asserted.

## Provenance note

The runbook asserted `.specify/bugs/991-tdd-run-phase0-no-analyze/issue.md`
and `assessment.md` were "already committed (if exists)" — no such records
exist in the tree (213 slugs searched); they were created by this session
from the runbook's section-3 record, per the #942 precedent. Unlike #942,
GitHub issue #991 **is reachable** from this session (API 200, state open)
and its body matches the runbook verbatim — including the repro output
shape `[run] phase-0 build -> failed` / "the run stops before any behavior
is driven", which the RED capture below reproduces line-for-line at the
driver level.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| B1 (U-991) — with pre-existing analyze warnings failing the bare `zfa build` gate, the run completes: the phase-0 build spawn carries `--no-analyze`, phase-0 reports `build -> ok`, behaviors are driven | PROVEN | RED captured (pre-fix run, this session): `Expected: <0> Actual: <2>` with driver output `[run] phase-0 build -> failed` / `zfa tdd run: phase-0 build failed (exit 1) — the run stops before any behavior is driven (bug #829).` / `result=runner-error ... stopped_at=phase-0:build` — bug #991's exact failure shape (matches the issue repro output). GREEN post-fix: exit 0, `[run] phase-0 build -> ok`, the argv log carries the `build --no-analyze` spawn, `stepInvocations()` non-empty. |
| B2 (U-991b) — a genuine build failure on the `--no-analyze` invocation still stops the run honestly (`runner-error`, `stopped_at=phase-0:build`, no behavior driven) | PROVEN | RED captured (pre-fix tree, lib fix stashed, test present): `Expected: <2> Actual: <0>` with `[run] phase-0 build -> ok` — the bare spawn never reaches the scripted genuine failure. GREEN post-fix: exit 2, `phase-0 build -> failed`, `result=runner-error`, `stopped_at=phase-0:build`, `stepInvocations()` empty. |
| B3 (U-829c†) — phase-0 spawn order unchanged: entity create first, then exactly ONE build, before the first gen | PROVEN | argv assertions: `argv[0]` contains `entity create -n User` with both `--field`s; `argv[1] == 'build --no-analyze'`; `argv[2]` contains `tdd gen`; build-spawn count == 1. |
| B4 (U-829d†) — an existing entity is REUSED: no entity create, no build spawn, hand-tuned file untouched | PROVEN | unchanged assertions; argv now asserted as "no line starts with `build`". |
| B5 (U-829e) — a failed entity create still stops the run (unaffected control) | PROVEN | exit 2, `stopped_at=phase-0:entity`, no behavior driven — unchanged and passing. |
| B6 (U-829f†) — no declared entities → no phase-0 spawn at all (every pre-829 run unchanged) | PROVEN | output contains no `[run] phase-0`; no entity-create, no build in the argv log. |

† Three pre-existing argv assertions were amended deliberately: the expected
argv changed with the fix (bare `build` → `build --no-analyze`); each
amendment asserts a strictly more-specific argv. No assertion was weakened;
no assertion was deleted.

## Deliberate mutants (both killed, run against the fixed tree)

| Mutant | Change | Killing test | Observed |
| --- | --- | --- | --- |
| M1 | `_runEntityPhaseZero`: spawn reverted to bare `['build']` (the fix undone) | B1 (U-991) | FAIL — `Expected: <0> Actual: <2>`, `result=runner-error ... stopped_at=phase-0:build` (the bug reproduces) |
| M2 | `_runEntityPhaseZero`: build-failure stop neutered (`if (false && build.exitCode != 0)`) | B2 (U-991b) | FAIL — `Expected: <2> Actual: <0>`: a genuine build failure would be papered over and the run would continue |

## Success criteria: PROVED vs NOT PROVED

PROVED (each by an actual run in this session):

1. **Phase-0 build does not fail on pre-existing analyze warnings** — U-991
   red→green; the driver forwards `--no-analyze` on the phase-0 build spawn.
2. **Analyze is NOT removed from verify/refactor (hard constraint)** — the
   diff touches only the phase-0 spawn argv + docs + tests; `zfa build`'s
   default `--analyze` (build_command.dart), the make/gen pipeline build
   steps and their #942 gate, and the refactor passes' build commands are
   byte-identical to master.
3. **No regression** — bug-829 group 6/6; chunked fast suite 74/74 chunks
   (70 PASS / 4 SKIP / 0 FAIL); `dart analyze` identical to master (345
   pre-existing, 0 new, none in touched files); `dart format lib test`
   clean with zero remaining diffs.

NOT PROVED (honest gaps):

1. **The literal repro environment** — the issue's repro is
   `/Users/ahmettok/Developer/forklift` with its 41 warnings; that repo
   state is not reachable from this session. The failure was reproduced
   deterministically at the driver level (same harness as the bug-829
   suite) with the gate failure scripted exactly as the issue reports it;
   the fix removes the gate from the spawn, which fixes the reported
   failure class regardless of the target repo's severity distribution.
2. **Slow tiers** — `--preset=all` regression/integration/property/
   benchmark tiers were not run: dart_test.yaml explicitly forbids them on
   cloud/disposable agents (temp projects + build_runner fill several GB
   under /tmp).
3. **Pre-existing failure left as found** — `bug #691` (verify-red
   unexpected-green transition) fails identically on clean master
   (reproduced with the fix stashed); out of scope for this one-PR bug fix.

## Residual risks

- The fake-zfa harness keys non-driver invocations by argv, so the
  driver-level tests prove the spawn contract, not the real analyzer's
  output handling — the real gate behavior remains covered by the
  build_command tests (untouched by this diff).
- Targets running a zfa binary older than this fix must rebuild before the
  phase-0 behavior changes (the fix is in the CLI itself, not the driver
  config).
