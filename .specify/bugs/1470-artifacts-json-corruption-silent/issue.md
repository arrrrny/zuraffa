# Bug Issue: artifacts.json silently swallows corruption

- **Slug**: 1470-artifacts-json-corruption-silent
- **Fetched**: 2026-09-13
- **Issue**: 1470
- **URL**: https://github.com/arrrrny/zuraffa/issues/1470
- **State**: open
- **Severity**: P1 (High)
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug, tdd

## Body

### Problem

`artifact_registry.dart` L293-294 catches `FormatException` and returns
empty list, treating corrupt file identically to missing file. This means
`register()` sees "no prior records" and may re-register behaviors with
`Ownership.created`, emitting duplicate artifact files without warning.

### Impact

- Duplicate test/subject files
- Ownership conflicts
- Silent data loss of registry
- Inconsistent with `RunStateStore`'s defensive approach
- **Priority: P1** (High)

### Root Cause

```dart
// artifact_registry.dart L293-294:
} on FormatException {
  return [];  // ← Treats corrupt file identically to missing file
}
```

### Suggested Fix

Throw `ArtifactRegistryCorruptException` (like `RunStateStore` does) or at
minimum log a warning to stderr:

```dart
} on FormatException catch (e) {
  throw ArtifactRegistryCorruptException(
    'Corrupt artifacts.json at $registryPath: ${e.message}. '
    'Delete the file and re-run gen to rebuild the registry.'
  );
}
```

### References

- File: `lib/src/plugins/tdd/services/artifact_registry.dart`
- Compare: `run_state_store.dart` validation approach
- FR-012 documents missing-file behavior, not corrupt-file behavior

## Expected Behavior

A corrupt (unparseable) `artifacts.json` is loud: every registry reader and
writer surfaces a corruption error that names the file and the recovery
path, the way `RunStateStore.load()` raises `RunStateCorruptException`.
Missing-file behavior (FR-012, empty registry) is unchanged.

## Actual Behavior

`_loadRecords()` maps `FormatException` to `[]` — the corrupt registry is
indistinguishable from an absent one. `register()`/`preflight()` then
treats every behavior as new: files already on disk trigger spurious
`OwnershipConflict`s (or, for behaviors whose files were also lost, the
pair is silently re-created), and a follow-up successful write REPLACES the
registry content, destroying the prior records (silent data loss).

## Environment

- Repo: zuraffa 6.2.2 (master)
- Dart SDK: ^3.11.0
- Component: TDD plugin — artifact registry (spec 044, FR-005/006/007/008/012)
