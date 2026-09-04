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
- green: 20/20 (both 965 suites) + 50/50 pre-existing view/taxonomy regression (commit b6aaebd6)

## Cycle: T003 (red)

- behavior: A-003 the generated widget test boots the slang test shell and asserts resolved keys
- kind: red
- classification: compileError (BehaviorTestWriter had no i18nKeys/i18nImport — the shell capability did not exist), then assertion reds on emission shape
- test: test/plugins/tdd/commands/bug_965_test_shell_resolved_keys_test.dart
- command: `dart test test/plugins/tdd/commands/bug_965_test_shell_resolved_keys_test.dart`
- exit: 1
- output:
```
Error: No named parameter with the name 'i18nKeys'.
```
- green: 9/9 + 72/72 across 965/964/938/912/writer regression (commit 73b0d268)

## Cycle: T004 (red)

- behavior: A-004 the ledger traces t.<key> per row and reports untraced-surface violations
- kind: red
- classification: compileError (UiLedgerBuilder.untracedHardcodedStrings did not exist)
- test: test/plugins/tdd/commands/bug_965_ledger_key_traces_test.dart
- command: `dart test test/plugins/tdd/commands/bug_965_ledger_key_traces_test.dart`
- exit: 1
- output:
```
Error: Member not found: 'UiLedgerBuilder.untracedHardcodedStrings'.
```
- green: 8/8 (commit 20f6af66)

## Cycle: T005 (red)

- behavior: A-005 the optional expansion tier pumps base + de and scaffolds the expansion file
- kind: red
- classification: compileError (BehaviorTestWriter had no i18nExpansion; gen/view had no --i18n-expansion)
- test: test/plugins/tdd/commands/bug_965_expansion_locale_test.dart
- command: `dart test test/plugins/tdd/commands/bug_965_expansion_locale_test.dart`
- exit: 1
- output:
```
Error: No named parameter with the name 'i18nExpansion'.
```
- green: 6/6
