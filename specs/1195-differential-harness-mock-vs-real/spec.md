# Spec 1195 — [MOCK-FIRST] Differential harness — mock-era fixtures vs real-adapter contract outputs

Issue: https://github.com/arrrrny/zuraffa/issues/1195
Branch: `spec/1195-differential-harness-mock-vs-real`
Parent: #908 (P1 — the REAL tier's honesty gate, companion to #1193 `zfa tdd realize`)

## Problem

`zfa tdd realize` (spec 913) swaps the mock for the real adapter behind the
same interface and gates the crossing — but its differential gate compares
whole-field JSON values with a drift ratio. That is a byte-level lens, not a
contract lens:

- A value drift on an entity payload field (ids, timestamps, server-assigned
  data) is NOT a contract break, yet it counts against the drift budget.
- The three contract-relevant dimensions the ladder cares about — entity
  shapes, state transitions, error kinds — are not classified, so a
  divergence cannot name WHICH contract behavior diverged.
- Divergences are reported as `{kind, detail}` string blobs, not named rows
  (input, mock output, real output, contract clause) — the unified journal
  (#1113) cannot lift them.
- The report has no fixture-set digest, so replayability ("same fixtures,
  same report bytes", the spec-fuzz standard) is asserted, not proven.
- The differential can only run inside the full realize flow (rebind +
  suite runs first); there is no standalone replay mode.

Without the contract lens, "the contract suite is green on the real adapter"
is trust, not proof — the ladder's REAL tier would be decoration.

## What was built

1. **`DifferentialHarness`** (services/differential_harness.dart) — replays
   every committed fixture under `specs/<feature>/tdd/fixtures/` (the #832
   commitment, `realize-diff.v1` shape) through the certified mock side
   (the fixture's recorded `mockOutput`, driver fallback) and the real
   adapter (the `RealizeFixtureDriver` protocol — same typedef as before,
   moved to the harness), then diffs the contract-relevant projection:

   - **entity shapes** (default): field-name sets and type signatures
     (parity is shape, not bytes — the #915 convention; list length and
     map key sets are shape). Value drift inside a same-shape entity
     field is NOT a divergence.
   - **state transitions** (`state`, `status`, `nextState`, `fromState`,
     `toState`, `transition`, `transitioned`): value equality — state
     outcomes are contract.
   - **error kinds** (`error`, `errorKind`, `error_kind`, `errorCode`,
     `error_code`, `failure`, `failureKind`, `failure_kind`): value
     equality + presence parity — the error taxonomy is contract, and an
     error on one side only is the classic contract break.

   Per-field comparison mode is overridable via the fixture's `contract`
   map (`{"<field>": "value"}` pins exact-value parity), and clause
   attribution via the fixture's `clauses` map (`{"<field>": "SC-3: …"}`);
   the default clause is the dimension's parity statement.

2. **Named rows.** Every divergence is a structured row
   `{fixture, field, dimension, clause, input, mockOutput, realOutput,
   detail}` — the four fields the issue names (input, mock output, real
   output, contract clause) plus the classification. The default verdict
   is strict: any row blocks (threshold from `.zfa.json`
   `tdd.realizeDifferentialThreshold`, default 0.0 — same key, same
   inclusive boundary, same escape hatch as spec 913).

3. **Deterministic receipt.** `specs/<feature>/tdd/differential-receipt.json`
   (schema `realize-diff-receipt.v1`): fixed key order, 2-space indent,
   rows sorted by (fixture, field), NO timestamps, NO absolute paths, and
   a `fixtures.digest` (sha256 over the sorted fixture files' sha256s)
   binding the fixture set into the report — same fixtures, same report
   bytes, provable by digest. The old `differential-report.json` and the
   superseded `DifferentialGate` are deleted (the harness replaces the
   gate; the `realize-diff.v1` fixture shape is unchanged).

4. **Journal-consumable (#1113).** The receipt carries a `journal` block
   with the future journal entry's lift: `gate_state`
   (green|red|not_assessed — pass→green, divergence/runner-error→red
   [the gate fails closed], skipped→not_assessed), `violations` (row ids),
   `refs` (fixtures dir + this receipt, project-relative POSIX).

5. **`zfa tdd realize --diff-only`.** Runs ONLY the harness — no nuance
   scan, no baseline suite, no rebind, no contract suite, no state
   transition, no #807 rebind receipt. The target tree is untouched; the
   receipt (mode `diff-only`) and an era-tagged cycle-log entry
   (`kind: realize-diff`, era unchanged) are the only writes. Exit 0 on
   pass/skipped (skipped is named, never silent), 1 on divergence /
   runner-error. The embedded realize flow now runs the harness as THE
   differential gate after the contract gate: divergence rolls the rebind
   back and prints every named row.

## Success criteria

- SC-1: Same fixtures replayed through mock + real; contract-relevant
  outputs (entity shapes, state transitions, error kinds) diffed with
  named rows.
- SC-2: A divergence blocks the MOCKED→REAL promotion (embedded mode:
  rollback + exit 1; the row names input, mock output, real output,
  clause).
- SC-3: Deterministic — same fixtures, same receipt bytes (digest-bound,
  replayable like the spec-fuzz reports).
- SC-4: Receipt lands in the feature's tdd/ directory, journal-consumable
  (gate_state / violations / refs).
- SC-5: `zfa tdd realize --diff-only` replays the differential without
  touching the tree.
