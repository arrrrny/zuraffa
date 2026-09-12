# Test report — Issue #1469

## Test design

New test **U2.5 "the journal write is fsync'd before the rename (bug #1469)"**
in `test/plugins/tdd/services/journal_test.dart` (group `JournalWriter (U2)`).

Why syntactic: `flushToDisk` is a top-level function over `dart:io` files and
is not injectable (refactoring it for injection would violate the
single-call constraint), and fsync is not observable from user space without
injection. A crash between two adjacent awaits cannot be reproduced
deterministically in-process. The suite already has a blessed pattern for
exactly this situation — source-level invariant guards
(`test/regression/issue_1173_engine_purity_test.dart`), and the bug report
itself describes the gap as "a code-level gap… verify the
write-then-flush-then-rename sequence".

What U2.5 asserts (via `package:analyzer` parse of `journal.dart`, using the
repo's `findProjectRoot()` helper for CWD-race safety):

1. `JournalWriter.append` contains a `flushToDisk` invocation at all (the RED
   discriminator — fails pre-fix).
2. The journal tmp is declared from `file.path}.tmp'` (not the schema
   write's `schemaFile.path` tmp), disambiguating the two write sites.
3. Ordering on the journal pair: `writeAsString` → exactly one `flushToDisk`
   → `rename`, with the flush invocation sitting strictly between the write
   and rename offsets and targeting `tmp`.
4. The rename argument is `file.path` (i.e. journal.json, not the schema file).

## RED evidence (pre-fix, commit c46d33fa's parent state)

```
00:00 +0: JournalWriter (U2) U2.5: the journal write is fsync'd before the rename (bug #1469)
00:00 +0 -1: JournalWriter (U2) U2.5: the journal write is fsync'd before the rename (bug #1469) [E]
  Expected: non-empty
    Actual: []
  JournalWriter.append never fsync's the tmp file before the rename — the #828
  crash-safe write discipline (writeAsString → flushToDisk → rename) is missing for
  journal.json (bug #1469).
00:00 +0 -1: Some tests failed.
```

## GREEN evidence (post-fix)

```
00:00 +0: JournalWriter (U2) U2.5: the journal write is fsync'd before the rename (bug #1469)
00:00 +1: All tests passed!
```

Whole file (17 pre-existing + U2.5):

```
00:00 +18: All tests passed!
```

## Regression coverage actually exercised post-fix

- `test/plugins/tdd/services/journal_test.dart` — 18/18
- `+ run_state_store_test.dart + artifact_registry_test.dart` — 47/47
- `test/plugins/tdd/theater/theater_journal_integration_test.dart` — 3/3
- `test/plugins/tdd/commands` — 507 (chunked batch)
- Broader chunked sample — see `tdd/verification.md`

The pre-existing U2.1/U2.2 behavioral tests (append writes valid journal,
entries preserved, no .tmp left behind) now run through the fixed
write→flush→rename path on every append — content durability is
behaviorally re-verified post-fix, not just syntactically.
