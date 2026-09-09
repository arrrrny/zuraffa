# TDD Test List — Spec 1372

Regression pin for already-landed fix (583d711d): all behaviors green on
master; red only if the scan regresses to first-section early-return.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | [error, red] → make proceeds | FR-1 / AS-1 | test/plugins/tdd/commands/bug_1372_certified_red_scan_test.dart |
| B2 | [red] alone → make proceeds | FR-2 / AS-2 | test/plugins/tdd/commands/bug_1372_certified_red_scan_test.dart |
| B3 | [error] alone → honest refusal | FR-3 / AS-3 | test/plugins/tdd/commands/bug_1372_certified_red_scan_test.dart |

## Red protocol

```
dart test test/plugins/tdd/commands/bug_1372_certified_red_scan_test.dart
```
M1 (revert the scan to early-return) → B1 red.
