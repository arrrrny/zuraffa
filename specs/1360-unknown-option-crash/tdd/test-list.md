# TDD Test List — Spec 1360 unknown-option crash

Red pre-fix: B1/B4 red (null-check crash, exit 1); B2/B3 guards green.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | `simulate run --world=v3` → exit 2, clean "Could not find an option" + usage, NO null-check text | FR-1 / AS-1 | test/cli/bug_1360_undeclared_option_crash_test.dart |
| B2 | Parent-level `simulate --world=v3` → exit 2 clean (guard) | FR-2 / AS-2 | test/cli/bug_1360_undeclared_option_crash_test.dart |
| B3 | `simulate --help` → exit 0 (guard) | FR-3 / AS-3 | test/cli/bug_1360_undeclared_option_crash_test.dart |
| B4 | The usage error carries the `-->` fix line | FR-1 / AS-1 | test/cli/bug_1360_undeclared_option_crash_test.dart |

## Red protocol

```
dart test test/cli/bug_1360_undeclared_option_crash_test.dart
```
