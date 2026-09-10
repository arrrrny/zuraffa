# TDD Test List — Spec 1381

Red pre-fix: B1 red (2-column extraction empty); B2 guard green; B3
landed with the plan warning (red verified against the pre-warning
parser+plan state — the warning did not exist).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | 2-column Key Entities table extracts entities | FR-1 / AS-1 | test/plugins/tdd/services/bug_1381_entity_table_2col_test.dart |
| B2 | 3-column grammar unchanged | FR-2 / AS-2 | test/plugins/tdd/services/bug_1381_entity_table_2col_test.dart |
| B3 | Plan warns on a declared-but-unparseable section | FR-3 / AS-3 | test/plugins/tdd/commands/bug_1381_plan_warns_on_unparsed_entities_test.dart |

## Red protocol

```
dart test test/plugins/tdd/services/bug_1381_entity_table_2col_test.dart
dart test test/plugins/tdd/commands/bug_1381_plan_warns_on_unparsed_entities_test.dart
```
