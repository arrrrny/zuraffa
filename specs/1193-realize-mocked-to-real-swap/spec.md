# Spec 1193 — [MOCK-FIRST] zfa tdd realize: the MOCKED→REAL swap with gates and receipts

Issue #1193 (part of #908 Mock-First Realization, P1). Closes #1193.

## Problem

The Contract Ladder is `PENDING → RED → MOCKED → REAL → DONE`. RED and
MOCKED machinery exist (verify-red, certified mocks, run-skin). The REAL
tier has no command: spec 913's entity-level `zfa tdd realize <entity>
--adapter <RealClass>` refuses to proceed unless the developer has
ALREADY written the adapter by hand (`locateAdapter` throws), never
advances the per-behavior ladder, never records generated/mock/hand
ratios, and cannot be driven per FEATURE the way the corpus drives
features to `complete(mocked)`.

## Requirements

### FR-001 — Feature-driven target with certified-mock location
`zfa tdd realize <feature> --adapter <name> [--dry-run]` resolves the
feature directory `specs/<feature>` and locates the entities behind the
behavior's interface per the engine receipt: `specs/<feature>/tdd/
engine.receipt.json` (v2) first, then the v1 grouped receipts under
`.zfa/receipts/<feature>/`, then the artifacts-registry entity
descriptions, then the `<Entity>MockDataSource` declarations under
`lib/`. An engine receipt that marks a method `mock_certified: false`
blocks the swap with the exact `zfa mock create <Entity> --certify` fix
(the honest ladder — we never realize behind an uncertified mock).

### FR-002 — REAL adapter scaffold (hand-delta seam)
When no file under `lib/` declares the resolved adapter class, realize
scaffolds it BEHIND THE SAME INTERFACE: the `implements` clause is read
from the certified mock's declaration and every member signature is read
from the interface file. The scaffold:
- is explicitly header-marked as a HAND-DELTA SEAM (never pretended
  generated: no `proof.v1` generation receipt is written for it);
- is immediately gated as a nuance receipt in the feature's provenance
  ledger (`tdd/provenance-ledger.json`) with reason
  `adapter scaffold seam (issue #1193)`;
- carries `throw UnimplementedError(...)` bodies — the developer fills
  in the real nuance, and the contract gate honestly blocks the swap
  until they do.

### FR-003 — Idempotent, unregister-first DI swap
The swap rebinds every mock binding site to the real adapter behind the
SAME generated interface (mock symbol out, adapter symbol in, import
fixup, byte-identical `domain/` proof — the 913 DiRebinder contract).
Idempotency: a re-run with the same adapter is an `already-real` no-op
(exit 0); a tree whose mock symbols were already swapped (crash between
rebind and state save) is detected and NOT re-swapped; a re-realize to a
different adapter swaps the currently-bound adapter class out
(unregister-first at the file level).

### FR-004 — Contract suite re-run UNCHANGED
The mock-era suite (the feature's registered test files) runs once
against the mock binding (baseline, before any rebind) and once against
the real binding (after all rebinds). Zero test edits: no test file's
bytes may change during a realize run. A red real-binding run rolls
every rebind back and attributes the break (`real-broke-contract` /
`mock-broke-contract`).

### FR-005 — Differential gate
Mock-era fixtures vs real-adapter outputs must agree on
contract-relevant behavior (the 913 DifferentialGate, driven per
entity). Non-fixture JSON in `tdd/fixtures/` (the #832 `manifest.json`
and `mock-cert.*` receipts) is skipped, never a runner-error. Drift
beyond the `.zfa.json` threshold blocks REAL: rollback, era stays
MOCKED, ladder untouched.

### FR-006 — Ladder advance MOCKED → REAL → DONE + receipt
After both gates pass, realize advances:
- the per-entity era `tdd/realize-state.json`: MOCKED → REAL with gate
  evidence (913 transition record);
- the per-behavior ladder `tdd/run-state.json`: behaviors of the
  realized entities advance `mocked → real → done` (the REAL tier is a
  first-class `BehaviorState`; the terminal write lands only when the
  contract suite re-run is green — the command's own verification);
- the unified journal: era-tagged `kind: realize` cycle-log entries
  (era REAL, hash-chained) plus one `## Realization: <feature>` unified
  entry naming the gates and the receipt (the `appendUnifiedJournalEntry`
  no-behavior-field convention, so evidence parsers read past it);
- the simulation-mode binding is retired: `tdd/fixtures/manifest.json`
  (the complete(mocked) marker the provenance reader derives) is removed
  after its digest is recorded — the mock-era fixture JSONs stay as
  differential evidence, so `FeatureProvenanceReader` derives
  `complete(real)`.
- a hand-delta receipt `.zfa/receipts/realize.<feature>.<adapterName>
  .receipt.json` records the swap: files + digests (rebind writes and
  the retired manifest), gate outcome (contract + differential verdicts,
  drift, threshold, fixtures), ladder transitions, and the
  generated / mock / hand ratios (the FeatureProvenanceReader buckets).
  The document is double-shaped `proof.v1` so `zfa proof check` parses
  and counts it.

### FR-007 — --dry-run
`--dry-run` prints the full plan (entities resolved, adapter resolution
per entity — existing class / scaffold path, binding sites, gates to
run, ladder writes, manifest retirement) and writes NOTHING: no
scaffold, no rebind, no state, no receipts, no manifest deletion.

### FR-008 — REAL-tier state integration
`BehaviorState.real` integrates with the existing machinery: lane
receipt counts treat it as the green tier, the run driver's step
sequencing and reconcile treat it like `mocked`/`green` (a REAL behavior
re-drives at refactor and keeps its claim only with green evidence),
run-state serialization round-trips it, and the doctor backs a `real`
claim with green evidence.

## Acceptance criteria

- SC-1: A feature driven to `complete(mocked)` (green behaviors +
  fixtures manifest) realizes to `complete(real)` with ZERO test edits
  (verified through `FeatureProvenanceReader` and byte comparison of
  every registered test file before/after).
- SC-2: A failing differential gate blocks REAL — the rebind rolls
  back, the era stays MOCKED, the manifest stays, the ladder stays.
- SC-3: The receipt records the swap — files, digests (re-derived from
  the on-disk bytes), gate outcome, ratios — and parses as `proof.v1`.
- SC-4: The 913 entity/behavior surface is unchanged (the existing
  realize command tests stay green).

## Out of scope

- The #1113 structured `journal.json`/JournalReader (open issue — this
  spec's unified journal is the cycle-log convention #1008 established).
- Generating real adapter BEHAVIOR (the honest 90/10: real nuance is
  hand-written; realize only scaffolds the seam and gates the swap).
- Tier-2 differential providers (#1009 realize-mock stays as-is).
