# RED evidence — bug #1469 (fresh capture)

Captured pre-fix, on the state where `journal.dart` had no `flushToDisk`
call (test committed alone as `RED(1469)`):

```
$ dart test test/plugins/tdd/services/journal_test.dart --plain-name "U2.5"
00:00 +0: loading test/plugins/tdd/services/journal_test.dart
00:00 +0: JournalWriter (U2) U2.5: the journal write is fsync'd before the rename (bug #1469)
00:00 +0 -1: JournalWriter (U2) U2.5: the journal write is fsync'd before the rename (bug #1469) [E]
  Expected: non-empty
    Actual: []
  JournalWriter.append never fsync's the tmp file before the rename — the #828
  crash-safe write discipline (writeAsString → flushToDisk → rename) is missing
  for journal.json (bug #1469).

  package:matcher                                    expect
  test/plugins/tdd/services/journal_test.dart 233:9  main.<fn>.<fn>

00:00 +0 -1: Some tests failed.
```

Static corroboration (pre-fix):

```
$ grep -n "flushToDisk" lib/src/plugins/tdd/services/journal.dart
(no output)
$ grep -rn "flushToDisk" lib/ --include="*.dart" -l
lib/src/plugins/tdd/services/artifact_registry.dart
lib/src/plugins/tdd/services/run_state_store.dart
```
