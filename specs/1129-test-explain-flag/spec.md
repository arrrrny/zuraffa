# Feature Specification: Test Plugin A- → A+ Upgrade — `--explain` Flag

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `spec/1129-test-explain-flag`

**Created**: 2026-09-07

**Status**: Approved

**Input**: User description: "test: add --explain flag (A- to A+) — emit a human-readable block describing which test files were generated, which test kinds (unit/integration/widget) were produced, the self-certification result per file, and the trust tier of the generated artifacts"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Human-readable explanation of a test generation (Priority: P1)

A developer runs `zfa test create <Entity> --explain`. The generation behaves exactly as without the flag (same files, same self-certification gate, same receipts), and AFTER the regular output (the machine verdict line plus the created/overwritten/skipped file list) the CLI prints a human-readable explanation block describing: which test files were generated, which test kinds (unit/integration/widget) were produced, the self-certification result per file, and the trust tier of the generated artifacts. A developer auditing the generator's output should be able to read the block top to bottom and know exactly what was written, how it was verified, and how much to trust it — without re-deriving any of it from receipts.

**Why this priority**: the `--explain` block IS the upgrade. The test plugin already has `--json` (via `ExecutionResult.data['certification']`), the AST-based self-certifier, provenance headers, receipts and a `plan()` dry-run; the missing human twin of `--json` is the only gap between A- and A+.

**Independent Test**: run `zfa test create <Entity> --explain` in a workspace with a compiling usecase; assert stdout contains the explain separator and the four mandated sections. The same run without `--explain` must not contain the separator.

**Acceptance Scenarios**:

1. **Given** a workspace whose generated tests compile, **When** `zfa test create <Entity> --explain` runs, **Then** stdout contains the explain block starting with the `--- explain: test create ---` separator, followed by the sections `generated files:`, `test kinds:`, `self-certification:`, `trust tier:` and `summary:`.
   **Type**: acceptance
2. **Given** the same run, **When** the regular output is examined, **Then** the machine verdict line (`test: entity=<X> tests=<N> compile=pass`) and the created/overwritten file list still appear — the explain block is additive, printed alongside the regular output, never instead of it.
   **Type**: acceptance
3. **Given** a run without `--explain`, **When** stdout is examined, **Then** no `--- explain:` separator appears (the flag is opt-in; `--json`-alone behavior is byte-identical to the pre-1129 behavior).
   **Type**: acceptance

### User Story 2 - `--explain --json` produces both JSON and prose (Priority: P1)

A developer or AI agent runs `zfa test create <Entity> --explain --json`. The CLI prints the machine-readable self-certification envelope `{entity, tests, compile, errors[], schema:1}` (the spec 980 `--json` semantics, unchanged) and then the human-readable explain block as prose. The two audiences are served by one invocation: machines parse the envelope line, humans read the block below it.

