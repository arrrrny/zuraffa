# TDD Test List — Spec 1382

Red pre-fix: B1 red — three regression files (issue_1173, issue_1188,
issue_891) carried no regression tag (invisible to the preset).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Every regression-tier file carries the regression tag | FR-1 / AS-2 | test/tier_integrity_test.dart |
| B2 | dart_test.yaml defines the regression preset | FR-2 / AS-3 | test/tier_integrity_test.dart |

## Red protocol

```
dart test test/tier_integrity_test.dart
```
