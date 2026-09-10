# Plan — Spec 1387 guard exit contract pin

**Branch**: `1387-guard-exit-contract-pin` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`test/plugins/tdd/commands/bug_1387_guard_exit_contract_test.dart`: the
TddFixture baseline is pure-Dart, so the Flutter-dependent view/controller
plugins hit the guard. B1 drives the orchestrator (`make User view
--no-entity` via the global `-C`), B2 the standalone
(`controller create Product`). No production change.

## Test strategy

In-process CliRunner with `-C` (make is root-bound); the assertions pin
exit codes + the message vocabulary of both halves.
