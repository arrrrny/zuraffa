# Cycle Log: 1652-defer-phase1-refactor-to-batch

Baseline: Dart SDK 3.13.4, master @ 4b31c2bc (includes the merged PR
#1662 digest gate). Test subject:
`lib/src/plugins/tdd/commands/run_driver_core.dart` (`_driveBehavior`).
New driver suite:
`test/plugins/tdd/issue_1652_defer_phase1_refactor_test.dart`
(scripted fake zfa, fast tier).

## Cycle: RED — issue 1652 behaviors fail against the pre-fix driver (5 red / 1 green-by-design)

- behavior: A1, A1b, A2, A4, A5 (red); A3 (green by design)
- kind: red
- classification: assertionFailure
- criterion: AC-1, AC-2, AC-4, AC-5 (FR-001/FR-002 scheduling)
- command: `dart test test/plugins/tdd/issue_1652_defer_phase1_refactor_test.dart`
- exit: 1
- at: 2026-09-16T00:55:00Z
- output (A5's run transcript, the defect made visible — B-001's phase-1
  refactor spawns right after its make, then B-002's make stops the run):
```
[run] B-001 gen -> ok
[run] B-001 verify-red -> certified
[run] B-001 make -> green
[run] B-001 refactor — format + analyze + re-proof
[run] B-001 refactor -> clean
[run] B-002 gen -> ok
[run] B-002 verify-red -> certified
[run] B-002 make -> not-certified-red
run: feature=092-defer-phase1-refactor result=stopped pending=0 red=1 green=0 done=1 stopped_at=B-002:make
```
- failing tests (pre-fix, exactly the predicted set):
  - A1: forward run defers every same-drive-make refactor — RED (refactor
    spawned between makes: `firstRefactor < lastMake`)
  - A1b: #694 skip transition defers — RED (same)
  - A2: all makes precede all refactors — RED (argv interleaved)
  - A4: blocked-contract composition defers the unit — RED (phase-1 spawn
    happened; the `--exempt-behaviors` part held as designed)
  - A5: honest stop with deferred refactors — RED (B-001 refactor spawned)
  - A3: resume re-entry at refactor still spawns in phase 1 — GREEN BY
    DESIGN (the pre-feature window; the bug-1624 contract holds)

Red verdict: the driver spawns one eager phase-1 refactor per made
behavior. The fix lands the deferral in `_driveBehavior` (T101).

## Cycle: GREEN — the deferral lands in _driveBehavior (6/6 green)

- behavior: A1, A1b, A2, A3, A4, A5
- kind: green
- classification: assertionFailure -> pass
- criterion: AC-1..AC-5 (FR-001..FR-005)
- command: `dart test test/plugins/tdd/issue_1652_defer_phase1_refactor_test.dart`
- exit: 0
- at: 2026-09-16T01:20:00Z
- output:
```
00:46 +6: All tests passed!
```
- change (T101, `run_driver_core.dart` `_driveBehavior` — the ONLY
  production change):
  1. new local `madeGreenThisDrive` flag;
  2. deferral gate extended: `madeGreenThisDrive ||` ahead of the
     unchanged suite-global predicate (`_hasRedBehavior` ||
     `_hasPendingWithArtifacts`);
  3. flag set in BOTH make success arms — the generic success path
     (`step == 'make'`) and the #694/#1331/#1345/#1398
     skip/adopt/adopted-placeholder/adopted-interrupted terminal arm;
  4. deferred arm body untouched (same advance/save/print/emitStep).
- A1 transcript (the AC-1 shape post-fix):
```
[run] B-001 gen -> ok
[run] B-001 verify-red -> certified
[run] B-001 make -> green
[run] B-001 refactor -> deferred (phase 2)
[run] B-002 gen -> ok
[run] B-002 verify-red -> certified
[run] B-002 make -> green
[run] B-002 refactor -> deferred (phase 2)
[run] B-001 refactor -> clean (phase 2)
[run] B-002 refactor -> clean (phase 2)
run: ... result=complete pending=0 red=0 green=0 done=2
```

## Cycle: fallout — existing suites re-run (T102/T103)

- kind: refactor (test-expectation updates only, no production change)
- criterion: SC-4
- at: 2026-09-16T01:40:00Z
- `test/plugins/tdd/two_cycle_run_commands_test.dart`: 4 tests pinned the
  exact per-behavior phase-1 step sequence (gen/verify-red/make/refactor
  per behavior) — the scheduling THIS feature removes. The pinned
  sequences were updated to the new schedule (all makes first, then the
  phase-2b batch refactors in list order): U1/US1.AC1, U3/US1.AC3,
  U7/US2.AC3, U12/US3.AC4. Result: 21/21 pass.
  `--preset=all` (slow tag): `dart test --preset=all
  test/plugins/tdd/two_cycle_run_commands_test.dart` → 21 pass.
- `test/plugins/tdd/run_driver_1652_make_post_state_test.dart`: 4/4 pass
  UNMODIFIED (the #1662 record contract composes with the deferral).

## Cycle: verify — mutation sampling 4/4 killed after one remediation (A1c)

- kind: verification
- criterion: SC-1..SC-6
- command: mutation sampling per the tdd-profile rubric (LLM-guided
  audit; repo not zfa-wired for `tdd verify`) — one mutant at a time
  against `issue_1652_defer_phase1_refactor_test.dart`, cmp-verified
  restore after each
- at: 2026-09-16T02:20:00Z
- results:
  - M1 (gate drops the new disjunct): KILLED `+1 -5`
  - M2 (generic make-success path stops setting the flag): KILLED `+1 -5`
  - M3 (skip/adopt arm stops setting the flag): pass 1 SURVIVED `+6`
    → remediation: additive fake-zfa `skip-fail` token (exit-disagreeing
    skip, the bug-986 shape) + test A1c → re-run KILLED `+0 -1`
  - M4 (over-deferral: resume window included): KILLED `+4 -1` (A3)
- restoration: `cmp` verified byte-identical; suite re-run green `+7`
- full verdict: PASS — see tdd/verification.md
