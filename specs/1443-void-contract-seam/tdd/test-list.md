# TDD Test List — Spec 1443

Red pre-fix: B1 red (`void register(` emitted — the capture cannot
compile); B2 guard green.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Void-return contract renders an Object? seam | FR-1 / AS-1 | test/plugins/tdd/services/bug_1443_void_contract_seam_test.dart |
| B2 | Non-void renderable return unchanged (int add) | FR-2 / AS-2 | test/plugins/tdd/services/bug_1443_void_contract_seam_test.dart |

## Red protocol

```
dart test test/plugins/tdd/services/bug_1443_void_contract_seam_test.dart
```
