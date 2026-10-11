# Cycle Log

## Cycle: T-U1 + T-U2 + T-U3 (red)

- behavior: the three `#1481: the two fallback classes are
  distinguishable` tests render the feature-1484 manual-routing
  contract instead of the retired pre-1484 fatal fallback class
- kind: red (pre-change reproduction on pristine HEAD `58ad4eed`)
- classification: assertionFailure
- criterion: feature-1484 manual routing (assessment.md)
- test: `test/plugins/tdd/commands/plan_command_bug_1481_test.dart`
- command: `dart test test/plugins/tdd/commands/plan_command_bug_1481_test.dart`
- exit: 1
- at: 2026-09-11
- output:
```
00:00 +5 -3: Some tests failed.
```
(5 green: the healable-spec invariants; 3 red: the stale pre-1484
assertions, see `tdd/red-evidence.md`)

## Cycle: fix (green)

- behavior: same three tests, expectations updated to the feature-1484
  manual-routing contract (warning block, both remedies, no unit route
  line, no dead-end tally)
- kind: green
- test: `test/plugins/tdd/commands/plan_command_bug_1481_test.dart`
- command: `dart test test/plugins/tdd/commands/plan_command_bug_1481_test.dart`
- exit: 0
- at: 2026-09-11
- output:
```
00:00 +8: All tests passed!
```

## Cycle: refactor (tooling only, no behavior change)

- kind: refactor
- change: none to production code. Test-only hygiene: the three tests
  were renamed to describe the CURRENT contract (the old names asserted
  a class that no longer exists), and the library doc comment gained a
  feature-1484 note. Assertions only ever read process output and temp
  fixtures; no new helpers introduced.
- verification: re-run green post-format (below).

## Cycle: verify (fresh re-run after cache purge)

- command: `rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*`
  then `dart test test/plugins/tdd/commands/plan_command_bug_1481_test.dart`
- exit: 0
- at: 2026-09-11
- output:
```
00:00 +8: All tests passed!
```

- companion gates:
  - `dart format` (file): Formatted 1 file (changed) → repo-wide
    dry-run `Formatted 2730 files (0 changed)` — clean.
  - `dart analyze test/plugins/tdd/commands/plan_command_bug_1481_test.dart`:
    `No issues found!`
  - chunked suite (`--exclude-tags flutter`, CI parity): all top-level
    chunks green; 6 dirs N/A (`slow || flutter` tag selectors match no
    tests: benchmark, integration, mock, plugins/helpers,
    plugins/tdd/helpers, plugins/tdd/scenarios); ONE pre-existing
    failure unrelated to this fix:
    `test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart`
    (+1 -3) — confirmed failing identically with this fix's diff
    stashed (pristine HEAD), so it predates the fix and is out of
    scope.
