# TDD Cycle Log — bug #726 (tdd-suite-template-truncation)

Branch: `fix/726-tdd-suite-template-truncation`
Runner: `dart test` (Dart SDK 3.13.3)

## Cycle 1: RED — multi-word unquoted command templates truncate to first word

Command (runner-level):

```
dart test test/plugins/tdd/runner_suite_test.dart --plain-name "multi-word unquoted"
```

Output (verbatim, pre-fix, 6 failing):

```
00:00 +0 -6: Some tests failed.

Failing tests:
  test/plugins/tdd/runner_suite_test.dart: bug #726: multi-word unquoted command templates an unquoted suite value with a trailing comment captures only the command (no comment swallowing)
  test/plugins/tdd/runner_suite_test.dart: bug #726: multi-word unquoted command templates loadSingleTemplate resolves an unquoted multi-word single: from nested stacks frontmatter
  test/plugins/tdd/runner_suite_test.dart: bug #726: multi-word unquoted command templates loadSuiteTemplate resolves an unquoted multi-word suite: from nested stacks frontmatter (the issue repro)
  test/plugins/tdd/runner_suite_test.dart: bug #726: multi-word unquoted command templates loadSuiteTemplate resolves an unquoted multi-word suite: from the Keys block (last key)
  ... and 2 more
```

Representative failure (the issue repro — truncation):

```
Expected: 'dart test'
  Actual: 'dart'
   Which: is different. Both strings start the same, but the actual value is missing the following trailing characters:  test
```

Representative failure (Keys block, last key — anchored pattern fails to match entirely):

```
Bad state: zfa tdd make: no `suite` command template found in /tmp/runner_suite_OVWYWR/.specify/memory/tdd-profile.md.
```

Command (integration-level, `zfa tdd make` end to end):

```
dart test test/plugins/tdd/make_command_test.dart --preset=all --plain-name "baseline runs the REAL suite"
```

Output (verbatim, pre-fix — matches the issue's repro output):

```
zfa tdd make: behavior B-001
   feature: 090-tdd-fixture
   test: /tmp/tdd_fixture_RHKIYS/test/b_001_test.dart
   suite baseline: dart
   baseline exit: 0, failed: 0
zfa tdd make: the suite baseline did not produce a usable snapshot. Refusing to generate without a trustworthy pre-run failure set.
make: behavior=B-001 outcome=runner-error feature=090-tdd-fixture
```

Total red: 7 failing (6 runner-level + 1 integration-level).

## Cycle 2: GREEN — unquoted alternative captures multi-word commands

Fix: in `lib/src/plugins/tdd/services/runner.dart`, change the unquoted
alternative from `[^\s#]+` to `[^\s#]+(?:[ \t]+[^\s#]+)*` (one or more
whitespace-separated words on a single line) at all six call sites
(`loadSingleTemplate` keys/frontmatter/nested, `loadSuiteTemplate`
keys/frontmatter/nested). Horizontal-only separator `[ \t]+` keeps the group
line-bound (a `\s+` separator would swallow the following YAML lines on
mid-block values) and the `[^\s#]` token class preserves the original
`#`-comment exclusion.

Commands:

```
dart test test/plugins/tdd/runner_suite_test.dart --plain-name "multi-word unquoted"
# -> 00:00 +6: All tests passed!

dart test test/plugins/tdd/make_command_test.dart --preset=all --plain-name "baseline runs the REAL suite"
# -> 00:08 +1: All tests passed!
```

Full affected-file regression (green, no new failures) is recorded in
`tdd/verification.md`.
