**Template Version**: `zuraffa-1.0`

# Spec: 1570-make-methods-append-propagate-mock

**Feature Branch**: `feat/1570-make-methods-append-propagate-mock`
**Created**: 2026-09-14
**Status**: Draft
**Input**: Issue #1570 — `zfa make ScanSession --preset=crud --methods=get,getList` appends `getList` to the interface (`ScanSessionDataSource`) and the real datasource, but the certified mock datasource keeps its earlier member set. Interface and implementer drift apart → `non_abstract_class_inherits_abstract_member` → `zfa build` gate fails.

## User Scenarios & Testing

### User Story 1 — Appended methods reach the certified mock (Priority: P1)

A developer generated a slice earlier (entity + interface + certified mock with `get`). They now widen the method set: `zfa make ScanSession --preset=crud --methods=get,getList --mock`. The interface and the real datasource gain `getList`; the certified mock datasource (`scan_session_mock_datasource.dart`, created earlier by `mock create` or an earlier make with a smaller `--methods=` set) MUST gain the same member. After the run the tree compiles: no `non_abstract_class_inherits_abstract_member` for the mock, and `zfa build`'s analyze gate passes without a manual `--force`.

**Why this priority**: this is the reported break — a half-applied append leaves the generated tree non-compiling and dead-ends the pipeline (build gate red on the tool's own output).

**Independent Test**: seed a project whose mock implements a strict subset of its interface's members, run the make append invocation, assert the mock file implements every interface member and `dart analyze` over the mock + interface is clean.

**Acceptance Scenarios**:

1. **Given** a project where `scan_session_mock_datasource.dart` implements only `get` while `ScanSessionDataSource` declares `get, getList`, **When** the mock lane runs (`make --methods=` with the mock plugin active, or `zfa mock create`) in a non-append, non-force, non-revert run, **Then** the mock is repaired to implement `getList` and the emitted ledger action is `updated` (not `skipped`).
   **Type**: acceptance
2. **Given** the same drifted state, **When** the make run completes, **Then** a scoped analyze over the interface + mock pair reports zero errors (`non_abstract_class_inherits_abstract_member` gone) before the make post-pass/build gate runs.
   **Type**: acceptance

### User Story 2 — Staleness is a shape check, not an existence check (Priority: P1)

The mock lane's skip decision stops being "file exists → skip". The lane compares the mock's implemented member set against the interface's declared member set (the same structural comparison the mock certification and the tdd lane's stale-mirror comparison use: AST member sets, no package resolution). A mock whose member set covers the interface stays skipped (idempotent regeneration promise: extend, never clobber); a mock missing interface members is stale and gets repaired.

