**Template Version**: `zuraffa-1.0`

# Spec: 1418-mock-force-regen-interface

**Feature Branch**: `feat/1418-mock-force-regen-interface`
**Created**: 2026-09-15
**Status**: Draft
**Input**: Issue #1418 — `zfa mock create Deal --methods getList --certify --force` regenerates the mock datasource from the current `--methods` but leaves the STALE `<entity>_datasource.dart` interface (create-if-absent write path): the pair drifts, `dart analyze` reports `Missing concrete implementation of 'DealDataSource.list'`, and certification dead-ends no matter how many times `--force` re-runs. Secondary: the mock lane emits `hide` names verified against `zuraffa.dart` while importing `package:zuraffa/mock.dart` — the actually-imported library's export surface is never checked.

## User Scenarios & Testing

### User Story 1 — `--force` regenerates the whole generated pair (Priority: P1)

A developer generated a mock earlier (`zfa mock create Deal --methods list`). They now change the method set: `zfa mock create Deal --methods getList --certify --force`. The datasource interface (`deal_datasource.dart`) is regenerated from the CURRENT `--methods` together with the mock, so the emitted `DealDataSource` declares `getList(ListQueryParams<Deal>)`, the mock implements it, and the certification proves a conforming pair. Re-running `--force` never dead-ends on a stale interface.

**Why this priority**: this is the reported break — the mismatched pair cannot compile and `--certify` fails permanently, defeating the flag whose documented promise is "Overwrite existing files".

**Independent Test**: seed a tree with an interface declaring `list(NoParams)` and a mock implementing only `list`; run `MockBuilder.generate` with `force: true, methods: [getList]`; assert the interface declares `getList` (and not `list`), the mock implements `getList`, and a scoped member-set comparison of the pair is empty of missing members.

**Acceptance Scenarios**:

1. **Given** a tree whose `<entity>_datasource.dart` declares `list(NoParams)`, **When** the mock lane runs with `force: true` and `--methods: [getList]`, **Then** the interface file is rewritten from the current methods (declares `getList(ListQueryParams<Entity>)`, no longer declares `list(NoParams)`) and the ledger action is `overwritten` (not `skipped`).
   **Type**: acceptance
