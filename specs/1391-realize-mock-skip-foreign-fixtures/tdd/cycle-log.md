# Cycle Log

## Cycle: 1391-realize-mock-skip-foreign-fixtures (red)

- behavior: 1391-realize-mock-skip-foreign-fixtures (spec 1391 / issue #1391 TDD loop)
- kind: red
- classification: assertionFailure
- criterion: AC-1..AC-5 / SC-1..SC-5
- test: test/plugins/tdd/commands/bug_1391_realize_mock_skip_foreign_fixtures_test.dart
- command: `dart test test/plugins/tdd/commands/bug_1391_realize_mock_skip_foreign_fixtures_test.dart`
- exit: 1
- at: 2026-09-10T21:55:00.000Z
- output:
```
A1  #1391 repro (#832 artifacts + 3 cases) -> Expected: contains 'result=certified'
                                              Actual: 'fixture manifest is not a realize-diff.v1 document
                                              (schema, input.op missing) — fix the fixture before certifying.'
                                              ... methods=3 mismatch=0 result=runner-error  (the issue signature)
A2a string-schema foreign doc            -> Expected: contains 'skipped foreign.json (schema world-v2)'
                                              Actual: 'fixture foreign is not a realize-diff.v1 document' (runner-error)
A2b schema-less document                 -> Expected: contains 'skipped schemaless.json (schema unknown)'
                                              Actual: crash on foreign document (runner-error)
A2c unparseable .json                    -> Expected: contains 'skipped broken.json (schema unknown)'
                                              Actual: crash on foreign document (runner-error)
A3  foreign-only fixtures dir            -> Expected: contains 'result=blocked'
                                              Actual: 'result=runner-error' (the crash this fix removes)
A4  pure realize-diff.v1 dir (PIN)       -> PASS (unchanged behavior pre-change)
A5  own-schema case missing input.op (PIN) -> PASS (fail-closed stands pre-change)
```
- note: 5 red / 2 pins green — the reds fail for the right reasons (the
  pre-fix scan ingests every .json as realize-diff.v1 and crashes on the
  first foreign document, exactly the issue #1391 signature).

## Cycle: 1391-realize-mock-skip-foreign-fixtures (green)

- behavior: 1391-realize-mock-skip-foreign-fixtures (spec 1391 / issue #1391 TDD loop)
- kind: green
- classification: pass
- criterion: AC-1..AC-5 / SC-1..SC-5
- test: test/plugins/tdd/commands/bug_1391_realize_mock_skip_foreign_fixtures_test.dart
- command: `dart test test/plugins/tdd/commands/bug_1391_realize_mock_skip_foreign_fixtures_test.dart`
- exit: 0
- at: 2026-09-10T22:05:00.000Z
- output:
```
A1  #1391 repro            -> exit 0, result=certified, methods=3 mismatch=0,
                              'skipped manifest.json (schema 1)' + 'skipped mock-cert.Login.json (schema 1)',
                              receipt carries exactly getById/saveLogin/getAllLogins, no 'runner-error'
A2a string-schema foreign  -> 'skipped foreign.json (schema world-v2)', methods=1, certified
A2b schema-less document   -> 'skipped schemaless.json (schema unknown)', methods=1
A2c unparseable .json      -> 'skipped broken.json (schema unknown)', methods=1, certified
A3  foreign-only dir       -> exit 1, result=blocked, 'no realize-diff.v1 contract cases remain after
                              skipping 2 foreign document(s)', no receipt written
A4  pure dir (PIN)         -> exit 0, certified, zero 'skipped ' lines, receipt unchanged
A5  own-schema red (PIN)   -> 'carries no input.op', result=runner-error (fail-closed intact)

7/7 passed (+ 16/16 pre-existing realize-mock tests green:
dart test test/plugins/tdd/commands/realize_mock_command_test.dart
          test/plugins/tdd/commands/bug_1367_realize_mock_cert_fallback_test.dart)
```
- note: smallest change that makes the reds green — the scan classifies
  by `schema` (contract case iff exactly `realize-diff.v1`), skips
  foreign documents with the `skipped <name> (schema <x>)` log line, and
  adds the post-scan zero-cases BLOCKED guard; the own-schema validation
  and every downstream format are untouched.
