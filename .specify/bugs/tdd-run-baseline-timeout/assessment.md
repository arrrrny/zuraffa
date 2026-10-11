# Bug Assessment: zfa tdd run suite baseline ignores --timeout; 10-min default kills the run on large repos

- **Slug**: tdd-run-baseline-timeout
- **Created**: 2026-09-05
- **Source**: https://github.com/arrrrny/zuraffa/issues/1159
- **Verdict**: valid — reproduced deterministically; root cause traced to source
- **Severity**: unknown (labeled `bug`)

## Report (summarized)

`zfa tdd run <feature>` can never complete on this repo. The full-suite baseline that
precedes every `make` step is killed by a hardcoded 10-minute deadline, so `tdd make`
always refuses with `runner-error` ("the suite baseline did not produce a usable
snapshot"). Reproduced on feature `077-make-engine-preset` during a spec-whole run.

Repro output:

```
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> runner-error
zfa tdd run: step failed — behavior=A1 step=make outcome=runner-error
```

Standalone: `zfa tdd make A1 --feature 077-make-engine-preset` →
`baseline exit: -1, failed: 0` → refusal. Direct `dart test` on the repo takes well over
10 minutes (fast tier), so this reproduces deterministically.

## Symptom

Every `zfa tdd run` (and standalone `zfa tdd make`) stops at the first behavior's make
step with `outcome=runner-error` because the suite baseline `dart test` child exits -1
(killed) and no `run-baseline.json` snapshot is ever written.

## Reproduction

1. On this repo (fast suite > 10 min): `zfa tdd run 077-make-engine-preset --timeout 25`
2. Observe `A1 make -> runner-error` and the refusal message.
3. Re-run `zfa tdd make A1 --feature 077-make-engine-preset` standalone — same refusal.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_driver_core.dart` (~line 406): the run-level baseline
  calls `const SingleTestRunner().runSuite(suiteTemplate: ..., workingDirectory: ...)`
  **without forwarding the driver's `timeout` override**.
- `lib/src/plugins/tdd/services/runner.dart` (`runSuite`, ~line 409): defaults the deadline
  to `TddTimeouts.defaultSuite` when `timeout` is null.
- `lib/src/plugins/tdd/services/tdd_timeout.dart:48`: `defaultSuite = Duration(minutes: 10)`.
- `lib/src/plugins/tdd/commands/make_command.dart` (~line 465): the make fallback live
  baseline ("baseline exit: ${live.exitCode}") hits the same wall when no cached snapshot
  exists.

## Root Cause Hypothesis

Confirmed: `run_driver_core.dart` drops the driver's `timeoutOverride` (from
`zfa tdd run --timeout N`) on the floor for the baseline suite run, violating the
bug-#742 contract ("one uniform deadline for every spawned process"). With the repo's
fast suite now > 10 minutes, the baseline child is SIGKILLed
(`ProcessTimeoutException` → `SuiteRunRecord.exitCode = -1, timedOut: true`), the
snapshot is unparseable, `RunBaselineCache` never writes, and `tdd make`'s own fallback
baseline re-runs into the identical deadline.

## Proposed Remediation

1. Forward the driver's `timeoutOverride` into `runSuite(...)` for the run-level baseline
   in `run_driver_core.dart`.
2. Ensure `zfa tdd run` passes `--timeout` through when spawning `zfa tdd make` so the
   make fallback baseline honors the same override (verify; the run-level spawn path is
   `run_driver_core.dart` `_driveBehavior`/`StepRunner`).
3. Tests (behavioral, in `test/plugins/tdd/`):
   - a baseline that exceeds `defaultSuite` but fits inside the `--timeout` override
     completes and yields a parseable snapshot (use a scripted fake suite command with a
     sleep, or inject a short `defaultSuite` — prefer overriding via the same parameter
     path, with fakes to keep the test fast);
   - `tdd make` with `--timeout` uses the override for its fallback baseline;
   - regression: with the override forwarded, a run whose baseline is slow still caches
     `run-baseline.json` and subsequent make steps reuse it.

## Risks & Considerations

- Fix is config-plumbing only — no behavioral change when the default is sufficient.
- The TDD-mode bug flow itself (bug.fix driving `tdd run`) hits the same broken baseline;
  the remediation must land first within the bug-fix step for the loop to proceed.
- Keep `defaultSuite` at 10 min; do not silently raise global defaults.
