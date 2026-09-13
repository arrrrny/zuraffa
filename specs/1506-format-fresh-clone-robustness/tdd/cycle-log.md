# TDD Cycle Log: dart format Robustness in a Fresh Clone [SPEC 1506]

**Feature ID:** 1506-format-fresh-clone-robustness
Test list: [test-list.md](test-list.md)

## RED — U1..U8 (2026-09-13, Dart 3.13.2)

Command:

```bash
dart test test/commands/format_runner_1506_test.dart \
  test/commands/entity_format_scope_1506_test.dart
```

Recorded output (abridged to the decisive lines):

```text
00:00 +0 -2: Some tests failed.

Failing tests:
  test/commands/entity_format_scope_1506_test.dart: loading test/commands/entity_format_scope_1506_test.dart
  test/commands/format_runner_1506_test.dart: loading test/commands/format_runner_1506_test.dart

  test/commands/format_runner_1506_test.dart:23:8: Error: Error when reading 'lib/src/core/format/format_runner.dart': No such file or directory
  test/commands/format_runner_1506_test.dart:82:22: Error: Method not found: 'FormatRunner'.
  test/commands/entity_format_scope_1506_test.dart:43:38: Error: The method 'EntityCommand' isn't defined with a 'formatRunner' parameter.
  lib/src/commands/entity_command.dart:30:3: Context: Found this candidate, but the arguments don't match.
    EntityCommand({PubspecProcessRunner? pubRunner}) : _pubRunner = pubRunner;
```

Red classification: compile-stage red — the tested units do not exist
(`FormatRunner` missing entirely; `EntityCommand` lacks the injection
seam). Every behavior U1–U8 is red against the pre-implementation tree;
no behavior can pass before implementation, which the loader failure
guarantees for both files.

## GREEN — U1..U8 (2026-09-13, Dart 3.13.2)

Implementation: `lib/src/core/format/format_runner.dart` (new) +
`EntityCommand` wiring (`formatRunner` injection, scoped `_runFormat`).

Two intermediate fixes were made during the green phase, both covered by
the recorded assertions (no test weakened):

1. `FormatRunner` result semantics: the success path after enforcement
   reported `pubGetRan: false` — U3 caught it; the runner now reports
   whether the enforcement fired on every path.
2. Test fakes initially did not simulate what a real `dart pub get`
   does (write `.dart_tool/package_config.json`); the runner's
   re-verification before formatting correctly refused to proceed, which
   the fakes now mirror (production-faithful).

Command:

```bash
dart test test/commands/format_runner_1506_test.dart \
  test/commands/entity_format_scope_1506_test.dart
```

Recorded output:

```text
00:00 +7: test/commands/entity_format_scope_1506_test.dart: zfa entity format scope (issue #1506) U8: without resolution, pub get precedes the scoped format
00:00 +8: All tests passed!
```
