# Fix: 991-tdd-run-phase0-no-analyze

- **Fixed**: 2026-09-05 (fix session)
- **Branch**: fix/991-tdd-run-phase0-no-analyze

## Change

`lib/src/plugins/tdd/commands/run_command.dart` — `_runEntityPhaseZero`:

```diff
-      build = await spawn(const ['build']);
+      build = await spawn(const ['build', '--no-analyze']);
```

plus documentation on the phase-0 doc comment and the spawn-site comment
stating the contract: the phase-0 build is a generation gate, not an
analysis gate; analyze is enforced by the verify/refactor steps.

`test/plugins/tdd/run_command_test.dart` — bug-829 group:

- U-829c / U-829d / U-829f argv assertions updated from the bare `build`
  spawn to the `build --no-analyze` spawn (the expected argv changed with
  the fix; the assertions' intent — exactly one build, ordered before the
  first gen — is unchanged).
- New U-991: pre-existing analyze warnings (scripted as a failure on the
  bare `build` invocation, config key `build-`) must not stop the run —
  the build spawn carries `--no-analyze` and behaviors are driven.
- New U-991b: a genuine build failure on the `--no-analyze` invocation
  (config key `build---no-analyze`) must still stop the run honestly
  (`runner-error`, `stopped_at=phase-0:build`, no behavior driven) — the
  fix removes only the analyze gate, not the stop contract.

No assertion was weakened: the two amended argv assertions assert a
strictly-more-specific argv, and the two new tests pin both directions of
the contract.

## Red→green evidence

See `tdd/cycle-log.md` (append-only record of the observed red and green
runs, plus the two deliberate mutants killed).
