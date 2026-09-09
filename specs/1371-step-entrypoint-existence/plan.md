# Plan — Spec 1371 step entrypoint existence

**Branch**: `1371-step-entrypoint-existence` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

One change in `StepRunner.resolveEntrypoint` tier 1: gate the verbatim
return on `await File(scriptPath).exists()`. The existing tiers 2-6
already check existence; the fall-through now reaches the package tier
for the re-anchored case.

## Test strategy

`test/plugins/tdd/services/bug_1371_entrypoint_existence_test.dart` —
unit-level, fully injected (script URI + resolvePackageUri over a temp
package layout): B1 phantom falls through to the package tier, B2
existing verbatim guard, B3 honest StateError with nothing resolvable.
Scoped pin: the existing step_runner suite + analyze.
