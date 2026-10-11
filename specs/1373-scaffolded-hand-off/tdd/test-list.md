# TDD Test List — Spec 1373

Red pre-fix: B1 red (the generic stop, no hand message); B2 guard green.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Marker present + not-certified-red → the hand step + --author remedy + stopped_at=<id>:hand | FR-1 / AS-1 | test/plugins/tdd/commands/bug_1373_scaffolded_hand_off_driver_test.dart |
| B2 | Marker absent → the generic make stop unchanged | FR-2 / AS-2 | test/plugins/tdd/commands/bug_1373_scaffolded_hand_off_driver_test.dart |

## Red protocol

```
dart test --preset=all test/plugins/tdd/commands/bug_1373_scaffolded_hand_off_driver_test.dart
```