**Why this priority**: the shape check is the root-cause remediation — without it, any future writer-ordering or config drift re-introduces the same failure class (#1530 sibling).

**Independent Test**: call the staleness detector on (a) an in-sync mock pair → not stale; (b) a mock missing one interface member → stale, naming exactly that member; (c) a project without the interface file → not stale (fail-open to the old skip).

**Acceptance Scenarios**:

1. **Given** an in-sync mock (implements exactly the interface surface, extra helper members allowed), **When** the mock lane runs without `--force`, **Then** the file is left untouched and the ledger action is `skipped`.
   **Type**: acceptance
2. **Given** a mock missing members the interface declares, **When** the staleness detection runs, **Then** it returns the missing member names exactly (no invented members, no false positives on helper/getter members the interface does not declare).
   **Type**: unit

### User Story 3 — Repair happens before the analyze gate, honestly (Priority: P2)

The repair is part of the generation run itself — the mock is healed before make's own analyze post-pass and before `zfa build`'s gate — and the run says so: a notice line names the entity, the missing member(s), and the repaired file; the files ledger records `updated`. A `--dry-run` run reports the would-be repair without writing.

**Why this priority**: honesty and gate-ordering are secondary to propagation but required by the issue's remediation (3) — the user must never see a compile error from the tool's own half-applied append.

**Independent Test**: run the append invocation against a drifted tree with `--verbose`/ledger assertions: the notice is printed, the ledger action is `updated`, and with `--dry-run` no bytes change on disk.

**Acceptance Scenarios**:

1. **Given** a drifted mock and a make run, **When** the lane repairs it, **Then** the summary ledger shows the mock file as updated and the repair notice names the missing member(s).
   **Type**: acceptance
2. **Given** `--dry-run`, **When** the lane detects staleness, **Then** the repair is reported but the mock file bytes are unchanged.
   **Type**: acceptance

### Edge Cases

- What happens when the interface file does not exist (or the class is missing from it)? The shape check fails OPEN: no staleness, keep the existing skip behavior — never fabricate members from nothing.
- What happens when the interface file itself does not parse? Same fail-open: skip as before; the analyze gate will name the real problem.
- What happens when the mock has EXTRA members the interface does not declare (custom-usecase helpers, `_delay`-adjacent helpers)? They are not "repaired away" — only MISSING members are appended; invented-surface reporting stays the certification gate's job.
- What about `--force`? Unchanged: full regeneration wins over repair (force already bypasses the skip).
- What about `--append` / `appendToExisting` runs and `--revert`? Unchanged paths: append keeps its idempotent member addition; revert keeps its undo/delete semantics. The shape check only arms where the old code had the existence-based skip.

## Requirements

### Functional Requirements

- **FR-001**: When the mock datasource file exists and the mock lane's write would be skipped (no `appendToExisting`, no `force`), the lane MUST compare the mock class's implemented member set against the interface's declared member set (AST shape check) instead of skipping on existence alone.
            traces: MockDataSourceBuilder
- **FR-002**: When the shape check finds interface members the mock does not implement, the lane MUST repair the mock by appending implementations for exactly the missing members (idempotent member addition via the existing append executor path) — the regenerated mock compiles against its interface.
            traces: MockDataSourceBuilder
- **FR-003**: The shape check MUST use the same structural primitives as the mock certification's conformance check (interface members via `MethodExtractor.extractMethodsFromInterface`, implemented members via `AstHelper` over the mock class) — matching the tdd lane's stale-mirror comparison semantics (member-set equality, not text hashing).
            traces: MockCertification
- **FR-004**: When the interface file/class is missing or unparseable, the shape check MUST fail open (no staleness detected, skip preserved) — a silent no-op is preferable to fabricating members.
            traces: MockDataSourceBuilder
- **FR-005**: When the mock implements the full interface surface, the lane MUST keep the pre-existing skip (action `skipped`) — the fix must not turn every idempotent re-run into a rewrite.
            traces: MockDataSourceBuilder
- **FR-006**: The repair MUST be reported: a stdout notice naming the entity, the missing member(s), and the repaired file, and the files ledger action `updated` for the repaired mock (so receipts/certification observe the true action).
            traces: MockDataSourceBuilder
- **FR-007**: The repair MUST honor `dryRun` — the would-be repair is visible in the ledger but no file bytes change.
            traces: MockDataSourceBuilder
- **FR-008**: The interface writer, the real datasource writer, the repository writers, and the analyze/build gates MUST NOT change — the fix is scoped to the mock lane's skip/append decision (one PR per feature).
            traces: MockDataSourceBuilder

## Layer Contracts

**Domain**:
- `MockDataSourceBuilder`: `generateMockDataSource(GeneratorConfig) -> Future<GeneratedFile>`
- `MockStalenessDetector` (new, mock-lane internal): `detectMockStaleness(config, fileSystem) -> Future<List<ParsedUseCaseInfo>>`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| ParsedUseCaseInfo | `fieldName: String`, `paramsType: String`, `returnsType: String`, `useCaseType: String` | One interface member's extracted shape — the unit of drift the repair appends |
| GeneratedFile | `path: String`, `type: String`, `action: String` | Ledger entry; the repair emits `updated` where the old code emitted `skipped` |

## Success Criteria

### Measurable Outcomes

- **SC-001**: `zfa make ScanSession --preset=crud --methods=get,getList --mock` on a tree whose certified mock implements only `get` leaves the tree compiling — a scoped `dart analyze` over the interface + mock pair reports zero errors.
- **SC-002**: The repaired mock implements every interface member (member-set inclusion holds post-run) — the mock certification's `missingMethods` set is empty after the run.
- **SC-003**: An in-sync mock re-run stays byte-identical (`skipped`), preserving the idempotent-regeneration contract.
- **SC-004**: The repair is observable (notice + ledger `updated`) and dry-run-safe.
- **SC-005**: No behavior change outside the mock lane: interface/real-datasource/repository writers and the analyze gate keep their current contracts (regression suites green).

## Assumptions

- The mock datasource is a generated artifact (Generated-provenance header) — repairing it in place does not clobber hand-written code; teams with hand-edits already own the `--force`/regeneration risk the skip never protected them from (it silently let the tree stop compiling).
- Stream-typed and void-typed interface members get the same mock body shapes the builder already emits for those types (Stream.fromFuture / Future.value) — no new body semantics are invented by this fix.
- The dogfood's exact `.zfa.json` state (older project, before the `method_append` plugin default shipped) is the target environment; the fix must hold for every combination of `--append`/`--force`/`--dry-run`/config-defaults, not just one.
- Out of scope: `FailingMockProviderBuilder` (the `--fail` twin), service-mode `MockProviderBuilder` (separate surface, separate drift ledger), and any build-gate changes (#1530 sibling, already merged).