**Why this priority**: the combined mode is the acceptance criterion that proves `--explain` is the human twin of `--json` (the issue #1125 convention) rather than a replacement for it.

**Independent Test**: run `zfa test create <Entity> --explain --json`; assert stdout contains a parseable certification envelope AND the `--- explain: test create ---` separator, in that order.

**Acceptance Scenarios**:

1. **Given** a workspace whose generated tests compile, **When** `zfa test create <Entity> --explain --json` runs, **Then** stdout contains the JSON envelope `{entity, tests, compile, errors[], schema:1}` (parseable, keys unchanged) and afterwards the explain block prose.
   **Type**: acceptance
2. **Given** the same combined run, **When** the envelope is compared with the pre-1129 envelope, **Then** the existing keys and their semantics are identical — `--json` semantics are unchanged; the explain block adds stdout prose only, never envelope keys.
   **Type**: acceptance

### User Story 3 - Honest trust tiers for generated artifacts (Priority: P2)

A developer reads the `trust tier:` section of the explain block. Every written test file carries a tier derived from the self-certification evidence: `certified` (written and analyzed clean by the scoped `dart analyze`), `failed` (written but a compile error is attributed to it), or `unverified` (written but no certification evidence exists). Files that already existed and were skipped carry `pre-existing`. The block-level trust tier is the honest floor of the per-file tiers — a single failed file fails the block.

**Why this priority**: tiers make the certification verdict actionable per file instead of per run, but they are derived read-only from the existing self-certification result — the gate itself must not change.

**Independent Test**: generate with a passing injected analyzer (tier `certified` for every written file), then with a failing injected analyzer (tier `failed` for the offending file); assert the explain block names the right tier per file and the honest floor at block level.

**Acceptance Scenarios**:

1. **Given** a generation whose certification passes, **When** the explain block prints, **Then** every written file line carries `tier=certified` and the block-level trust tier is `certified`.
   **Type**: acceptance
2. **Given** a generation whose certification fails (a compile error attributed to one file), **When** the explain block prints, **Then** that file's line carries `tier=failed`, its `self-certification:` line names the first error, and the block-level trust tier is `failed`.
   **Type**: acceptance
3. **Given** a generation where a test file already exists and is skipped (no `--force`), **When** the explain block prints, **Then** the skipped file's line carries `tier=pre-existing` and it does not lower the block-level tier of the files this run wrote.
   **Type**: acceptance

## Edge Cases

- **Nothing generated (all skipped or empty generation)**: the explain block still prints (honesty on every exit path, the #1125 convention), listing the skipped/pre-existing files with their tiers; the #769 zero-files guard keeps its exit semantics.
- **Dry run (`--dry-run`)**: certifies nothing (spec 980 behavior unchanged); if explain is requested the block prints with `unverified` tiers and a summary naming the dry run.
- **Analyzer could not run**: the certifier already refuses to claim pass (spec 980); the explain block shows the file as `failed` with the synthesized diagnostic, never silently `certified`.
- **Explain requested with no `--name`**: usage refusal (exit 64 family) — no explain block, the grammar error path is unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa test create <Entity> --explain` MUST emit the human-readable explain block on stdout, after the regular output, starting with the separator line `--- explain: test create ---`.
- **FR-002**: the block MUST contain the sections `generated files:` (one line per file: project-relative POSIX path, action, kind, tier), `test kinds:` (unit/integration/widget counts), `self-certification:` (per-file result plus the machine verdict line), `trust tier:` (block-level tier plus a one-line legend) and `summary:` (a one-paragraph narrative).
- **FR-003**: `zfa test create <Entity> --explain --json` MUST print the certification envelope `{entity, tests, compile, errors[], schema:1}` first, then the explain block prose.
- **FR-004**: the `--json` semantics MUST NOT change: the envelope's keys, ordering and meaning are exactly the spec 980 contract, and `--json` without `--explain` produces the same stdout as before 1129 (no explain prose).
- **FR-005**: the self-certification gate MUST NOT change: certification still runs on every real (non-dry-run, non-revert) generation that writes test files, non-compiling output still fails the command with exit 1, and `ExecutionResult.data['certification']` keeps its shape.
- **FR-006**: per-file trust tiers MUST be derived read-only from the run's certification evidence (an error attributed to a file by file path): `certified` when the file has no attributed error, `failed` when it has one, `unverified` when no certification evidence exists, `pre-existing` for skipped files.
- **FR-007**: test kinds MUST be reported honestly for the unit/integration/widget lanes; the test plugin emits unit tests only, so the counts name the produced kind(s) and 0 for the lanes it did not produce in this run.
- **FR-008**: the capability inputSchema MUST declare the `explain` boolean so the manifest treaty (`zfa manifest --verify`) can certify the flag surface, and the bespoke `zfa test create` grammar MUST accept every schema-advertised flag (the #902/#904 drift classes).

### Key Entities

- **TestExplain**: the human-readable block (a pure function of the generation result: files, actions, certification, receipt path). No I/O, no drift from what generation actually did.
- **Trust tier**: `certified` / `failed` / `unverified` / `pre-existing` per file; the block-level tier is the floor over the files this run wrote (`failed` > `unverified` > `certified`; `pre-existing` never lowers the floor).
- **Test kinds**: `unit` / `integration` / `widget` lanes, counted per file actually produced by this run.

## Success Criteria *(measurable)*

- **SC-1**: `zfa test create <Entity> --explain` prints the separator plus all five mandated sections (measured by the unit suite asserting each section marker on captured stdout).
- **SC-2**: `--explain --json` prints a parseable certification envelope followed by the explain prose (measured by decoding the envelope line and asserting the separator appears after it).
- **SC-3**: without `--explain`, stdout contains no `--- explain:` separator (measured by the same suite).
- **SC-4**: with a failing injected analyzer, the explain block names the offending file `tier=failed`, quotes the first error, and sets the block-level tier to `failed` (measured by the unit suite).
- **SC-5**: `zfa manifest --verify` reports zero drift findings for the test plugin after the schema gains `explain` (measured by the manifest gate).
- **SC-6**: the targeted test-plugin suite passes; `dart analyze` on the changed files reports no errors; `dart format .` leaves zero formatting diffs.
