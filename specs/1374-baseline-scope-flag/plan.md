# Plan — Spec 1374 baseline scope flag

**Branch**: `1374-baseline-scope-flag` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`run_driver_core.drive` gains `baselineScope`; the baseline block appends
the scope to the suite template and bypasses the corpus cache on both the
read and the write sides when scoped. `run_command` registers
`--baseline-scope` and plumbs it into both lane `drive` calls.
`make_command` registers the same option and appends the scope in its
live-baseline branch.

## Test strategy

`test/plugins/tdd/commands/bug_1374_baseline_scope_test.dart` (slow tier
— the run drives real dart test children): B1/B2 assert the scoped
baseline command on each verb, B3 the unscoped guard. Scoped pin: split
1000, #1309, realize-mock suites + analyze.
