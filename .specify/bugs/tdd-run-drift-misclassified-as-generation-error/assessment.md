# Bug Assessment: run driver misclassifies #657 success as generation-error

- **Slug**: tdd-run-drift-misclassified-as-generation-error
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/693
- **Verdict**: valid
- **Severity**: high

## Report

After fix #657, `zfa tdd make` returns `drift` (test already passes) for plain-function behaviors. But `zfa tdd run` maps `drift` to `generation-error` and leaves the behavior `pending` instead of `green`/`done`.

## Symptom

U1:make → `drift` (success, test passes), but run driver reports `generation-error` and hard-stops.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart` — outcome mapping table (from #625 refactor) lacks a `drift` entry.

## Root Cause Hypothesis

The outcome mapping table maps `drift` to `generation-error` (fallthrough). It needs an entry classifying `drift` as `green` (success). Confidence: **high**.

## Proposed Remediation

Add `drift` → `green` to the outcome mapping table in `run_command.dart`. When `make` returns `drift` and the test is green, transition the behavior to `green`/`done` and proceed.

## Open Questions

- None blocking.