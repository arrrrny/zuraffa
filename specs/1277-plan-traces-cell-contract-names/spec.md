**Template Version**: `zuraffa-1.0`

# Spec: 1277-plan-traces-cell-contract-names

## Problem Statement

`zfa tdd plan` writes only the criterion id (`FR-001`) into the
test-list / lane-plan `traces` cell. But
`DeclaredRouting.declaredSignatureFor` (the #1259 remediation that lets
`gen` derive the subject signature and a real outcome assertion from a
declared Layer Contract) expects that cell to carry the traced contract
row names — its own doc comment says the cell is "a raw string
(`FR-001, Formatter.format`)". Since plan never emits the contract
names, the declared-signature path is unreachable through the standard
plan→gen pipeline: `gen` falls back to the legacy guard-only pair, and
`make`'s vacuous-green guard stops the run.

The repo's own committed example
(`specs/1004-skin-contract-adaptive-slots/tdd/04-ENGINE.md`) shows the
same loss: the spec declares contract rows, the provenance lines resolve
them, and the emitted cells carry the criterion id only — so the
declared path has likely never worked end-to-end via `zfa tdd plan`.

## Acceptance Scenarios

1. **Given** a spec whose FR carries a `traces:` continuation naming a
   declared contract row (`TodoRepository`) with a declared signature
   (`TodoRepository: create(String title) -> bool`), **When** the user
   runs `zfa tdd plan <f>` and then `zfa tdd gen U1`, **Then** the
   emitted subject derives the declared signature and the paired test
   asserts the declared outcome (e.g. `expect(result, isA<bool>())`) —
   NOT the legacy guard-only pair — and `zfa tdd run <f>` completes the
   make step without a vacuous-green stop.
2. **Given** the same spec, **When** the user inspects the emitted
   test list (legacy single-file plan), **Then** the unit behavior's
   traces cell contains the full trace set: the criterion id plus the
   method-qualified contract references (e.g. `FR-001,
   TodoRepository.create`) — the exact shape `TestListReader` /
   `RoutingResolver` already accept.
3. **Given** a spec declaring `## Lanes` (lane splitting active),
   **When** the user runs `zfa tdd plan <f>`, **Then** the
   `04-ENGINE.md` traces cells also carry the full trace set (criterion
   id + method-qualified contract references), matching the test-list
   shape.
4. **Given** a spec whose FRs declare no `traces:` continuation,
   **When** the user runs `zfa tdd plan <f>`, **Then** the behavior
   rows keep the criterion-only traces cell (fallback path unchanged),
   and re-planning a feature preserves its behavior ids (the
   reconciliation read of the traces cell accepts the new shape).

## Functional Requirements

- **FR-001**: The plan command MUST write the full trace set into every
  spec-derived behavior row's traces cell it emits (legacy single-file
  writers): the criterion id followed by the behavior's resolved
  contract-row names parsed from the spec's `traces:` continuation
  (`frTraces[currentId]`), comma-separated — e.g. `FR-001,
  TodoRepository.create`. A behavior whose FR declares no `traces:`
  continuation keeps the criterion-only cell.
- **FR-002**: The lane-plan row derivation (`_derivedLaneRows`) MUST
  carry the same full trace set into `04-ENGINE.md` / `04-SKIN.md` rows
  so lane plans match the test-list shape; preserved ffi rows and
  hand-declared lane rows are out of scope and keep their verbatim
  cells.
- **FR-003**: The plan-time re-plan reconciliation (the prior-list read
  that stabilizes `U`/`A` ids across re-plans) MUST keep working when
  the prior list carries the full trace set: the criterion key is
  resolved from the traces cell's leading criterion token, so a
  re-plan preserves ids and states instead of renumbering.
- **FR-004**: The change MUST NOT alter `RoutingResolver`,
  `DeclaredRouting`, `gen`, `make`, the contract scanner, or the verify
  gate semantics — the fix is confined to the plan command's row
  writers and its own reconciliation read.

## Success Criteria (measurable)

- SC-1: For the repro spec (FR-001 with `traces: TodoRepository.create`
  and declared `TodoRepository: create(String title) -> bool`),
  `zfa tdd plan` emits the unit row cell `FR-001, TodoRepository.create`
  (legacy and lane shapes), `zfa tdd gen U1` emits
  `bool subject_u1(String)` (declared return type, declared parameter)
  and a test asserting `expect(result, isA<bool>())` with no
  `vacuous-guard` marker.
- SC-2: For the same feature, `zfa tdd make U1` on a subject returning
  a dummy `bool` certifies green (no vacuous-green refusal) because the
  test carries a real outcome assertion.
- SC-3: An FR with no `traces:` continuation emits `FR-00N` (criterion
  only) in both plan shapes, byte-identical to the pre-fix emission.
- SC-4: Re-planning a feature whose prior list carries the full trace
  set preserves behavior ids (no renumbering), exactly as the
  criterion-only list does today; A/U row states re-emit as PENDING by
  design (state preservation is an ffi/contract-row property and stays
  out of scope).
- SC-5: `dart analyze` on the changed files reports no new issues and
  the targeted test suite (plan command tests + a new #1310 regression
  suite) passes.
