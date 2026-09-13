# TDD test list — Bug #1470 artifacts.json silently swallows corruption

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1470-a1 | test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart | unit | loadAll throws ArtifactRegistryCorruptException on invalid JSON (pre-fix: silently returned []) | issue #1470 root cause (L293–294 swallow), FR-012 corrupt-vs-missing split | GREEN |
| U-1470-a2 | test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart | unit | register refuses to re-register through a corrupt registry; corrupt bytes survive untouched on disk (pre-fix: Ownership.created + rewrite destroyed B-001/B-002) | issue #1470 impact (duplicate artifacts, silent data loss), preflight ownership gate | GREEN |
| U-1470-a3 | test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart | unit | findRecord (reader path) also refuses a corrupt registry | issue #1470 (every reader funnels through _loadRecords) | GREEN |
| U-1470-a4 | test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart | unit | the exception names artifacts.json, contains the full registry path, and prescribes recovery | RunStateCorruptException message discipline (U9), issue #1470 expected behavior | GREEN |
| U-1470-a5 | test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart | unit | a MISSING registry is still an empty one (loadAll → [], findRecord → null) — corrupt ≠ missing | FR-012 (unchanged, pinned) | GREEN |

## Red evidence (pre-fix, this session)

Behavioral probe against pre-fix code (output preserved verbatim in
`.specify/bugs/1470-artifacts-json-corruption-silent/red-evidence.md`):

- RED-1: `loadAll()` on a corrupt registry returned 0 records, no exception.
- RED-2: `register(B-003)` returned `Ownership.created` / `created` with no
  corruption diagnosis.
- RED-3: the registry rewrite left only `[B-003]` — B-001/B-002 ownership
  records silently destroyed.

The committed suite's pre-fix state was a compile-level RED
(`'ArtifactRegistryCorruptException' isn't a type`).

## Suite placement note

The behaviors are unit tests in the registry's own service suite
(`test/plugins/tdd/services/`), colocated with `artifact_registry_test.dart`.
They are fast-tier (no `slow`/`flutter` tags) and run in the default
`dart test` selection and in the chunked sweep.
