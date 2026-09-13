# Bug Assessment: artifacts.json silently swallows corruption

- **Slug**: 1470-artifacts-json-corruption-silent
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1470
- **Verdict**: valid — reproduced at unit level; fix is a one-clause change
- **Severity**: P1 (High)

## Report (summarized)

`artifact_registry.dart` catches `FormatException` around the
`artifacts.json` decode and returns `[]`, making a corrupt registry
indistinguishable from a missing one (FR-012 covers only the missing-file
case). Downstream, `register()` sees "no prior records" and re-registers
behaviors with `Ownership.created`, emitting duplicate artifact files and
destroying the prior registry content on the next successful write.

## Symptom

With a corrupt `specs/<feature>/tdd/artifacts.json`:

1. `loadAll()` returns `[]` — silently (the reader that verify/run/doctor
   and the registry's own writers all funnel through).
2. `preflight()`/`register()` treats every behavior as brand new. For a
   behavior whose artifacts still exist on disk, the user gets a
   misleading `OwnershipConflict` ("exists on disk but the registry has no
   recorded ownership") — technically true, caused by corruption, but the
   registry then stays broken. For a behavior whose artifacts are absent,
   `gen` recreates the pair and `_appendRecord` REWRITES the registry,
   permanently discarding every prior record (silent data loss).
3. No stderr warning is emitted anywhere in the flow.

## Reproduction

Unit-level (this repo, `test/plugins/tdd/services/artifact_registry_test.dart`):

1. Create a feature dir; write `{ "records": [` (truncated JSON) to
   `<featureDir>/tdd/artifacts.json`.
2. Call `registry.loadAll()` → returns `[]` (RED expectation: throws
   `ArtifactRegistryCorruptException`).
3. Call `registry.register(sampleRecord)` → returns
   `Ownership.created` for both artifacts and rewrites the registry file
   with exactly one record — the pre-corruption content is gone (RED
   expectation: throws before any write).

## Suspected Code Paths

- `lib/src/plugins/tdd/services/artifact_registry.dart` —
  `_loadRecords()` L283-296; the `on FormatException { return []; }`
  clause at L293-294 is the only corruption swallow in the file.
  `loadAll()`, `findRecord()`, `preflight()`, `append()` and
  `_appendRecord()` all funnel through `_loadRecords()`, so one fix
  covers readers and writers.

## Root Cause Hypothesis

Confirmed (not just a hypothesis). `_loadRecords()` catches
`FormatException` from `jsonDecode` and returns `[]`. The empty-list
return value is overloaded: it means both "registry absent — fresh
feature" and "registry unreadable — corruption". Callers cannot
distinguish the two, and the write path (`register` → `_appendRecord`)
treats it as the former.

Reference behavior in the same plugin: `RunStateStore.load()` maps every
parse failure to `RunStateCorruptException` whose message names the file
and the recovery path (`run_state_store.dart`, `_validated()`). The
sibling stores (`gap_ledger_store.dart`, `corpus_manifest_store.dart`,
`corpus_progress_store.dart`) follow the same throw-on-corrupt pattern.
`artifact_registry.dart` is the outlier.

## Proposed Remediation

Throw a dedicated `ArtifactRegistryCorruptException` from the existing
`on FormatException` clause, with a message naming the registry path and
the recovery action ("delete the file and re-run gen to rebuild the
registry"). This mirrors `RunStateCorruptException` (same shape:
`message` field, `toString() => message`).

Hard constraints from the bug report:

- Fix ONLY the `FormatException` handling in `artifact_registry.dart` —
  no registry-format, ownership-model, or state-machine changes.
- Must not break normal missing-file behavior (the
  `if (!await file.exists()) return [];` guard stays).
- Must pass `dart analyze` with no new warnings.

Blast-radius note (accepted, intended): `_loadRecords()` is also the
read path for verify/run/doctor/realize/compose/wire/func/reset/migrate
viewers. After the fix, a corrupt registry makes those commands fail
loudly instead of silently reporting an empty feature — that is the
desired P1 behavior change, and it is exactly how `RunStateStore` and
the other stores already behave. No call-site changes are required: the
exception is additive, and every caller today either propagates to the
CLI error handler or explicitly matches on store exceptions.

## Risks & Considerations

- Readers that used to "work" on a corrupt registry now surface an
  error. This is the point of the fix (fail loud), and it matches the
  established store contract; regression sweep must confirm no suite
  fixture relies on the swallow.
- Scope deliberately excludes the well-formed-but-wrong-shape cases
  (top-level non-map, non-map records) which currently raise `TypeError`
  from the casts; widening to those would change more than the
  `FormatException` handling and is out of scope per the constraints.
- `readDropped()`-style secondary readers (cf. `run_state_store.dart`)
  do not exist for the artifact registry; no dual-path concern.

## Open Questions

- None blocking. The issue offers "throw or at minimum log a warning";
  throw is the consistent choice (matches `RunStateStore` and the other
  stores) and is what the suggested patch implements.
