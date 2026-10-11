# Plan — Spec 1372 certified-red scan pin

**Branch**: `1372-certified-red-scan-pin` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`test/plugins/tdd/commands/bug_1372_certified_red_scan_test.dart`: seed a
TddFixture behavior + a cycle-log with parametrized section kinds
([error, red] / [red] / [error]), run `tdd make A1` through the in-process
runner, and pin the gate outcome. No production change.

## Test strategy

The three scenarios above; scoped pin: the make suite + analyze.
