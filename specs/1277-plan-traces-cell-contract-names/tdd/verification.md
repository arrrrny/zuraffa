# Verification: 1277-plan-traces-cell-contract-names

Audit report written by the `/speckit.tdd.verify` discipline. Audits the
cycle log against the test list, re-runs the recorded evidence, and
samples deliberate mutants (Phase 4 fallback — no mutation tool is wired
in this repo's stack profile).

## Phase 1 — test-first audit

- Every behavior in `tdd/test-list.md` carries a recorded cycle in
  `tdd/cycle-log.md`. No list line without a log entry; no log entry
  without a list line.
- Red evidence exists for every BEHAVIOR-CHANGING cycle: Cycle 1 (U1)
  and Cycle 4 (U4) carry verbatim failure output captured before the
  enabling change. Cycles 2/3/5/6/7 are verifications and compat fences
  whose enabling change landed in Cycles 1/4; each says so explicitly in
  the log (the honesty rule) instead of staging artificial reds.
- The suite baseline (12 plan/routing/1259 suites, 118 tests) was green
  before the work and green after: no pre-existing failures were
  present, none were introduced, none hidden.

## Phase 2 — re-run evidence

Recorded commands re-run in the delivered tree (cloud-agent scope: only
suites covering the modified file `plan_command.dart` plus the new
suite):

| Command | Result |
| --- | --- |
| `dart test test/plugins/tdd/commands/plan_traces_cell_1310_test.dart` | 7 passed, 0 failed |
| `dart test` on the 12 regression suites (see Baseline in the cycle log) | 118 passed, 0 failed |
| `dart analyze lib/src/plugins/tdd/commands/plan_command.dart test/plugins/tdd/commands/plan_traces_cell_1310_test.dart` | No issues found |
| `dart format .` | zero remaining diffs (`git diff --stat` clean after format) |

## Phase 3 — acceptance criteria vs evidence

| Criterion | Status | Evidence |
| --- | --- | --- |
| AC-1 declared path reachable (gen emits declared signature + real outcome assertion; make completes without vacuous-green) | PROVED | U5: subject carries `create(String title) -> bool` provenance + `bool subject_u1(String title)` declared signature; test asserts `expect(result, isA<bool>())`, no `vacuous-guard` marker. U6: plan -> gen -> verify-red -> make certifies green (exit 0), no `outcome=vacuous-green`. |
| AC-2 legacy single-file cells carry the full trace set | PROVED | U1 (red -> green): cell `FR-001, TodoRepository.create` in test-list.md. |
| AC-3 lane plan cells carry the full trace set | PROVED | U2: `FR-001, TodoRepository.create` in 04-ENGINE.md unit row. |
| AC-4 criterion-only fallback preserved; reconciliation accepts the new shape | PROVED | U3: untraced FR emits `| FR-001 |` only, no invented names. U4 (red -> green): re-plan keeps the prior U2 id against a full-trace-set prior list. U7: legacy criterion-only prior list still reconciles. |
| SC-1 | PROVED | = U1 + U2 + U5 evidence. |
| SC-2 | PROVED | = U6 evidence (make certifies on the dummy-bool subject because the test carries the real outcome assertion). |
| SC-3 | PROVED | = U3 evidence. |
| SC-4 | PROVED | = U4 + U7 evidence (id preservation; A/U states re-emit PENDING by design, out of scope per the spec's own note). |
| SC-5 | PROVED | = Phase 2 table (analyze clean, targeted suites green). |

Not proved (honest gaps):

- `zfa tdd run` was not executed as a whole two-cycle driver; the
  issue's run-level symptom is covered compositionally by
  U5 (gen half) + U6 (make half, the exact vacuous-green refusal point)
  through the same CLI entrypoints the runner shells out to.
- make's `tdd func` repair subprocess crashed in this sandbox on a Dart
  VM isolate quirk (`type 'Null' is not a subtype of type 'SendPort'`)
  when invoked on a failing baseline — an environment failure unrelated
  to the fix (the certify-green path under test does not shell that
  subprocess).

## Phase 4 — mutation sampling (deliberate mutants)

| Mutant | Change | Result |
| --- | --- | --- |
| M1 | `_tracesCell` returns the criterion id unconditionally (drops contract names) | KILLED — suite 3 passed / 4 failed (U1, U2, U5, U6) |
| M2 | Reconciliation keys by the full cell instead of the leading criterion token | KILLED — U4 failed with the renumbering symptom |

After each mutant the working tree was restored byte-identical
(`diff` clean) and the suite re-run green (7 passed).

## Constraint audit (FR-004)

- `git diff --name-only HEAD` at delivery touches ONLY:
  - `lib/src/plugins/tdd/commands/plan_command.dart` (the named fix
    site: `_derivedLaneRows`, the legacy single-file writers, the
    reconciliation read, the shared `_tracesCell` renderer)
  - `test/plugins/tdd/commands/plan_traces_cell_1310_test.dart` (new
    suite)
  - `specs/1277-plan-traces-cell-contract-names/**` (spec-kit artifacts)
- `RoutingResolver`, `DeclaredRouting`, `gen`, `make`, the contract
  scanner and the verify gates are untouched; the 118-test regression
  fence over their suites is green.

## Suite health

- Baseline: green (118 targeted tests) at `37c38f2` before any change.
- Delivered: green (118 + 7 new). No skipped, no quarantined, no
  deleted tests. Pre-existing unrelated failures: none observed in the
  scoped suites.
