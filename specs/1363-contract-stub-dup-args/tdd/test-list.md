# TDD Test List — Spec 1363 contract stub duplicate arg0

Red pre-fix: B1 (bare-name repro), B3 (positional fallback), B4 (test
echo) red; B2/B5 guards green (typed rows already unique).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | `validate(email, password) -> LoginVerdict` stub carries the declared names (dynamic email, dynamic password) — never a duplicate arg0 pair | FR-1 | test/plugins/tdd/bug_1363_contract_stub_dup_args_test.dart |
| B2 | Typed cells keep declared names/types (int a, int b) | FR-1 | test/plugins/tdd/bug_1363_contract_stub_dup_args_test.dart |
| B3 | Unnamed generic-type cells (List<int>, Map<String, int>) get positional arg0/arg1 | FR-2 | test/plugins/tdd/bug_1363_contract_stub_dup_args_test.dart |
| B4 | The generated TEST summary echoes unique names (no `arg0, Object? arg0`) | FR-1 | test/plugins/tdd/bug_1363_contract_stub_dup_args_test.dart |
| B5 | A mixed row (typed + bare cells) keeps every name unique | FR-1 | test/plugins/tdd/bug_1363_contract_stub_dup_args_test.dart |

## Red protocol

```
dart test test/plugins/tdd/bug_1363_contract_stub_dup_args_test.dart
```
Expected RED (pre-fix): +2 -3 (B1/B3/B4).
