# Cycle Log — 0965-i18n-keyed-widget-contracts

## Cycle: T001 (red)

- behavior: A-001 the spec contract parses `key:` declarations with EN anchors
- kind: red
- classification: compileError (missing contract — `services/i18n_key_contract.dart` did not exist)
- test: test/plugins/tdd/bug_965_i18n_key_contracts_test.dart
- command: `dart test test/plugins/tdd/bug_965_i18n_key_contracts_test.dart`
- exit: 1
- output:
```
Error: Type 'LayerContract' not found. / loading failed — i18n_key_contract.dart not resolvable
```
- green: 12/12 after implementing the contract (commit c59e0f03)

## Cycle: T002 (red)

- behavior: A-002 `zfa tdd view` emits `t.<key>` for anchored literals and scaffolds missing keys into lib/i18n
- kind: red
- classification: assertionFailure (the generator still pins EN literals — `Text('Sign in')` instead of `Text(t.auth.signIn)`, no i18n scaffold)
- test: test/plugins/tdd/commands/bug_965_view_i18n_generation_test.dart
- command: `dart test test/plugins/tdd/commands/bug_965_view_i18n_generation_test.dart`
- exit: 1
- output:
```
00:03 +2 -6: Some tests failed.
Failing: US2.AC1 accessor-not-EN, US2.AC1 accessor import, US2.AC2 scaffold merge,
         US2.AC2 fresh lib/i18n tree, determinism, malformed-refusal
(+2 pass: the zero-drift EN-fallback cases the pre-#965 generator already satisfies)
```
