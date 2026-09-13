# TDD test list — Bug #1470 artifacts.json silently swallows corruption

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1470-a1 | test/plugins/tdd/services/artifact_registry_test.dart | unit | loadAll on a corrupt registry throws ArtifactRegistryCorruptException, not an empty list | FR-012, ArtifactRegistry._loadRecords | GREEN |
| A-1470-a2 | test/plugins/tdd/services/artifact_registry_test.dart | unit | findRecord on a corrupt registry throws too (same read path) | ArtifactRegistry.findRecord → _loadRecords | GREEN |
| A-1470-a3 | test/plugins/tdd/services/artifact_registry_test.dart | unit | register refuses to re-register on a corrupt registry (no silent duplicate pair, no registry rewrite) | FR-006, ArtifactRegistry.register → preflight → _appendRecord | GREEN |
| A-1470-a4 | test/plugins/tdd/services/artifact_registry_test.dart | unit | the corruption message names the registry path and the recovery (delete the file, re-run gen) | ArtifactRegistryCorruptException.toString, RunStateCorruptException parity | GREEN |
| A-1470-b1 | test/plugins/tdd/services/artifact_registry_test.dart | guard | missing-file behavior is unchanged (FR-012 guard): loadAll → [], findRecord → null, register → created | FR-012 missing-file contract (must not regress) | GREEN |
| A-1470-c1 | test/plugins/tdd/services/artifact_registry_test.dart (pre-existing, 15 tests) | regression | append/idempotent-reuse/ownership-conflict/dry-run/read-back/path-form normalization all still pass on the fixed loader | FR-005/006/007/008/009, issue #1397 path forms | GREEN |

RED evidence (suite): `dart test test/plugins/tdd/services/artifact_registry_test.dart`
with the exception type defined but the throw not yet wired → `+15 -4`
(A-1470-a1..a4 failed with the bug's own symptoms: `loadAll` emitted `[]`,
`findRecord` emitted `null`, `register` emitted `Ownership.created/created`;
A-1470-b1 passed, correctly). Scratch repro on unmodified master additionally
showed the P1 data-loss chain: corrupt file → `[]` → `register(B-003)` →
`Ownership.created` → registry rewritten to `[B-003]`, destroying B-001/B-002.
