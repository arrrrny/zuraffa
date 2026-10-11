# TDD Verification — 1398-crash-safe-make-interrupt

**Date**: 2026-09-16 · **Branch**: `feat/1398-crash-safe-make-journal-interrupt`
**Issue**: #1398 · **Spec**: [spec.md](../spec.md) · **Test list**: [test-list.md](./test-list.md)
**Evidence**: [cycle-log.md](./cycle-log.md)

This audit was produced from the REAL runs on this branch (commands and
counts quoted verbatim below). No artifact was copied, stubbed, or
back-dated. `zfa tdd verify` is not applicable to this feature (the subject
under test is the zuraffa CLI itself — the loop's own source — so the
LLM-guided fallback path of the TDD extension is the honest audit vehicle).

## 1. Test-first evidence (git history)

- Commit `WIP: sdd-specify-plan-tasks-analyze…` — spec/plan/tasks/analysis
  land BEFORE any implementation.
- The RED runs were executed against the un-implemented tree:
  - Unit tier: `dart analyze test/plugins/tdd/bug_1398_marker_contract_test.dart`
    → 3 errors (uri_does_not_exist, undefined_class 'MakeInterruptMarker').
  - E2E tier: `dart test …/bug_1398_make_interrupt_recovery_test.dart` →
    `+1 -5` (A1 marker-missing after real SIGKILL; A3 marker-not-cleared;
    U6/U7 driver token unknown). U5 passed vacuously pre-implementation and
    was STRENGTHENED (pre-seeded crash residue) so its green is meaningful.
  - Cycle-log red entries predate the implementation commit; the
    implementation commit lands after this audit's green entries.

## 2. Red-phase evidence (cycle-log integrity)

Every behavior in the test list carries a red entry naming the classification
and the captured failure, then a green entry naming the generation steps:

| Behavior | Red classification | Green evidence |
| --- | --- | --- |
| U-marker | compile-error (missing service) | 4/4 pass |
| A-adopt | assertionFailure ×5 (incl. real-SIGKILL marker absence) | 6/6 pass |
| R-guard | n/a (regression sweep — compared against clean master) | identical results |

## 3. Test-smell rubric

- **No assertion-free tests**: every test asserts observable outcomes
  (exit codes, summary tokens, cycle-log hash bindings, marker presence).
- **No tautologies**: A1 reproduces the crash with a REAL subprocess and a
  REAL SIGKILL — the kill window is verified by polling the subject bytes,
  not assumed; the resume asserts the adoption outcome AND the hash binding
  AND the marker consumption.
- **No test-side implementation of the production logic**: the fake zfa
  scripts only exercise the real CLI surface (established fixture pattern);
  the marker/adoption logic under test is production code.
- **Discrimination pairs present**: A1 (crash → adopt) vs A2 (hand-edit →
  refuse) vs A3 (crash+placeholder → refuse) — the acceptance criterion 3
  trichotomy is pinned, not just the happy path.
- **Vacuous-pass fixed**: U5 was redesigned when its pre-implementation run
  passed for the wrong reason (missing marker trivially satisfies
  "cleared"); it now pre-seeds the residue so the green proves consumption.

## 4. Mutation strength (manual assessment — mutation_test harness out of scope for this tier)

The critical mutants and the tests that kill them:

| Mutant | Killed by |
| --- | --- |
| Marker begin removed (no write-ahead) | A1 (marker absent after SIGKILL) |
| Marker never cleared on graceful exit | A3 + U5 (residue persists after refusal) |
| Interrupt arm dropped from the adoption gate | A1 (resume refuses subject-drift) |
| Placeholder gate bypassed for the interrupt class | A3 (vacuous adoption) |
| `pendingFor` ignores the behavior field | U3 (foreign marker adopts) |
| `pendingFor` accepts corrupt JSON | U3 (crash marker widens adoption) |
| Outcome token downgraded to `skipped`/`adopted` | A1 + U6/U7 (token accounting) |
| StepRunner omits the token from the success set | U6/U7 (run stops at make) |
| Driver #986 arm omits the token | U7 (evidence not recorded on disagreement) |

## 5. Acceptance-criteria coverage (spec SC-1..SC-7)

| SC | Requirement | Verdict | Proof |
| --- | --- | --- | --- |
| SC-1 | killed make leaves durable behavior-named marker; no green evidence | **PROVED** | A1 (real SIGKILL, marker asserted, cycle-log negative) |
| SC-2 | resume → adopted-interrupted, exit 0, current-hash green evidence | **PROVED** | A1 (token + hash equality + marker consumed) |
| SC-3 | identical drift without marker still refuses | **PROVED** | A2 (subject-drift, single seeded green entry, no hash binding) |
| SC-4 | marker + placeholder refuses | **PROVED** | A3 (refusal stands, no green entry) |
| SC-5 | resumed run completes; transition in transcript | **PROVED** | U6 + U7 (`result=complete`, `make -> green (adopted-interrupted)` / driver-recorded evidence) |
| SC-6 | graceful exits clear marker; corrupt marker = absent | **PROVED** | U1–U4 (unit contract), U5 + A1 + A3 (live make exits) |
| SC-7 | analyze clean; targeted suites green; pre-existing failures flagged | **PROVED** | §6 below |

## 6. Verification runs (actual commands and counts)

```
dart analyze <7 changed files>            → No issues found!
dart test bug_1398_marker_contract_test   → +4 All tests passed!
dart test bug_1398_make_interrupt_recovery_test --preset=all → +6 All tests passed!
dart test bug_1331_make_adopted_re_drive_test                → +8 All tests passed!
dart test make_command_1036_test bug_828  → +21 -1 (pre-existing, see below)
dart test 1324 + 1345 + 1430              → +25 -4 (pre-existing, see below)
dart test make_command_test               → +30 -10 (pre-existing, see below)
dart format --set-exit-if-changed <changed files> → 0 changed (GATE CLEAN)
```

**Unrelated pre-existing failures (flagged, NOT introduced by this branch)** —
each verified identical on clean master by `git stash` + re-run:

- `make_command_1036_test.dart` A-1036a (1): the #1587 build-skip scheduling
  makes a func-only plan succeed where the test expects generation-error.
- `bug_1324_resume_stale_artifacts_wedge_test.dart` B1;
  `bug_1345_placeholder_re_drive_test.dart` B1+B2, B7;
  `bug_1430_refresh_evidence_test.dart` U-1430-2 (4 total).
- `make_command_test.dart` (10): pre-existing failures on master, identical
  counts and names.

## 7. Verdict

**Gate: PASSED** for this feature's scope.

- 10/10 new tests green (unit + e2e incl. the real-SIGKILL regression the
  issue demands).
- All 7 success criteria PROVED; none unproven.
- Preserved classes (#694 skip, #1036 refusal, #1331 adoption, #1345
  re-entry, #1430 refresh, #1324 wedge, #828 WAL replay) behave
  identically to master.
- 15 pre-existing failures across 5 legacy suites are flagged with evidence
  and are NOT attributable to this branch.

Remediation tasks: none for this feature. The pre-existing failures above
belong to their own issues (#1587-era drift and the #1345/#1430 classes) —
filing them is out of this PR's one-feature scope.
