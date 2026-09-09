# TDD Test List — Spec 1371

Red pre-fix: B1/B3 red (phantom path returned verbatim / no honest
throw); B2 guard green.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Phantom re-anchored zfa.dart falls through to the package tier | FR-1 / AS-1 | test/plugins/tdd/services/bug_1371_entrypoint_existence_test.dart |
| B2 | Existing zfa.dart returned verbatim | FR-2 / AS-2 | test/plugins/tdd/services/bug_1371_entrypoint_existence_test.dart |
| B3 | Nothing resolvable → the honest StateError | FR-3 / AS-3 | test/plugins/tdd/services/bug_1371_entrypoint_existence_test.dart |

## Red protocol

```
dart test test/plugins/tdd/services/bug_1371_entrypoint_existence_test.dart
```
