# Issue — #1469 (P0 Critical)

**BUG 1469 — JOURNAL.JSON MISSING flushToDisk BEFORE RENAME — CRASH LEAVES
TRUNCATED JOURNAL**

## Summary

`journal.dart` L720–722 writes `journal.json` to a temp file and renames it
without calling `flushToDisk()`. Bug #828's fsync discipline was applied to
`run-state.json` (run_state_store.dart L141) and `artifacts.json`
(artifact_registry.dart L377) but missed `journal.json`. Power loss between
`writeAsString` and `rename` could leave a truncated journal, breaking the
unified audit trail.

## Comparison with the stores #828 fixed

```dart
// run_state_store.dart L141:
await tmp.writeAsString(content);
await flushToDisk(tmp);  // ← present
await tmp.rename(path);

// artifact_registry.dart L377:
await tmpFile.writeAsString(raw);
await flushToDisk(tmpFile);  // ← present
await tmpFile.rename(file.path);

// journal.dart L720–722 (pre-fix):
await tmp.writeAsString('${encoder.convert(journal)}\n');
await tmp.rename(file.path);
// ← NO flushToDisk(tmp) before rename
```

## Expected

```dart
await tmp.writeAsString('${encoder.convert(journal)}\n');
await flushToDisk(tmp);  // ← ADD THIS
await tmp.rename(file.path);
```

## Hard constraints

- Fix ONLY the single `flushToDisk` call in `journal.dart`. Do NOT change the
  journal schema, entry format, or any other store.
- Must pass `dart analyze` with no new warnings.
- P0 priority — lost journal entries break the unified audit trail.
- Related: #828 (crash-safe state writes origin), `run_state_store.dart` L141,
  `artifact_registry.dart` L377.

## Remediation status

Fixed on branch `fix/1469-journal-flush-to-disk` — see `fix.md`; TDD evidence
in `tdd/` and `test.md`.
