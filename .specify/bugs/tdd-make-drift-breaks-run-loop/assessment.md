# Bug Assessment: zfa tdd make: drift on already-green test breaks run loop

- **Slug**: tdd-make-drift-breaks-run-loop
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/694
- **Verdict**: valid
- **Severity**: high

## Report

`zfa tdd make` reports `outcome=drift` when the target test is already passing from a prior run, breaking the `zfa tdd run` loop.

## Symptom

Re-running `zfa tdd run` after some behaviors are already green → `make` returns `drift` and the run stops.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart` — `drift` outcome handling.

## Root Cause Hypothesis

`make` detects the test already passes (drift) but the run loop treats it as a failure instead of skipping. Confidence: **high**.

## Proposed Remediation

Detect already-green tests in `make` and either skip them or update run-state to `green`. Map `drift` to a success/skip transition.

## Open Questions

- None blocking.