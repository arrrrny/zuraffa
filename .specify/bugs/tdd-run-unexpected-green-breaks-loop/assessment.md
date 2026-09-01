# Bug Assessment: zfa tdd run: unexpected-green on already-completed behavior breaks the run loop

- **Slug**: tdd-run-unexpected-green-breaks-loop
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/691
- **Verdict**: valid
- **Severity**: high

## Report

`zfa tdd run` fails with `unexpected-green` when a behavior's test is already green from prior work. The run loop treats it as a failure instead of skipping the already-complete behavior.

## Symptom

After manually completing a behavior (gen → verify-red → make), `zfa tdd run` stops at that behavior with `outcome=unexpected-green`.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart` — `verify-red` step in the run loop fails on already-green tests.

## Root Cause Hypothesis

The run loop's `verify-red` step assumes the test is red. When the test is already green (from prior manual make), it reports `unexpected-green` and halts. The run loop should detect already-green tests and skip them (mark done) instead of failing. Confidence: **high**.

## Proposed Remediation

In the run loop, before `verify-red`, check if the test is already green. If so, skip to `make` (or mark done directly). Map `unexpected-green` to a skip/done transition rather than a hard failure.

## Open Questions

- None blocking.