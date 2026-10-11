# Feature Specification: Standalone Zero-Artifact Honesty — `test create` / `api` Verbs

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `verify/epic1-honesty-sweep`

**Created**: 2026-09-09

**Status**: Approved

**Input**: Verify misfires #1385 + #1386 (EPIC #1132 Phase A/B): standalone `zfa test create <Entity>` with a missing UseCase source exits 0 with zero files and a misattributed skip message; standalone `zfa api <Entity>` with no UseCases found exits 0 with zero files. Both are zero-artifact runs reported as success — the exact "exit 0 on error" class EPIC 1 exists to end.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - `test create` with a missing dependency fails honestly (Priority: P1)

A developer runs `zfa test create <Entity>` in a project where the UseCase source file (or a native-mock / repository source the test builder needs) does not exist. The builder skips every requested test and writes nothing. The CLI reports the run as a FAILURE: a `❌` verdict line naming the run's true cause ("nothing generated — dependency missing"), a machine-actionable `--> fix:` line pointing at creating the missing sources (e.g. `zfa usecase create ...`), and process exit code 1. A fleet automation script can rely on the exit code; a human is told exactly what to do next.

**Why this priority**: this is the misfire. A silent exit-0 on "did nothing" is the honesty bug; the fix message misattribution (`Skipped (use --force to overwrite)` shown for a missing dependency, which `--force` cannot fix) is the lie on top of it.

**Independent Test**: fresh pure-Dart package, no entity sources; run `zfa test create Product`; assert exit code != 0 and stdout contains a `--> fix:` line naming the missing dependency. The historical benign case (overwrite conflict without `--force`) must still exit 0.

**Acceptance Scenarios**:

1. **Given** a package with no `product_usecase.dart` discoverable, **When** `zfa test create Product` runs, **Then** the process exits non-zero and stdout contains `❌` and a `--> fix:` line referencing creating the UseCase source.
   **Type**: acceptance
2. **Given** the same run, **When** stdout is examined, **Then** no `✅ Success!` verdict appears (a zero-artifact run must not present as success).
   **Type**: acceptance
3. **Given** a package where the test target file already exists (overwrite conflict, no `--force`), **When** `zfa test create Product` runs and every skip is an overwrite conflict, **Then** the run keeps the historical benign semantics (exit 0, skip listing with the `--force` hint).
   **Type**: acceptance
4. **Given** `--dry-run`, **When** `zfa test create Product --dry-run` runs, **Then** the run exits 0 (preview is an explicit user intent; the gate never fires on dry runs).
   **Type**: acceptance

### User Story 2 - `api` with no UseCases fails honestly (Priority: P1)

A developer runs `zfa api <Entity>` in a project where the entity has no UseCases under `lib/src/domain/usecases/<entity>/`. The bridge builder discovers zero UseCases and writes nothing. The capability reports `success: false` with an honest message, so `ApiCommand`'s existing failure branch (bug #1139 pattern) prints `❌ Failed to generate API bridge: ...` and exits 1. The failure message carries the remediation (create UseCases first).

**Why this priority**: same misfire family, one-line-class fix at the capability verdict layer — `ApiCommand` already honors `success: false` with exit 1.

**Independent Test**: fresh pure-Dart package; run `zfa api Product`; assert exit code != 0 and stdout contains the failed-bridge line. The dry-run form stays exit 0.

**Acceptance Scenarios**:

1. **Given** a package with no UseCases for the entity, **When** `zfa api Product` runs, **Then** the process exits non-zero and stdout contains `❌ Failed to generate API bridge`.
   **Type**: acceptance
2. **Given** the same package, **When** `zfa api Product --dry-run` runs, **Then** the run exits 0 (preview keeps preview semantics).
   **Type**: acceptance

### User Story 3 - Skip causes are structured, not printed prose (Priority: P2)

The test builders (`test_builder_entity`, `test_builder_custom`, `test_builder_polymorphic`) emit `GeneratedFile` entries with `action: 'skipped'` and a machine-readable `skipReason` (`'missing-dependency'` for missing UseCase/mock/repository sources, `'overwrite-conflict'` for existing targets). The capability verdict is derived from these reasons: a run with zero artifacts whose skips are ALL missing-dependency skips fails; a run with zero artifacts whose skips are all overwrite conflicts keeps benign semantics; a mixed run with at least one artifact stays success. The receipt contract (issue #769: no artifact, no receipt) is unchanged — the wrapper still writes nothing for zero-artifact runs.

**Why this priority**: the verdict must key off structured causes, not output text, so MCP/`--json` consumers and future verbs inherit the same rule without re-parsing stdout.

**Independent Test**: invoke the test capability directly with injected builder results (mixed skip reasons) and assert the success flag follows the truth table above.

**Acceptance Scenarios**:

1. **Given** builder results with `skipReason: 'missing-dependency'` and zero artifacts, **When** the capability computes its verdict, **Then** `ExecutionResult.success` is false and the message names the missing dependency class.
   **Type**: acceptance
2. **Given** builder results with `skipReason: 'overwrite-conflict'` only and zero artifacts, **When** the verdict is computed, **Then** `success` stays true (benign, historical contract).
   **Type**: acceptance
3. **Given** a run with at least one created file plus any skips, **When** the verdict is computed, **Then** `success` follows the existing certification gate only (skips never fail a run that produced artifacts).
   **Type**: acceptance

## Requirements

### Functional Requirements

- **FR-1**: `GeneratedFile` gains an optional `skipReason` field (String?, serialized in `toJson()` when present). Existing constructors and consumers are source-compatible; `null` preserves today's behavior everywhere.
- **FR-2**: The three test builders set `skipReason: 'missing-dependency'` on dependency-missing skips (UseCase file, native-mock files, repository source) and `skipReason: 'overwrite-conflict'` on existing-target skips.
- **FR-3**: `CreateTestCapability.execute` fails (`success: false`, message naming the cause + fix) when the run is non-dry-run, produced zero artifacts, and has at least one `missing-dependency` skip. Dry runs never fail for this reason.
- **FR-4**: `CreateApiBridgeCapability.execute` fails (`success: false`, honest message + fix) when the run is non-dry-run and the builder produced zero files due to missing UseCases.
- **FR-5**: Exit codes: the existing plumbing carries the verdict — `CapabilityCommand` (and `ApiCommand` via #1139 pattern) set `exitCode = 1` on `success: false`. No new exit classes are introduced.
- **FR-6**: Receipt semantics unchanged: zero-artifact runs persist no receipt (issue #769). Failed runs persist no receipt. Successful runs keep the wrapper's proof.v1 path.
- **FR-7**: Overwrite-conflict-only zero-artifact runs keep exit 0 (pinned regression so the honesty gate cannot over-fire).

### Key Entities

- **GeneratedFile**: `{path, type, action, content, skipReason?}` — the skip cause rides on the file entry.
- **ExecutionResult**: unchanged shape; `success`/`message` carry the verdict.

## Success Criteria *(measurable)*

- **SC-1**: `zfa test create <Entity>` on a dependency-missing project exits non-zero with a `--> fix:` line (regression test pinned).
- **SC-2**: `zfa api <Entity>` on a no-UseCases project exits non-zero (regression test pinned).
- **SC-3**: Benign overwrite-conflict runs and `--dry-run` runs still exit 0 (regression tests pinned both verbs).
- **SC-4**: The full existing test/regression suite keeps passing (no over-firing of the honesty gate on legitimate zero-artifact flows).
