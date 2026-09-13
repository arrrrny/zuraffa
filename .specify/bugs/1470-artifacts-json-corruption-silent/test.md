# Test report — Issue #1470

## Test design

New suite
`test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart`
(group `bug #1470 — corrupt artifacts.json must be loud, never empty`),
unit-level over `ArtifactRegistry` against a temp fixture
(`<tmp>/specs/044-test-tdd-generation`), same harness shape as the
existing `artifact_registry_test.dart`.

Behavioral (no source parsing needed — corruption is directly
reproducible in-process, unlike #1469's unobservable fsync):

1. **U-1470-a1** `loadAll` throws `ArtifactRegistryCorruptException` on
   invalid JSON (truncated JSON body). The RED discriminator: pre-fix it
   returned `[]` silently.
2. **U-1470-a2** `register` refuses to re-register through a corrupt
   registry and the corrupt bytes survive on disk untouched — pre-fix,
   B-003 came back `Ownership.created` and the rewrite destroyed
   B-001/B-002 (the duplicate/data-loss symptom).
3. **U-1470-a3** `findRecord` (the reader path) also refuses a corrupt
   registry.
4. **U-1470-a4** the exception message names `artifacts.json`, contains
   the full `registryPath`, and prescribes a recovery (case-insensitive
   `recovery` check).
5. **U-1470-a5** a MISSING registry is still an empty one (`loadAll` →
   `[]`, `findRecord` → `null`) — FR-012 unchanged; corrupt ≠ missing is
   the distinction the fix must not erase.

Corruption fixtures: truncated JSON (`'{"records": [ {"behavior_id":
"B-001" '`), non-JSON text (`'not json at all'`), and structurally-broken
JSON (`'{]]}'`).

## RED evidence (pre-fix)

Behavioral probe (pre-fix code, `tool/bug1470_red_probe.dart`, since
removed):

```
RED-1 loadAll() on a CORRUPT registry returned 0 records with no exception (identical to a missing file).
RED-2 register(B-003) returned ownership test=Ownership.created subject=Ownership.created (no corruption diagnosed).
RED-3 registry file after register() now holds [B-003] — B-001/B-002 ownership records silently destroyed: true.
```

Committed suite pre-fix: compile-level RED —
`Error: 'ArtifactRegistryCorruptException' isn't a type.` (full text in
`red-evidence.md`).

## GREEN evidence (post-fix)

```
00:00 +5: All tests passed!
```

All five behaviors pass; the suite is deterministic (no sleeps, no network,
temp-dir fixture torn down per test).

## Regression sweep (post-fix, this session)

- Registry-adjacent suites, one command:
  `dart test test/plugins/tdd/services/artifact_registry_test.dart
  test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart
  test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart
  test/plugins/tdd/services/mutation_scope_test.dart
  test/plugins/tdd/services/spec_fuzz_auditor_test.dart
  test/plugins/tdd/services/behavior_kind_trace_test.dart
  test/plugins/tdd/services/mutation_auditor_test.dart`
  → `+68: All tests passed!`
- Chunked fast-suite sweep (repo policy `tools/run_tests_chunked.sh`
  semantics: per-folder chunks, kernel cache cleared between chunks,
  flutter-tagged excluded): 103 runnable chunks + 4 root-file chunks
  (905 tests in `tdd/services` root, 519 in `tdd` root) — all passed;
  5 all-slow folders SKIP. Full table: `../../tdd/verification.md`.
