# Cycle Log: missing-subject-symlink-root (#1603)

## Cycle: baseline — U-V3 red on macOS (pre-fix tree)

- behavior: U-V3 (existing pin)
- kind: red
- classification: assertionFailure / wrong refusal branch
- test: test/plugins/tdd/commands/view_command_test.dart
- command: `dart test test/plugins/tdd/commands/view_command_test.dart --plain-name "U-V3"`
- exit: 1
- at: 2026-09-13 (macOS, Dart 3.13.x)
- output:
```
00:04 +0 -1: U-V3: a missing subject file is a hard runner-error [E]
  Expected: contains 'missing subject file'
    Actual: 'zfa tdd view: behavior A-001\n'
              '   feature: 090-tdd-fixture\n'
              '   description: the login page renders\n'
              'zfa tdd view: the registry record for behavior "A-001" points outside the project root at "lib/a_001_subject.dart". Run `zfa tdd gen A-001` to restore its artifacts.\n'
              'view: behavior=A-001 outcome=runner-error feature=090-tdd-fixture\n'
              ''
     Which: does not contain 'missing subject file'
  test/plugins/tdd/commands/view_command_test.dart 205:5  main.<fn>
```
- result: red for the RIGHT reason — the fixture temp root (`/var/folders/...`)
  canonicalizes to `/private/var/folders/...`, so the un-canonicalized missing
  subject compares as outside the root.

## Cycle: U-V11 red / U-V12 guard green (pre-fix tree, new pins)

- behavior: U1603-1 (U-V11), U1603-2 (U-V12)
- kind: red
- classification: assertionFailure (U-V11) / pass (U-V12 guard)
- test: test/plugins/tdd/commands/view_command_test.dart
- command: `dart test test/plugins/tdd/commands/view_command_test.dart -n "U-V1[12]"`
- exit: 1
- at: 2026-09-13 (macOS, Dart 3.13.x)
- output:
```
00:05 +0 -1: U-V11: a missing subject under a symlinked project root is the missing-file refusal, never outside-root (issue #1603) [E]
  Expected: contains 'missing subject file'
    Actual: 'zfa tdd view: behavior A-001\n'
              '   feature: 090-tdd-fixture\n'
              '   description: the login page renders\n'
              'zfa tdd view: the registry record for behavior "A-001" points outside the project root at "lib/a_001_subject.dart". Run `zfa tdd gen A-001` to restore its artifacts.\n'
              'view: behavior=A-001 outcome=runner-error feature=090-tdd-fixture\n'
              ''
     Which: does not contain 'missing subject file'
  test/plugins/tdd/commands/view_command_test.dart 368:5  main.<fn>

00:05 +0 -1: U-V12: a recorded subject that genuinely resolves outside the project root is still refused as outside-root
00:09 +1 -1: Some tests failed.
```
- result: U-V11 red for the RIGHT reason (explicit sibling symlink, no macOS
  temp-root dependence); U-V12 green pre-fix — the must-not-break outside-root
  guard for FR-002.

## Cycle: green (fix applied — `_canonicalizeMissingPath` in view_command.dart)

- behavior: U1603-1 (U-V11), U1603-2 (U-V12), U-V3
- kind: green
- classification: pass
- test: test/plugins/tdd/commands/view_command_test.dart
- command: `dart test test/plugins/tdd/commands/view_command_test.dart`
- exit: 0
- at: 2026-09-13 (macOS, Dart 3.13.x)
- output:
```
00:10 +3: U-V3: a missing subject file is a hard runner-error
00:45 +10: U-V11: a missing subject under a symlinked project root is the missing-file refusal, never outside-root (issue #1603)
00:48 +11: U-V12: a recorded subject that genuinely resolves outside the project root is still refused as outside-root
00:51 +12: All tests passed!
```
- result: 12/12 — U-V3 turned green on macOS (the original red), U-V11 green,
  U-V12 stayed green.

## Cycle: sibling view-surface regression (post-fix)

- behavior: regression sweep over the other view-command suites
- kind: verify
- classification: pass
- command: `dart test test/plugins/tdd/commands/bug_1141_view_audit_test.dart test/plugins/tdd/commands/bug_965_view_i18n_generation_test.dart test/plugins/tdd/commands/bug_1141_login_ui_regeneration_test.dart test/plugins/tdd/commands/spec_1142_adaptive_layout_test.dart`
- exit: 0
- at: 2026-09-13
- output:
```
00:38 +29: All tests passed!
```
- result: 29/29 sibling view pins green.

## Cycle: static analysis + format

- command: `dart analyze lib/src/plugins/tdd/commands/view_command.dart test/plugins/tdd/commands/view_command_test.dart`
- output: `No issues found!`
- command: `dart format lib/src/plugins/tdd/commands/view_command.dart test/plugins/tdd/commands/view_command_test.dart`
- output: `Formatted 2 files (0 changed) in 0.06 seconds.`

