# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: U1+U2 (red) — plan writes the UI ledger

- behavior: U1, U2
- kind: red
- classification: assertionFailure
- criterion: FR-001
- test: test/plugins/tdd/commands/bug_1141_ledger_wiring_test.dart
- command: `dart test test/plugins/tdd/commands/bug_1141_ledger_wiring_test.dart`
- exit: 1
- at: 2026-09-06T08:55:00Z (this session, pre-implementation)
- output:
```
00:00 +0 -6: Some tests failed.

Failing tests:
  test/plugins/tdd/commands/bug_1141_ledger_wiring_test.dart: bug 1141 U1: ... the keyed anchor feeds a t.<key> row ...
  test/plugins/tdd/commands/bug_1141_ledger_wiring_test.dart: bug 1141 U1: ... unkeyed presence literals become text rows ...
  test/plugins/tdd/commands/bug_1141_ledger_wiring_test.dart: bug 1141 U1: ... route and enabled-state literals become route/affordance rows ...
  test/plugins/tdd/commands/bug_1141_ledger_wiring_test.dart: bug 1141 U1: ... the JSON twin carries the same rows
  test/plugins/tdd/commands/bug_1141_ledger_wiring_test.dart: bug 1141 U1: ... the plan stdout reports the ledger write
  test/plugins/tdd/commands/bug_1141_ledger_wiring_test.dart: bug 1141 U2: ... a zero-surface spec writes the empty ledger ...
(all six: plan wrote no `tdd/ui-ledger.md` — `Expected: true / Actual: <false>` on the artifact existence and `Which: does not contain 'ui-ledger.md'` on the stdout assertion)
```

## Cycle: U3+U4+U5 (red) — view audits its own output

- behavior: U3, U4, U5
- kind: red
- classification: compileError
- criterion: FR-002
- test: test/plugins/tdd/commands/bug_1141_view_audit_test.dart
- command: `dart test test/plugins/tdd/commands/bug_1141_view_audit_test.dart`
- exit: 1
- at: 2026-09-06T08:55:00Z (this session, pre-implementation)
- output:
```
test/plugins/tdd/commands/bug_1141_view_audit_test.dart: Error: Undefined name 'UiViewAudit'.
test/plugins/tdd/commands/bug_1141_view_audit_test.dart: Error: Member not found: 'UiLedgerBuilder.quotedUserFacingStrings'.
00:00 +0 -1: Some tests failed.
Failing tests:
  test/plugins/tdd/commands/bug_1141_view_audit_test.dart: loading test/plugins/tdd/commands/bug_1141_view_audit_test.dart
```

## Cycle: U6+U7+U8 (red) — build runs the slang codegen stage

- behavior: U6, U7, U8
- kind: red
- classification: compileError
- criterion: FR-003
- test: test/commands/build_command_slang_stage_test.dart
- command: `dart test test/commands/build_command_slang_stage_test.dart`
- exit: 1
- at: 2026-09-06T08:55:00Z (this session, pre-implementation)
- output:
```
test/commands/build_command_slang_stage_test.dart: Error: Method not found: 'SlangBuildStage'.
test/commands/build_command_slang_stage_test.dart: Error: Undefined name: 'SlangStageDecision'.
00:00 +0 -1: Some tests failed.
Failing tests:
  test/commands/build_command_slang_stage_test.dart: loading test/commands/build_command_slang_stage_test.dart
```

## Cycle: A1+A2+U9 (red) — the 004-login-ui regeneration acceptance

- behavior: A1, A2, U9
- kind: red
- classification: assertionFailure
- criterion: FR-004
- test: test/plugins/tdd/commands/bug_1141_login_ui_regeneration_test.dart
- command: `dart test test/plugins/tdd/commands/bug_1141_login_ui_regeneration_test.dart`
- exit: 1
- at: 2026-09-06T09:00:00Z (this session, pre-implementation)
- output:
```
00:00 +0 -3: Some tests failed.

Failing tests:
  ... A1: the regenerated view has zero hardcoded user-facing strings ...
  ... A2: an EN copy edit (Sign in → Log In) does NOT break the generated tests ...
  ... U9: the regeneration composes — ledger rows, slang test shell, merged scaffold ...
```
- notes:
  - A1/A2 root cause (in addition to the missing ledger): the view
    command's `_stubSignature` only matches the pre-#959 throw-shaped
    stub; `zfa tdd gen` now emits the INERT stub
    (`Widget $target() => const SizedBox.shrink();`), so `zfa tdd view`
    no-ops ("already implemented") on a freshly generated subject —
    the regeneration loop could never run end-to-end. The fix (matching
    the inert shape too) is part of this spec's GREEN phase.
  - U9: `PathNotFoundException: .../tdd/ui-ledger.md` — plan wrote no
    ledger (same root cause as U1).
  - The keyed emission itself (Text(t.auth.signIn), the slang test
    shell, the scaffold) was already green on master via #965 — the
    honest baseline, same as 0965's zero-drift cases.
