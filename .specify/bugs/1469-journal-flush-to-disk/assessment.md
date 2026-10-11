# Assessment — Issue #1469 (journal.json missing flushToDisk before rename)

## Root cause (empirically confirmed)

`JournalWriter.append` in `lib/src/plugins/tdd/services/journal.dart` (now
L720–728) persists `journal.json` with the temp-file-then-rename pattern but,
before this fix, omitted the fsync between the write and the rename:

```dart
// journal.dart (pre-fix, L720–722):
const encoder = JsonEncoder.withIndent('  ');
final tmp = File('${file.path}.tmp');
await tmp.writeAsString('${encoder.convert(journal)}\n');
await tmp.rename(file.path);          // ← no flushToDisk(tmp) before rename
```

Bug #828 (crash-safe state writes) introduced `flushToDisk()` and applied the
write → fsync → rename discipline to the other two committed TDD stores:

- `run_state_store.dart` `save()` (L141): `await flushToDisk(tmp);` present.
- `artifact_registry.dart` (L377): `await flushToDisk(tmpFile);` present.

The sweep missed `journal.dart`: the temp-rename shape is there, but the
fsync was never added. Confirmed by `grep -n flushToDisk lib/` — the symbol
appears in exactly `run_state_store.dart` (definition + use) and
`artifact_registry.dart` (use), never in `journal.dart`.

## Why it matters (P0)

`writeAsString` returns when the bytes reach the page cache, not the disk.
If power is lost (or the host crashes) between the `writeAsString` and the
`rename`, the kernel can commit an empty or partially-written `journal.json.tmp`
while the rename to `journal.json` still lands. The journal — the unified
audit trail read by `zfa tdd status`, `zfa tdd theater`, and `zfa tdd prove` —
would then be truncated or empty: lost journal entries, silently. The #828
rationale ("a committed store write must survive the crash that interrupts
the run") applies verbatim to the journal, which is committed on every
engine/skin/meta cycle.

## Reproduction

No runtime repro is possible or needed — fsync omission is a code-level gap;
a crash between two adjacent await points cannot be provoked deterministically
in-process. Evidence is:

1. Static: the pre-fix source shows no `flushToDisk` reference in
   `journal.dart` (grep above), versus both sibling stores.
2. Test: the new U2.5 guard in `test/plugins/tdd/services/journal_test.dart`
   parses `JournalWriter.append` and fails pre-fix with
   `JournalWriter.append never fsync's the tmp file before the rename...`
   (see `red-evidence.md`).

## Fix shape (and constraints honored)

Single-line behavioral fix: `await flushToDisk(tmp);` immediately before
`await tmp.rename(file.path);`, plus the import the call requires
(`import 'run_state_store.dart' show flushToDisk;` — Dart imports are not
transitive, so journal.dart cannot reach the helper through its existing
`artifact_registry.dart` import; a scoped `show` keeps the added surface to
one symbol).

- Journal schema, entry format, and every other store: untouched.
- The schema-file write (`journal.schema.json`, L684–686 pre-fix) keeps its
  existing shape: the issue scope is journal.json durability; widening the
  diff would violate the one-call constraint.

`flushToDisk()` itself is reused verbatim from `run_state_store.dart`
(L164–171): open append-mode handle, `raf.flush()` (fsync on POSIX), close.
