# TDD cycle log — bug #1469

Branch: `fix/1469-journal-flush-to-disk` · Dart SDK 3.13.3 (stable)

## Cycle 1 — U2.5 (the one behavior on the test list)

**RED** — wrote `U2.5: the journal write is fsync'd before the rename (bug
#1469)` first, ran against un-fixed `journal.dart`:

```
dart test test/plugins/tdd/services/journal_test.dart --plain-name "U2.5"
00:00 +0 -1: ... [E]
  Expected: non-empty
    Actual: []
  JournalWriter.append never fsync's the tmp file before the rename — the #828
  crash-safe write discipline (writeAsString → flushToDisk → rename) is missing
  for journal.json (bug #1469).
  test/plugins/tdd/services/journal_test.dart 233:9
00:00 +0 -1: Some tests failed.
```

Committed: `RED(1469): journal — failing test asserting flushToDisk before rename` (c46d33fa).

**GREEN** — added `await flushToDisk(tmp);` (+ scoped import) to
`JournalWriter.append`; same test:

```
dart test test/plugins/tdd/services/journal_test.dart --plain-name "U2.5"
00:00 +1: All tests passed!
```

Whole unit file, no regressions:

```
dart test test/plugins/tdd/services/journal_test.dart
00:00 +18: All tests passed!
```

Committed: `GREEN(1469): journal — add flushToDisk before rename; crash-safe journal writes` (064fb88d).

**REFACTOR** — none: the fix is the minimal disciplined line; the only
refactor-class change was `dart format` on the touched test file (no
behavior change; formatter is a no-op on `journal.dart`).

## Test-authoring fixups during the cycle (test-side only, no lib changes)

- analyzer-14 AST API: `ClassDeclaration.namePart.typeName.lexeme` +
  `ClassDeclaration.body.members` (matches issue_1173's usage).
- Fixed my own wrong assertion: `flushToDisk(tmp)` is a bare top-level call
  (null receiver) — assert `methodName.name == 'flushToDisk'`, not `target`.
