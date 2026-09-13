# tdd.verify — Bug #1470 artifacts.json silently swallows corruption

- **Verified**: 2026-09-13, this session, on
  `fix/1470-artifacts-json-corruption-silent` (working tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64
- **Scope**: `artifact_registry.dart` (`_loadRecords` FormatException
  clause + new `ArtifactRegistryCorruptException`) and the registry suite,
  then the chunked regression sweep below.

## Verdict: PASS

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/services/artifact_registry.dart \
             test/plugins/tdd/services/artifact_registry_test.dart
→ No issues found!
```

Full-project `dart analyze`: **112 `info` lints, 0 errors / 0 warnings** —
identical to the pre-change baseline measured on this same tree with the
fix stashed (112). No new analyzer output of any severity.

## 2. The bug suite (REAL runs in this session)

```
dart test test/plugins/tdd/services/artifact_registry_test.dart
→ 00:00 +20: All tests passed!
```

- RED (exception type defined, throw not yet wired): `+15 -4` — the four
  corrupt-registry tests failed with the bug's own symptoms
  (`loadAll` emitted `[]`, `findRecord` emitted `null`, `register`
  emitted `Ownership.created/created` and rewrote the corrupt file's
  pending state; the FR-012 missing-file guard passed throughout).
- GREEN (throw wired): `+20: All tests passed!` — 15 pre-existing +
  5 new, including the two guards that must NOT change
  (`OwnershipConflict` stop, FR-012 empty-registry contract).
- Post-format re-run: same file re-run after `dart format .` → `+20:
  All tests passed!` again.

Scratch reproduction on unmodified master (pre-fix, deleted after):

```
loadAll() on CORRUPT file -> []                <-- silent empty list
register(B-003) -> Ownership.created           <-- re-registered as fresh
registry file now contains: [B-003]            <-- B-001/B-002 DESTROYED
```

The same script post-fix dies with:

```
Unhandled exception:
Corrupt artifacts.json at /tmp/repro_1470_.../specs/044-demo/tdd/artifacts.json:
Unexpected end of input. Delete the file and re-run gen to rebuild the registry.
#0 ArtifactRegistry._loadRecords (package:zuraffa/.../artifact_registry.dart)
```

## 3. Neighbor suites (REAL runs in this session)

```
dart test test/plugins/tdd/services/   → 01:48 +950: All tests passed!
dart test test/plugins/tdd/commands/   → 03:13 +533: All tests passed!
```

Covers `RunStateStore` (the referenced validation approach), the registry's
direct consumers (gen/verify/run/realize/compose/wire/func/view/doctor/
reset/migrate-paths) and the ownership/model machinery the fix must not
perturb.

## 4. Chunked fast suite (REAL runs in this session)

`tools/run_tests_chunked.sh` (kernel cache cleared per chunk), resumed via
`tools/run_chunks_range.sh` after two wall-clock interruptions — every
chunk executed exactly once, 0 failures everywhere:

| Run | Chunks | Passed | SKIP (exit 79) | Failed |
| --- | ------ | ------ | -------------- | ------ |
| 1   | 1–27   | 25     | 2              | 0      |
| 2   | 28–60  | 32     | 1              | 0      |
| 3   | 61–85  | 24     | 1              | 0      |
| 4   | 86–104 | 18     | 1              | 0      |
| all | 104    | 99     | 5              | **0**  |

The 5 SKIP chunks are the pre-existing all-slow folders
(`dart_test.yaml` excludes `slow` from the fast tier; the repo's own
verification notes record the same 5-folder skip pattern at baseline).

## 5. Formatter

```
dart format .   → Formatted 2763 files (1 changed)
git diff --stat → 2 files changed, 130 insertions(+), 2 deletions(-)
```

The single reformat is the new test file (line-joining in the new group);
`artifact_registry.dart` was already format-clean. No unrelated file was
touched.

## 6. Host caveats

- Cloud Linux agent, no Flutter SDK: flutter-tagged tests are excluded by
  the chunked runner by design (matches the repo's documented
  cloud-agent workflow); the slow tiers (regression/integration/property/
  benchmark) were not run — they spawn temp projects and are documented
  as unsafe on small/disposable agents (dart_test.yaml header).
- The interrupted wall-clock runs resumed from recorded chunk indices;
  no chunk was skipped or double-counted (per-run tallies sum to 104).
