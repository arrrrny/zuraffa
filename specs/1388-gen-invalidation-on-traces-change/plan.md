# Plan — Spec 1388 gen invalidation on traces change

**Branch**: `feat/1388-gen-invalidation-on-traces-change` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

## Technical Context

- **Reuse decision today**: `ArtifactRegistry.preflight`
  (`lib/src/plugins/tdd/services/artifact_registry.dart`) matches a
  prior record by behavior id, requires equal test/subject paths and
  both files on disk, then returns `Ownership.reused/reused`. No
  routing input participates.
- **Why the #1320 remedy misses this class**: `_regenerateStaleStub`
  (gen_command.dart) byte-compares the on-disk pair against a temp
  mirror render. A traces migration whose row carries no signature
  (`adaptive_layouts` — Presentation layout surface) leaves
  `contractShape` null, the mirror renders the same guard-only bytes,
  equality short-circuits, verdict stays `reused`.
- **Fingerprint inputs**: the resolved lane-plan traces cell (already
  carried by `Behavior.sourceCriterion` — `_findRow` maps
  `row.traces` verbatim; `TestListReader.read()` resolves the
  `04-ENGINE.md`/`04-SKIN.md` meta-index) and the sha256 of the
  feature's `spec.md`. Hash: `package:crypto` sha256 (direct dep).
- **Persistence**: `artifacts.json` records gain the OPTIONAL
  `gen_fingerprint` key (nullable, omitted for legacy records so
  untouched registries stay byte-stable through load/save cycles).
  Every field-by-field `ArtifactRecord` rebuild must thread it:
  `copyWithOwnership`, `_reanchorRecord`, `_canonicalize`
  (artifact_registry.dart), `_withPortablePaths`/`_withPaths`
  (migrate_paths_command.dart).
- **Guard-only marker detection** (regression assertions):
  `contentIsVacuousGreen` / `contentCarriesVacuousGuardMarker`
  (vacuous_guard.dart) + the `zfa:tdd: guard-only` warning token.

## Approach

1. New pure service `GenReuseFingerprint`
   (`lib/src/plugins/tdd/services/gen_reuse_fingerprint.dart`):
   `compute({tracesCell, specMd})` → sha256 hex over a
   version-delimited concatenation; `forFeature({featureDir,
   tracesCell})` reads `spec.md` (missing → empty component) and
   delegates.
2. `ArtifactRecord`: optional `genFingerprint` field, JSON
   `gen_fingerprint`, `copyWithGenFingerprint` copier; registry gains
   `refreshGenFingerprint({behaviorId, genFingerprint})` (find +
   rewrite via the existing write-and-rename path).
3. gen `_generate`: compute the fingerprint before building the
   proposed record (created records arm the gate). On a
   `reused/reused` preflight with a STORED fingerprint that differs:
   force `_regenerateStaleStub(forceRebuild: true)` — skips only the
   byte-equality short-circuit, keeps the progressed/ffi guards and
   the rollback — then refresh the stored fingerprint, print the
   #1388 note and report `verdict=regenerated`; when the machinery
   declines (progressed subject, ffi harness), refuse reuse with the
   `--> fix: zfa tdd reset <feature>` line, exit 1, verdict `refused`
   (JSON stays the final stdout line — house pattern bug #840).
4. Regression suite `test/plugins/tdd/commands/
   issue_1388_gen_reuse_fingerprint_test.dart` (U1–U6, red first)
   exercising scenarios 1–5 of the spec.

## Test strategy

TDD via the tdd extension: red-green-refactor per behavior (U1–U6 in
tdd/test-list.md), red evidence recorded in tdd/verification.md.
Suite: `dart test test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart`
plus the touched-area suites (gen_command, artifact_registry,
migrate_paths, bug_1320, bug_1377, issue_1309). `dart analyze` must
stay at zero new warnings; changed files formatted with
`dart format`.
