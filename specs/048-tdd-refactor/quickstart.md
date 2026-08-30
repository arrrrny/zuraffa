# Quickstart: validating `zfa tdd refactor`

Runnable end-to-end validation. Prerequisites: repo checkout on branch
`048-tdd-refactor`, Dart SDK on PATH.

## 1. Unit suite (fast)

```bash
dart test test/plugins/tdd/services/refactor_passes_test.dart \
          test/plugins/tdd/services/tree_snapshot_test.dart \
          test/plugins/tdd/models/cycle_entry_test.dart
```

Expected: all pass, no `slow` tags.

## 2. Command + scenario suite (slow)

```bash
dart test --tags slow test/plugins/tdd/refactor_command_test.dart \
     test/plugins/tdd/scenarios/sc_010_refuses_red_suite_test.dart \
     test/plugins/tdd/scenarios/sc_011_tool_only_and_test_immutable_test.dart \
     test/plugins/tdd/scenarios/sc_012_reproves_green_test.dart
```

Expected: all pass, driving the real CLI against `TddFixture` projects.

## 3. Manual smoke: green → normalize → re-proven green

```bash
cd <fixture project with a green suite>
dart run bin/zfa.dart tdd refactor
echo "exit=$?"   # expect 0
tail -15 specs/<f>/tdd/cycle-log.md   # expect a refactor entry with actions: block
```

Expected: summary line `refactor: ... outcome=refactored applied=<n>` (or
`clean` when nothing needed changing); evidence per
[contracts/refactor.md](contracts/refactor.md).

## 4. Refusal on red

```bash
# fixture with one failing test
dart run bin/zfa.dart tdd refactor; echo "exit=$?"
```

Expected: non-zero, `outcome=not-green`, the failing test named, zero files
modified anywhere in the project.

## 5. Test-directory immutability

```bash
find test -type f -exec shasum {} + > /tmp/t_before.sums
dart run bin/zfa.dart tdd refactor
find test -type f -exec shasum {} + > /tmp/t_after.sums
diff /tmp/t_before.sums /tmp/t_after.sums && echo TEST-DIR-IMMUTABLE
```

Expected: no diff, regardless of outcome (spec FR-004 / SC-002).