2. **Given** the same force run, **When** the pair is compared member-set against member-set (the certification's structural check), **Then** the missing-member set is empty — the certification's structural gate passes on the regenerated pair.
   **Type**: acceptance
3. **Given** a tree with NO existing interface file, **When** the mock lane runs with `force: true`, **Then** the interface is still emitted exactly once (the #417 guarantee holds — the mock's import target always exists after the run).
   **Type**: acceptance

### User Story 2 — Non-force mock creation is unchanged (Priority: P1)

Every working non-force contract survives byte-for-byte: an existing interface is left untouched on a non-force run (create-if-absent preserved for the interface writer), the #1570 mock drift-repair keeps its precedence (revert / append-existing / force), and an absent interface is still emitted. No existing behavior changes for teams that never pass `--force`.

**Why this priority**: the #1570 fix explicitly left the interface writer untouched as a hard constraint; this feature must not silently widen that contract either.

**Independent Test**: seed the same drifted tree, run with `force: false`; assert the interface file's bytes are identical after the run and the mock-side ledger actions match the #1570 suite's expectations.

**Acceptance Scenarios**:

1. **Given** an existing interface file, **When** the mock lane runs WITHOUT `--force`, **Then** the interface file is byte-identical after the run (the interface writer is not invoked on the append path from the mock lane).
   **Type**: acceptance
2. **Given** no interface file, **When** the mock lane runs WITHOUT `--force`, **Then** the interface is emitted (`created`) exactly as before the change.
   **Type**: acceptance

### User Story 3 — Mock-barrel hide emission verifies the library it imports (Priority: P2)

The mock lane's generated files import `package:zuraffa/mock.dart` with a `hide` combinator (#942 collision protection). Today the hide names are verified against the `zuraffa.dart` surface only; the import's OWN library (`lib/mock.dart` → `src/mock/mock.dart`) is never walked. The emission verifies against the imported library's real export surface: a name the mock barrel does not export is never hidden from it, and a name verified on the zuraffa surface stays hidden while the bare re-export carries it. An unresolved surface still emits no combinator at all (#1530 FR-001 carries over).

**Why this priority**: the residual is latent (today `src/mock/mock.dart` bare-re-exports the full zuraffa surface), but it is the exact `undefined_hidden_name` family the issue names — fixing the verification target closes the class instead of the instance.

**Independent Test**: seed `ZuraffaBarrelExports` with a zuraffa surface containing a name the mock-barrel walk does not see (diverged mock barrel, no bare re-export); assert the mock-barrel filter drops it while the zuraffa-barrel filter keeps it; with the bare re-export present, assert the union keeps it.

**Acceptance Scenarios**:

1. **Given** a resolved zuraffa surface `{Alpha, Credentials}` and a mock barrel whose export chain does NOT carry a bare `package:zuraffa/zuraffa.dart` re-export, **When** the mock-barrel filter runs on `[Alpha, AlphaPatch]`, **Then** only names collected from the mock barrel's own chain survive.
   **Type**: unit
2. **Given** the mock barrel DOES bare-re-export `package:zuraffa/zuraffa.dart`, **When** the mock-barrel filter runs on the same input, **Then** the zuraffa-verified names survive (the #942 protection does not regress on the mock lane).
   **Type**: unit
3. **Given** an unresolved surface (no seed / no resolvable barrel), **When** either filter runs, **Then** the result is empty — the import is emitted with no `hide` combinator at all.
   **Type**: unit

### Edge Cases

- `--force` together with `--dry-run`: no file bytes change; the ledger reflects the would-be regeneration.
- `--force` together with `--revert`: the revert path keeps its current contract (the regeneration guard does not fire over revert).
- `--force` on an in-sync pair: both files regenerate from the same config; a second run is byte-stable (idempotent output).
- `config.repo` set (repository-mode entity resolution): the regenerated interface targets the SAME path the create-if-absent guard computed (`repo`-derived entity name), so no second interface file appears.
- Custom-usecase mocks (`isCustomUseCase`): the interface regeneration follows the same `DataSourceInterfaceBuilder` path; no new emission shape is invented.

## Requirements

### Functional Requirements

- **FR-001**: When `config.force` is true and the `<entity>_datasource.dart` interface file EXISTS, the mock lane MUST invoke the interface writer so the file is regenerated fresh from the current `config.methods` (ledger action `overwritten`).
            traces: MockBuilder
- **FR-002**: When `config.force` is false, the mock lane MUST keep the create-if-absent contract for the interface (existing file untouched, absent file still emitted) — the #417 guarantee and the #1570 hard constraint stay intact.
            traces: MockBuilder
- **FR-003**: A force-regenerated pair MUST satisfy the certification's structural member-set check (interface members ⊆ mock members) with the changed `--methods` — proven without modifying any certification file.
            traces: MockBuilder, MockCertification (read-only)
- **FR-004**: The mock lane's `package:zuraffa/mock.dart` hide list MUST be verified against the mock barrel's actual export surface (walked from `lib/mock.dart`); an unresolved surface yields NO combinator.
            traces: MockDataSourceBuilder, FailingMockProviderBuilder, ZuraffaBarrelExports
- **FR-005**: The zuraffa-barrel verification (interface writer and every other emission site) MUST stay on the `zuraffa.dart` surface, unchanged; the #942 protection survives on both lanes under the bare-re-export union.
            traces: ZuraffaBarrelExports, DataSourceInterfaceBuilder (read-only)
- **FR-006**: The force regeneration MUST honor `dryRun` — would-be actions visible, zero byte changes.
            traces: MockBuilder
- **FR-007**: Revert and append-existing precedence MUST stay exactly as pinned by the #1570 suite (U4).
            traces: MockBuilder
- **FR-008**: The certification logic (`MockCertification`, `MockCertifier`, gate analyze flags) and the entity pipeline MUST NOT change — the fix is scoped to the mock lane's interface-regeneration guard and the hide-emission verification target (one PR per feature).
            traces: —

## Layer Contracts

**Domain**:
- `MockBuilder`: `generate(GeneratorConfig) -> Future<List<GeneratedFile>>` — the interface-regeneration guard moves from `!exists` to `!exists || (force && !revert)`.
- `ZuraffaBarrelExports`: adds a mock-barrel surface walk + `filterMock(Iterable<String>) -> List<String>`; `filter` keeps its exact current contract.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| GeneratorConfig | `force`, `revert`, `methods`, `repo`, `appendToExisting` | The run's contract flags; `force && !revert` arms the interface regeneration, `methods` is the fresh interface's member source |
| GeneratedFile | `path`, `type`, `action` | Ledger entry; the force-regenerated interface reports `overwritten` where the old code reported nothing (file skipped pre-builder) |
| ZuraffaBarrelExports | `names` (zuraffa surface), mock surface (union) | The verified name sets behind `filter` / `filterMock` |

## Success Criteria

### Measurable Outcomes

- **SC-001**: `mock create Deal --methods list` followed by `mock create Deal --methods getList --certify --force` leaves a conforming pair: the interface declares `getList(ListQueryParams<Deal>)`, the mock implements it, a scoped `dart analyze` over the pair reports zero errors, and the certification gate passes (exit 0).
- **SC-002**: The non-force run leaves an existing interface byte-identical and keeps the #1570 mock-lane ledger actions (`skipped` in-sync / `updated` drift-repaired).
- **SC-003**: The force run on an in-sync pair is idempotent: two consecutive force runs produce byte-stable output for both files.
- **SC-004**: The mock-barrel hide emission contains only mock-barrel-verified names (diverged-surface names dropped, bare-re-export union kept, unresolved → no combinator), and the zuraffa-barrel `filter` behavior is unchanged.
- **SC-005**: No regression outside the named scope: the #1570 suite (incl. U4 precedence), the #1530 hide suites, the #942 suite, capability/certify-gate suites, and `mock_builder_test.dart` all stay green.

## Assumptions

- `DataSourceInterfaceBuilder`'s fresh-write path (`exists && (appendToExisting || !force)` → else fresh write with `force: options.force`) is the correct regeneration primitive — the established pattern of the datasource and repository plugins — and is NOT modified by this feature.
- `MockPlugin.generate` re-delegates with `options.force` synced to `config.force`, so the interface builder's `options.force` equals the run's force flag by the time `MockBuilder` executes.
- The mock datasource body always regenerates from the current `--methods` (already true); the interface regeneration mirrors that source of truth, so the pair cannot drift under `--force`.
- The generated interface is a provenance-headed artifact; regeneration under `--force` follows the same ownership contract the mock body already has.
- Out of scope: certification logic and its emitted contract-test artifacts (the `deal_mock_contract_test.dart` `unused_import` residual is certification-owned — recorded, not fixed here), the entity pipeline, the build gate, and service-mode provider emission.
