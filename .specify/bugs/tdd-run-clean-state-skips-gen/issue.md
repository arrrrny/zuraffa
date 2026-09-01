# Bug Issue: fix(tdd): run driver on clean state goes straight to make — skips gen, fails with 'no gen artifacts'

- **Slug**: tdd-run-clean-state-skips-gen
- **Fetched**: 2026-09-01
- **Issue**: 720
- **URL**: https://github.com/arrrrny/zuraffa/issues/720
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

`zfa tdd run` on a clean state (no run-state.json, no artifacts.json, no generated test files) goes straight to `[run] A1 make -> runner-error` with `behavior "A1" is planned in the test list but has no gen artifacts. Run \`zfa tdd gen A1\` first.` The run should start with `gen` but skips to `make`.

## Reproduction

```bash
rm specs/004-cloud-agent-task-dispatch/tdd/run-state.json
rm specs/004-cloud-agent-task-dispatch/tdd/artifacts.json
rm lib/tdd/*.dart test/tdd/*.dart 2>/dev/null
zfa tdd run 004-cloud-agent-task-dispatch --project . --zfa-bin ~/.local/bin/zfa
# Output: [run] A1 make -> runner-error — no gen artifacts
```

## Root cause

The driver reads `current.inFlightBehaviorId` / `current.inFlightStep` to resume. When the run-state file is missing or stale, the driver falls through to `make` instead of starting at `gen`. The `steps: _stepsFor(state, inFlightStep)` call returns only `make` for a behavior that has no gen artifacts but a prior `red` state.

## Expected

No run-state → start with `gen` for the first behavior, then `verify-red`, then `make`.