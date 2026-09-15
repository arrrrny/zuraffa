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
