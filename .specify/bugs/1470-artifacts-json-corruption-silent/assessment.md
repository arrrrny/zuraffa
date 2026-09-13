# Assessment — Issue #1470 (artifacts.json silently swallows corruption)

## Root cause (empirically confirmed)

`ArtifactRegistry._loadRecords` in
`lib/src/plugins/tdd/services/artifact_registry.dart` (pre-fix L283–296)
caught `FormatException` from the registry JSON decode and returned `[]`:

```dart
// artifact_registry.dart (pre-fix, L293–294):
} on FormatException {
  return [];  // ← Treats corrupt file identically to missing file
}
```

Every reader funnels through `_loadRecords`: `register()` → `preflight()`,
`append()`, `loadAll()`, `findRecord()`, `_appendRecord()`. A corrupt
`tdd/artifacts.json` therefore presented to all of them exactly like a
freshly-initialized feature with zero records (FR-012's missing-file
answer), with no diagnostic anywhere.

Reproduced pre-fix with a probe (`tool/bug1470_red_probe.dart`, since
removed; output preserved in `red-evidence.md`):

1. valid two-record registry (B-001, B-002) written, then corrupted on disk;
2. `loadAll()` returned 0 records with NO exception (RED-1);
3. `register(B-003)` returned `Ownership.created` with no corruption
   diagnosis (RED-2);
4. `_appendRecord` rewrote the file as a single-record registry — B-001 and
   B-002's ownership rows silently destroyed (RED-3).

## Why it matters (P1 High)

- **Silent data loss**: the registry is the durable ownership link between
  `gen` (writer) and `verify`/`run` (readers). The rewrite-on-corrupt path
  destroys every surviving behavior's ownership record, and with it the
  ability to ever diagnose what was lost.
- **Duplicate artifacts**: `register()` believing "no prior records" walks
  the `Ownership.created` path; the issue text describes gen re-registering
  behaviors and emitting duplicate test/subject files without warning.
- **Ownership conflicts**: verify derives mutation scope from
  `loadAll()`; an empty view silently narrows scope instead of failing.
- **Inconsistency with the sibling store**: `RunStateStore` already maps
  every parse failure to `RunStateCorruptException` naming the file and the
  recovery path (U9). The registry — the OTHER committed TDD store — kept
  the swallow, so the same class of on-disk corruption is loud in one store
  and silent in the other.

## Reproduction

Deterministic, in-process: corrupt bytes in `artifacts.json` +
`register()`/`loadAll()`. See `red-evidence.md` for the probe output and
the committed test's pre-fix failure.

## Fix shape (and constraints honored)

Behavioral change confined to the `FormatException` handling in
`artifact_registry.dart` (single file in lib/):

- New `ArtifactRegistryCorruptException` (`implements Exception`, message +
  `toString() => message`) mirroring `RunStateCorruptException`'s shape.
- `on FormatException catch (e)` now throws with the registry path, the
  parser's cause, and a recovery prescription (repair to valid registry
  JSON or restore from version control; do not delete — deletion is what
  re-registers every behavior as created and duplicates artifact files).

The issue's suggested message offered "delete the file and re-run gen" as
recovery; the fix deliberately prescribes repair/restore instead — with
surviving artifact files on disk, deletion + re-gen is precisely the
duplicate-file symptom the issue reports. The thrown contract (type, file
path, cause, actionable recovery) is exactly what the issue asks for.

- Missing-file behavior (FR-012, `loadAll` on absent file → `[]`) is
  unchanged and pinned by a new test — corrupt ≠ missing.
- No other file in lib/ changed (`git diff --stat` = one lib file).
- Out of scope by the same constraint: `RunStateStore.readDropped`'s
  intentional `FormatException → const []` (documented there: `load()` is
  the corruption gate that fires first), and shape violations that raise
  `TypeError` rather than `FormatException` (valid JSON, wrong shape).
