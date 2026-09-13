**Template Version**: `zuraffa-1.0`

# Plan: 1570-make-methods-append-propagate-mock

## Technical Context

- Language/Dart SDK: `^3.11.0` (repo constraint), toolchain Dart 3.13.3 stable.
- CLI surfaces involved:
  - `lib/src/plugins/mock/builders/mock_datasource_builder.dart` — THE fix
    site. `generateMockDataSource(config)` currently branches:
    `if (config.appendToExisting && fileExists) { …append… }` else fresh
    build → `FileUtils.writeFile(force: options.force)` → `action:
    'skipped'` when the file exists and force is false (the
    existence-based skip, `file_utils.dart` L53-66). That skip is what
    leaves a `mock create`-certified mock without the appended members.
  - `lib/src/utils/file_utils.dart` — `writeFile` skip semantics (NOT
    modified; the fix avoids reaching the fresh-path write when stale).
  - `lib/src/utils/method_extractor.dart` —
    `extractMethodsFromInterface(filePath, className)` →
    `List<ParsedUseCaseInfo>` (name/paramsType/returnsType/useCaseType
    per interface member; AST-only, no package resolution). The same
    primitive `MockCertificationService.certify` uses for
    `interfaceMethods`.
  - `lib/src/core/ast/ast_helper.dart` — `parseFile` / `findClass` /
    `findMethods`: implemented-member extraction for the mock class
    (same primitives as the certification's `implementedMethods`).
  - `lib/src/core/ast/append_executor.dart` — idempotent member
    addition (`AppendRequest.method`); the append path already uses it.
  - `lib/src/core/context/file_system.dart` — the `FileSystem` seam the
    builders receive from `PluginContext` (tests inject in-memory FS).
  - `lib/src/models/generator_config.dart` — `methods`, `repo`,
    `isCustomUseCase`, `paramsType`, `returnsType`, `appendToExisting`,
    `revert`; `repo` → interface entity resolution (`repo!.replaceAll(
    'Repository', '')`), already mirrored by the certification.
  - `lib/src/plugins/mock/services/mock_certification.dart` — the
    shape-comparison precedent: interface members vs implemented
    members → `missingMethods` / `inventedMethods`. FR-003 pins the
    detector to these exact primitives so the repair and the cert gate
    can never disagree about staleness.
- Sibling context (same failure class, already merged): #1530
  (build-gate barrel-hide) — the "generated tree needs a coherence
  pass" family; this feature closes the mock-lane member.

## Root Cause (verified by reproduction)

Reproduced with the real CLI (`dart run zuraffa:zfa`) in a scratch
project: a mock created earlier by `mock create --methods=get`
certifies a smaller member set. Later `zfa make --methods=get,getList`
runs where the mock lane reaches `generateMockDataSource` with
`appendToExisting=false` (older/customized `.zfa.json` without the
`method_append` plugin default, or any lane entry that does not set the
append flags) take the fresh path and the write is refused by the
existence check (`exists && !force` → `skipped`). The interface lane
appends (or the interface was already regenerated), the mock does not →
`non_abstract_class_inherits_abstract_member` → `zfa build` gate fails.
`mock create` itself shows the same skip ("⏭ Skipped (use --force to
overwrite)") on a stale existing mock — the certified mock can never
heal without `--force`.

## Technical Approach

1. **New mock-lane detector** (private to the mock plugin, new file
   `lib/src/plugins/mock/services/mock_staleness_detector.dart`):
   `detectMockStaleness({entity, entitySnake, mockClass, mockPath,
   interfacePath, fileSystem})` → `List<ParsedUseCaseInfo>` (the
   missing members, empty = in-sync / fail-open).
   - Fail-open guards: interface file missing, interface class missing,
     mock file/class missing or unparseable → `const []`.
   - Drift = interface members whose `fieldName` is not in the mock's
     implemented member-name set (invented surface intentionally NOT
     repaired — cert gate's job).
2. **Wire into `generateMockDataSource`** (mock lane only): before the
   fresh-path write, when `fileExists && !config.appendToExisting &&
   !options.force && !config.revert`, run the detector. On missing
   members: print the honest notice (entity, missing members, file) and
   take the EXISTING append block (idempotent member addition, write
   with `force: true` → ledger `updated`). The appended method set
   becomes `config.methods`-driven impls PLUS impls synthesized for the
   missing members from their `ParsedUseCaseInfo` shapes (same body
   patterns the builder already emits: `logger.info` → delay →
   `sampleList` / `sample<Entity>` / `Future.value()`; Stream members →
   `Stream.fromFuture` with a `Future<T>`-typed delay).
   - Review round: the repair is strictly ADDITIVE (members the mock
     already declares are never re-emitted — the append strategy
     replaces same-name members, clobbering customized bodies), and the
     synthesized signatures mirror the interface declaration
     (parameter-less members carry no `params`; the `--init`
     `Stream<bool> get isInitialized` stays a getter). Parameter count
     and getter-ness travel on `ParsedUseCaseInfo` from
     `MethodExtractor.extractMethodsFromInterface` (`'NoParams'`
     paramsType alone cannot express either).
3. **Interfaces touched**: none outside the mock plugin. The detector
   is exercised through `generateMockDataSource` (the public lane
   entry) so the contract surface stays `GeneratedFile`.

## Constitution Check

*GATE: pass — read against `.specify/memory/constitution.md`.*

- Engine purity: the fix is pure Dart (no Flutter imports, no
  `zuraffa_flutter` reference) — mock lane is CORE.
- Honest artifacts: the repair prints a notice and emits `updated`;
  no silent skip of a drifted artifact, no lying success.
- Generated-marker respect: the mock datasource carries the Generated
  provenance header; repairing a generated file in place is the
  lane's contract (same as the existing append path).
- One PR per feature; no gate/writer changes outside the mock lane.

## Project Structure

### Documentation (this feature)

```text
specs/1570-make-methods-append-propagate-mock/
├── spec.md
├── plan.md
├── tasks.md
└── tdd/
    ├── test-list.md
    ├── cycle-log.md
    └── verification.md
```

### Source Code (repository root)

```text
lib/src/plugins/mock/
├── builders/mock_datasource_builder.dart   # lane wiring + repair notice + missing-member impls
└── services/mock_staleness_detector.dart   # NEW: shape-check staleness detection (fail-open)

test/plugins/mock/
├── mock_datasource_builder_1570_test.dart          # NEW: repair / precedence / honesty behaviors + U1 detector exactness
└── mock_datasource_builder_1570_compile_test.dart  # NEW (review round): U2 — real scoped `dart analyze` over the repaired pair
```

**Structure Decision**: single-package change inside the mock plugin;
no new exports, no public API surface beyond the existing builder.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | — | — |
