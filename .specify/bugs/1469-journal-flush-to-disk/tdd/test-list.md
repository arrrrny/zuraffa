# TDD test list — bug #1469 (journal flushToDisk before rename)

Driven from `assessment.md` (root cause) and the issue's hard constraints.
Every behavior gets a failing test before its implementation.

| # | Test | File | Level | Status |
|---|------|------|-------|--------|
| U2.5 | `JournalWriter.append` persists the journal via writeAsString → flushToDisk(tmp) → rename(file.path): a `flushToDisk` invocation exists, sits strictly between the journal write and its rename, targets `tmp`, and the rename lands on `file.path` (journal.json — not the schema tmp) | `test/plugins/tdd/services/journal_test.dart` | syntactic guard (analyzer AST) over `JournalWriter.append` | RED → GREEN |

Companion regression behavior (pre-existing, re-run through the fixed path —
must stay green):

| # | Test | File | Status |
|---|------|------|--------|
| U2.1 | first append writes journal.json + journal.schema.json (valid content) | `test/plugins/tdd/services/journal_test.dart` | green (unchanged) |
| U2.2 | appends preserve prior entries, no tmp left behind | `test/plugins/tdd/services/journal_test.dart` | green (unchanged) |
| U2.3 | schema file written once, not per append | `test/plugins/tdd/services/journal_test.dart` | green (unchanged) |
| U3.* | reader contract over the journal the writer now fsyncs | `test/plugins/tdd/services/journal_test.dart` | green (unchanged) |

Out of scope by the issue's constraints (documented, not tested here):
schema-file write path durability, entry format, other stores.
