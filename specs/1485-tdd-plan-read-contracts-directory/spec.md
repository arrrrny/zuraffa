# Feature Specification: zfa tdd plan reads contracts/*.md as a declared-row source — declare once, resolve everywhere

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1485-read-contracts-directory`

**Created**: 2026-09-11

**Status**: Draft

**Input**: User description: "Issue #1485 — zfa tdd plan ignores the specs/<feature>/contracts/*.md artifacts that the spec-kit planning phase writes; declared contract rows are sourced only from spec.md sections, so the structured contract documents already produced are invisible and the author must restate the same contract a second time in a different grammar, with the two copies free to drift"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The planning phase's contract documents feed the routing resolver (Priority: P1)

A developer authors a feature with the spec-kit planning phase. The phase
writes `specs/<feature>/contracts/*.md` — structured contract documents
carrying operation/method tables (`| Operation | Input | Behaviour |`) and
method signature lists. Today `zfa tdd plan` ignores that directory
entirely: declared rows are sourced only from the spec's `## Layer
Contracts`, `## Key Entities`, and `## External Dependencies & Contracts`
sections, so every behavior the contracts describe falls back to the
legacy prose classifier (42 behaviours fallback-route in the issue's
repro), and the author must retype the same contract into `spec.md` in a
different grammar. Plan must enumerate the contract documents, extract
their declared rows, and feed them to the routing resolver alongside the
spec.md rows — the author declares the contract once, in the artifact the
planning workflow already produced.

**Why this priority**: This is the defect. Without it the structured
contract documents are dead weight and every traced behavior
fallback-routes.

**Independent Test**: A feature whose `contracts/` directory carries a
task-store operations table plans with the contract-file rows declared:
plan reports what it read, and a behavior traced to
`task-store.Create` resolves the contract-file row instead of
fallback-routing.

**Acceptance Scenarios**:

1. **Given** a feature with `specs/<feature>/contracts/` holding
   `task-store.md` (an operations table) and `data-layer.md` (a method
   signature list), **When** `zfa tdd plan <feature>` runs, **Then** plan
   reports what it read — `declared rows: 4 from contracts/task-store.md`,
   `declared rows: 3 from contracts/data-layer.md` — and the extracted
   rows are available to the routing resolver
   **Type**: acceptance
2. **Given** the same feature, an FR whose block carries
   `traces: task-store.Create`, **When** the plan resolves the behavior's
   routing, **Then** the trace token resolves against the contract-file
   row — the behavior routes declared (unit lane), not fallback
   **Type**: acceptance
3. **Given** a feature with no `contracts/` directory at all, **When**
   `zfa tdd plan` runs, **Then** the plan output and artifacts are
   byte-identical to today's behaviour — no new lines, no new warnings
   **Type**: acceptance

---

### User Story 2 - Silence about ignored directories is the defect; plan must name what it read and what it could not (Priority: P2)

A developer whose `contracts/` directory exists but holds no parseable
declared rows (an empty directory, or documents with no operation/method
tables and no signature lists) must be told — silence about ignored
directories is what makes this expensive to diagnose. Equally, plan must
report every file it DID read and how many rows it extracted, so the
author can see the declared-row source working.

**Why this priority**: Diagnosability. A silent empty contracts/ directory
re-creates the exact waste this issue names (the author assumes the rows
were read).

**Independent Test**: A feature whose `contracts/` directory exists but
holds only prose documents plans with a warning naming the directory and
the fix; a feature whose contracts/ holds parseable documents plans with
per-file declared-row counts.

**Acceptance Scenarios**:

1. **Given** a feature whose `contracts/` directory exists but is empty or
   yields zero parseable rows, **When** `zfa tdd plan` runs, **Then** plan
   emits a warning naming the directory and the expected grammar
   **Type**: acceptance
2. **Given** a feature whose contracts/ yields rows from two files, **When**
   plan runs, **Then** one report line per read file names the file
   relative path (`contracts/<name>.md`) and the extracted row count
   **Type**: acceptance

---

### User Story 3 - The supplement never replaces the spec's own grammar (Priority: P2)

Contract-file rows are a supplement, not a replacement: every spec.md
declared-row source (Layer Contracts, Key Entities, External Dependencies)
continues to work unchanged, and both sources feed the SAME routing
resolver. When a row name collides between spec.md and a contract file,
the contract-file version wins — it is more structured and was produced by
the planning workflow. The gen-time signature resolution
(`DeclaredRouting.declaredSignatureFor`, consumed by make/func) resolves
against the same merged source, so a trace that binds at plan time also
resolves its declared signature at generation time — declare once, resolve
everywhere.

**Why this priority**: Backwards compatibility is the hard constraint. A
merge that demoted spec.md rows or split the resolver's sources would
break every existing feature.

**Independent Test**: A spec declaring a Layer Contracts row AND a contract
file declaring a row with the same name plans with the contract-file
version winning; a spec.md-only feature plans exactly as before; the
declared-signature resolution at gen time resolves a contract-file trace.

**Acceptance Scenarios**:

1. **Given** spec.md declares row `TaskStore` (Layer Contracts) and
   `contracts/task-store.md` declares a row also named `TaskStore`,
   **When** plan builds the declared-row map, **Then** the contract-file
   version wins and a trace to `TaskStore` binds to the contract-file row
   **Type**: unit
2. **Given** a spec with `## Layer Contracts`, `## Key Entities`, and
   `## External Dependencies & Contracts` rows and a populated contracts/
   directory, **When** plan runs, **Then** rows from BOTH sources resolve
   (spec.md rows unchanged, contract rows added) **Type**: unit
3. **Given** a behavior whose test-list traces cell names
   `task-store.getAll` (a contract-file row carrying the signature
   `` `getAll() -> List<Task>` ``), **When** make/gen resolves the
   declared signature via `DeclaredRouting.declaredSignatureFor`, **Then**
   the contract-file row's signature is returned **Type**: unit

---

### Edge Cases

- What happens when two contract files declare rows with the same name?
  Files are enumerated in sorted order and later files overwrite earlier
  ones (deterministic last-wins, mirroring the collision policy).
  **Type**: unit
- What happens when a contract file is unreadable (permissions)? The file
  contributes no rows and plan's zero-rows warning path names the
  directory; the plan never crashes. **Type**: unit
- What happens to fenced code blocks inside a contract file? They are
  documentation, not declarations — blanked before parsing (the same
  stance spec.md parsing applies), so a `| Operation |` example inside a
  ``` fence declares nothing. **Type**: unit
- What happens when a signature column cell carries prose instead of a
  `name(Params) -> Return` shape? Plain prose is dropped (not carried as a
  malformed signature); a cell shaped like a signature but failing to
  parse (`(x) -> y` without a name) is carried raw so the resolver's
  malformed-declaration refusal names it when consulted. **Type**: unit
- What about markdown inside contracts/ that is NOT .md (e.g. .dart
  sources)? Only `*.md` files are read; code inside contracts/ is never
  parsed. **Type**: unit

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa tdd plan` MUST enumerate every `*.md` file inside
  `specs/<feature>/contracts/` (sorted by file name) when the directory
  exists, and extract declared rows from operation/method tables and
  method signature lists in each file
- **FR-002**: Each extracted contract-file row MUST become a declared row
  available to the routing resolver — a `traces:` token naming the row
  (bare, or `<contract-file-stem>.<row>` for the file-qualified form)
  resolves against contract-file rows exactly as it does against spec.md
  sections
- **FR-003**: Plan MUST report what it read — one line per read file in
  the form `declared rows: <n> from contracts/<file>.md` — and MUST NOT
  stay silent about a `contracts/` directory that exists but yields no
  parseable rows (a warning naming the directory and the expected grammar
  is emitted instead)
- **FR-004**: Contract-file rows MUST be a supplement, not a replacement —
  rows from the spec's `## Layer Contracts`, `## Key Entities`, and
  `## External Dependencies & Contracts` sections continue to work
  unchanged, and both sources feed the same routing resolver
- **FR-005**: When a row name collides between spec.md and a contract
  file, the contract-file version MUST win (it is more structured and was
  produced by the planning workflow)
- **FR-006**: The gen-time declared-signature resolution
  (`DeclaredRouting.declaredSignatureFor`, the make/func path) MUST
  resolve against the same merged source, so a contract-file trace bound
  at plan time resolves its declared signature at generation time
- **FR-007**: A feature with no `contracts/` directory MUST plan
  byte-identically to today — no new output, no new warnings, no
  behavioural change
- **FR-008**: The reader MUST handle varied markdown shapes — pipe tables
  whose header row's first cell is `Operation` or `Method` (with an
  optional `Signature` column), tables whose first cell is `Signature`,
  interface bullets (`` - `Name`: `sig`, `sig` ``), and pure signature
  bullets (`` - `name(Params) -> Return` ``); `## Operations` / `## Methods`
  headings scope the signature-list bullets; fenced code blocks are
  documentation and declare nothing; only markdown is parsed — never code
  files inside contracts/
- **FR-009**: The routing resolver's API MUST be unchanged — it already
  accepts declared rows; this feature only adds a new source feeding it

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A feature with `contracts/task-store.md` (operations table,
  4 rows) and `contracts/data-layer.md` (signature list, 3 rows) plans
  with the exact report lines `declared rows: 4 from
  contracts/task-store.md` and `declared rows: 3 from
  contracts/data-layer.md`
- **SC-002**: A behavior whose FR block traces `traces:
  task-store.<Row>` routes declared (unit lane, function-row signature
  resolution) — not fallback — and the same trace resolves its declared
  signature through `DeclaredRouting.declaredSignatureFor` at gen time
- **SC-003**: A feature with an empty contracts/ directory plans with a
  warning naming the directory; a feature with no contracts/ directory
  plans with output byte-identical to the pre-change behaviour
- **SC-004**: A spec.md row name collided with a contract-file row name
  resolves to the contract-file row (criterion FR-005 proved)
- **SC-005**: The existing TDD plugin suites (spec parser declarations,
  routing resolver, plan command suites) stay green — the supplement
  regresses nothing

## Assumptions

- Contract-file rows carry the `function` contract-row kind: an operations
  contract declares callable operations, the unit lane + plain-function
  surface is the safest default, and the issue's repro (data-layer store
  operations) routes declared unit. A row the author wants in another lane
  keeps the spec.md escape hatches (`**Type**` markers, spec.md rows — the
  supplement never removes them)
- The `<contract-file-stem>` in the file-qualified trace form is the
  contract file's basename without the `.md` extension
  (`contracts/task-store.md` → `task-store`)
- `corpus_catalog.dart`'s recognition of `contracts` as a spec-kit
  subdirectory name (the issue's line-183 citation) needs no change — the
  catalog's CORE/SKIN classification reads spec.md content signals and is
  out of scope; the fix is the declared-row source in the spec parser plus
  its wiring in the plan/make/gen declaration builders
- The coverage gate, traceability matrix, lane split, and every run/
  verify/loop semantic are untouched — this feature only widens what the
  declared-row map contains before the (unchanged) resolver runs
