# Issue — #1470 (P1 High)

**BUG 1470 — ARTIFACTS.JSON SILENTLY SWALLOWS CORRUPTION**

## Summary

`artifact_registry.dart` L293–294 catches `FormatException` and returns an
empty list, treating a corrupt `tdd/artifacts.json` identically to a missing
one. `register()` then sees "no prior records" and may re-register behaviors
with `Ownership.created`, emitting duplicate artifact files without warning
and rewriting the registry so prior ownership records are silently
destroyed.

## Already tracked

This assessment was produced from an existing issue — **no new issue was
filed** (that would duplicate it).

- **Issue**: #1470 — *artifacts.json silently swallows corruption*
- **URL**: https://github.com/arrrrny/zuraffa/issues/1470
- **State**: OPEN — labels `bug`, `tdd`
- **Assessment**: `.specify/bugs/1470-artifacts-json-corruption-silent/assessment.md`

## Root cause (confirmed against the tree)

```dart
// artifact_registry.dart L293–294:
} on FormatException {
  return [];  // ← Treats corrupt file identically to missing file
}
```

`_loadRecords` is the single load gate for every registry reader
(`register` → `preflight`, `append`, `loadAll`, `findRecord`,
`_appendRecord`), so the swallow covers the whole read surface.

## Impact

- Duplicate test/subject files (re-registration through `Ownership.created`)
- Ownership conflicts downstream (verify scope derived from a lying empty view)
- Silent data loss of the registry (rewrite destroys surviving records)
- Inconsistent with `RunStateStore`'s defensive approach
- Priority: P1 (High)

## Expected

Throw `ArtifactRegistryCorruptException` (like `RunStateStore` throws
`RunStateCorruptException`) with an actionable message naming the file and
the recovery path.

```dart
} on FormatException catch (e) {
  throw ArtifactRegistryCorruptException(
    'corrupted artifacts.json at $registryPath (invalid JSON: '
    '${e.message}). Recovery: …',
  );
}
```

## Hard constraints

- Fix ONLY the `FormatException` handling in `artifact_registry.dart`.
- Must pass `dart analyze` with no new warnings.
- Related: `run_state_store.dart` validation approach (the pattern to mirror).
