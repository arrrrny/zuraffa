# Spec 1193 — [MOCK-FIRST] zfa tdd realize — the MOCKED→REAL swap with gates and receipts

Issue: https://github.com/arrrrny/zuraffa/issues/1193
Branch: `spec/1193-realize-mocked-to-real-swap`
Parent: #908 (P1 — the Contract Ladder `PENDING → RED → MOCKED → REAL → DONE`)

## Problem

The Contract Ladder's REAL tier had a command shape (spec 913 landed the
swap + contract/differential gates), but issue #1193 re-specs the tier's
honesty requirements — and four were still missing:

1. **No certified-mock location.** The swap scanned for mock bindings but
   never consulted the #1110 cert registry: a mock whose own
   certification was red could still carry the feature to REAL.
2. **No adapter seam.** A missing adapter class was a flat refusal — the
   developer got no receipted starting point behind the SAME interface,
   and nothing distinguished "the swap never generates real impls" from
   "the swap cannot even open the seam".
3. **No preview.** There was no zero-write way to see what a swap would
   do before it does it.
4. **No unified-journal advance.** The crossing wrote
   `realize-state.json` and an era-tagged cycle-log line, but the #1113
   journal — the ladder's memory — never recorded MOCKED → REAL → DONE,
   no behavior state advanced, and no hand-delta receipt carried the
   generated/mock/hand ratios.

## What was built (on top of spec 913's swap)

1. **Certified-mock location.** `RealizeCommand` consults
   `CertRegistry.checkEntity` (#1110) before anything moves: `certified`
   counts into the receipt's `mocks {total, certified}`; `missing`/
   `notReferenced` proceed NAMED (never silently assumed); `unsatisfied`/
   `corrupt`/`stale` BLOCK with the exact fix command — a red
   certification never crosses to REAL.
2. **The adapter seam (`--scaffold`).** A missing adapter class is
   scaffolded behind the SAME interface the certified mock implements:
   an `UnimplementedError` stub for every interface method, stamped as
   the hand-delta seam, recorded in the feature's provenance ledger
   (`recordedBy: zfa tdd realize --scaffold`) — receipted, NEVER pretended
   generated (no `// GENERATED` mark, no generation receipt). The
   scaffolder fails closed on members it cannot honestly stub (getters,
   fields, constructors). Re-scaffold never clobbers filled-in work.
   Without `--scaffold` the spec 913 refusal stands.
3. **`--dry-run`.** Previews the ENTIRE swap — the rebinding sites, the
   contract suite, the differential replay, the scaffold plan (validated,
   not written), the journal advance and its receipt — and writes
   NOTHING. Exit 0 when the swap would proceed, 1 with `would refuse:`
   naming every blocker. Mutually exclusive with `--diff-only`.
4. **The journal advance (#1113).** After both gates pass and the era
   flips: the covered behaviors' states advance `mocked → done` in
   `tdd/run-state.json` (only `mocked` behaviors — pending/red stay
   honest), and a schema-valid journal entry
   (`cycle: meta, phase: aggregate, gate_state: green, result: realized`)
   appends to `tdd/journal.json` listing the behaviors, counts, and the
   `mocks {total, certified}` accounting.
5. **The hand-delta receipt.** `specs/<feature>/tdd/realize-receipt.json`
   (schema `realize-receipt.v1`): the ladder advance (`MOCKED` → `REAL`
   with the behavior state), the gate outcomes (contract, differential,
   threshold, rows, compared, hand-deltas), EVERY file the swap touched
   with its post-write sha256 digest and provenance bucket
   (`generated` = rebind-written binding files carrying the #807
   receipt, `mock` = the certified mock's own files, `hand` = the
   adapter seam + gated hand-deltas), the generated/mock/hand ratios
   with the spec-070 `G%/M%/H%` cell, and the mock certification counts.

## Acceptance mapping

- A feature driven to `complete(mocked)` realizes to `complete(real)`
  with zero test edits — the mock-era suite runs UNCHANGED (spec 913's
  contract gate, unchanged) and the journal records the ladder advance.
- A failing differential gate blocks REAL — unchanged (spec 1195's
  harness rolls the rebind back); additionally a failing CERTIFICATION
  now blocks before anything moves.
- Receipt records the swap (files, digests, gate outcome) — the
  `realize-receipt.v1` hand-delta receipt.

## Success criteria

- SC-1: The certified mock behind the interface is located (#1110); red
  certification blocks; missing certification is named, never assumed.
- SC-2: `--scaffold` opens the hand-delta seam behind the SAME interface,
  receipted in the provenance ledger, never pretended generated.
- SC-3: `--dry-run` previews every write and writes nothing.
- SC-4: A realized swap advances the unified journal: behaviors
  `mocked → done` (only mocked ones), era `MOCKED → REAL`, one
  schema-valid meta entry in `tdd/journal.json`.
- SC-5: The swap writes `realize-receipt.v1` with files, digests, gate
  outcomes, and generated/mock/hand ratios.

## Depends on

- #1176-adjacent idempotent DI (landed) — the rebind's idempotent
  already-real path.
- The unified journal (#1113) — `JournalWriter`/`JournalSchema`.
- The differential harness (#1195) — embedded gate, unchanged.
- The cert-gate (#1110) — `CertRegistry`.
