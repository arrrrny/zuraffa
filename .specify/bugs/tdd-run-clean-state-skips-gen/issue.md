# Issue #720 (verbatim from https://github.com/arrrrny/zuraffa/issues/720)

> Provenance note: the task brief listed `.specify/bugs/tdd-run-clean-state-skips-gen/issue.md`
> and `assessment.md` as pre-committed records, but they are absent on `master`
> at `078891de`. The GitHub issue below is the authoritative record and is
> reproduced verbatim (minus the issue metadata header) so the bug directory is
> self-contained. No assessment.md was fabricated.

## Summary

`zfa tdd run` on a clean state (no run-state.json, no artifacts.json, no generated test files) goes straight to `[run] A1 make -> runner-error` with `behavior "A1" is planned in the 004-cloud-agent-task-dispatch test list but has no gen artifacts. Run \`zfa tdd gen A1\` first.`

The run should start with `A1:gen`, then `A1:verify-red`, then `A1:make`. But it skips `gen` and `verify-red` and tries `make` first.

## Reproduction

```bash
# Clean state
rm specs/004-cloud-agent-task-dispatch/tdd/run-state.json
rm specs/004-cloud-agent-task-dispatch/tdd/artifacts.json
rm lib/tdd/*.dart test/tdd/*.dart 2>/dev/null

# Run
zfa tdd run 004-cloud-agent-task-dispatch --project /Users/ahmettok/Developer/forklift --zfa-bin /Users/ahmettok/Developer/zuraffa/bin/zfa.dart
# Output:
# zfa tdd run: feature 004-cloud-agent-task-dispatch — 49 behavior(s)
# [run] A1 make -> runner-error
# zfa tdd run: step failed — behavior=A1 step=make outcome=runner-error
#    zfa tdd make: behavior "A1" is planned in the 004-cloud-agent-task-dispatch test list but has no gen artifacts. Run `zfa tdd gen A1` first.
# run: feature=004-cloud-agent-task-dispatch result=runner-error pending=43 red=6 green=0 done=0 stopped_at=A1:make
```

## Root cause

The driver reads `current.inFlightBehaviorId` / `current.inFlightStep` to resume. When the run-state file is missing or stale, the driver appears to fall through to `make` instead of starting at `gen`. The `steps: _stepsFor(state, inFlightStep)` call (run_command.dart:299) returns only `make` for a behavior that has no gen artifacts but a prior `red` state (from a previous interrupted run that never wrote in_flight).

## Expected

- No run-state → start with `gen` for the first behavior
- No artifacts.json + no test/subject files → `gen` runs and creates them
- The full gen → verify-red → make → refactor cycle per behavior in list order

## Actual

- No run-state → driver starts with `make` → errors with "no gen artifacts"
- The run stops at the very first behavior, never runs `gen` for any

## Verification

- A clean `zfa tdd run` from empty state should produce `[run] A1 gen -> ok`, `[run] A1 verify-red -> certified`, `[run] A1 make -> ...` in that order.
- An interrupted run that's resumed from a fresh wipe should also start with `gen` for the first behavior that has no artifacts.

## Context

Discovered on 2026-09-01 running `zfa tdd run` on forklift spec 004 after merging fixes for #657, #683, #693, #695 and wiping the run-state, artifacts, and all generated files. The run failed at A1:make with "no gen artifacts" on a fully clean state.

Following the STOP-ON-ROADBLOCK rule from zuraffa/AGENTS.md: filing and waiting for the merge before resuming.
