# Spec 1311 — refactor pass invalidates proof receipts: the run driver's refactor phase must refresh receipts (sanctioned provenance event)

GitHub issue: arrrrny/zuraffa#1311
Severity: high — the two subsystems the workflow tells agents to run before
committing (`zfa proof check` and `zfa tdd verify`) cannot both pass after a
sanctioned `zfa tdd run` that applies a refactor.

## Problem

On a feature driven to green by the standard `zfa tdd run <feature>`
(two-cycle runner), `zfa proof check` FAILs with digest drift on the run's
own generated subjects, and `zfa tdd verify --feature <f>` refuses to audit
(NOT_ASSESSED, exit 3) because its proof preflight hits the same drift.

The mutating step is the runner's own refactor pass (`dart format --apply
lib/`, the fixed pass registry build → format → fix in
`refactor_passes.dart`), which runs AFTER make/compose/view recorded their
proof receipts — and no command refreshes receipts afterwards. Receipt
digests are recorded at artifact-write time inside make/compose/view
(`TddGenerationReceipts.write`), but the refactor phase rewrites those files
without appending/updating the receipts. `zfa proof` has no refresh/update
subcommand — only check — so the two surfaces cannot be reconciled by any
command. The printed remedy ("reproduce with: zfa tdd make") re-enters the
same cycle.

Repro:

```
zfa setup app --platforms=ios,macos && zfa tdd init --skin
# author spec, ingest, plan, then:
zfa tdd run <feature>          # completes green; phase-2 refactor applies dart format
zfa proof check                # FAIL — digest mismatches
zfa tdd verify --feature <feature>  # NOT_ASSESSED (proof preflight drift)
```

## Locked decisions

1. Fix ONLY the run driver's refactor phase (post-format receipt refresh)
   and/or the proof receipt recording (add refactor provenance event). The
   core engine cycle, make/compose/view artifact generation, the proof
   check algorithm, and the verify gate semantics are UNCHANGED.
2. The refactor pass stays mandatory — it is a sanctioned run phase; the
   fix never makes it optional and never suppresses it.
3. Remediation shape: the refactor command appends ONE proof.v1
   "sanctioned refactor" provenance event re-hashing every receipted path
   the passes actually mutated (latest-wins semantics in `ProofChecker`
   make the refreshed digests authoritative). Append-only: the original
   generation receipts stay on disk.
4. The refresh fires ONLY when a pass actually mutated a receipted file.
   Features that complete without a refactor mutation keep working
   unchanged (no new receipts, no behavior change).

## Functional requirements

- **FR-1 (post-refactor receipt refresh)**: After the run driver's refactor
  phase completes a sanctioned pass (preflight green, all passes exit 0,
  re-proof green), every proof.v1 receipted artifact the pass touched MUST
  be re-hashed to the formatted bytes via an appended refactor provenance
  event.
- **FR-2 (proof check passes after a sanctioned run)**: A feature that
  completed the standard `zfa tdd run` cycle (receipts written during
  make/compose/view, refactor applied) MUST pass `zfa proof check` with
  zero digest-drift (`modified`) findings.
- **FR-3 (tdd verify not blocked by proof preflight)**: After a sanctioned
  run, `zfa tdd verify --feature <f>` MUST NOT return NOT_ASSESSED due to
  proof preflight digest drift. The proof preflight passes so the verify
  audit can proceed (the audit's own verdict semantics are unchanged).
- **FR-4 (backward compatibility)**: Features that complete without a
  refactor pass mutating receipted files continue to work unchanged. The
  refresh only fires when the refactor pass actually mutates receipted
  files. Projects with no receipts are unaffected.
- **FR-5 (honest provenance)**: The appended event records the command
  (`tdd refactor`), the feature, the pass names that ran, a repro line, and
  the `update` action per re-hashed file. No fabricated digests: every
  recorded digest is derived from the on-disk bytes at event time.

## Acceptance scenarios (measurable)

1. **Given** a fixture project whose receipted `lib/` artifact carries a
   make-era digest of its pre-format bytes, **when** `zfa tdd refactor`
   completes green with `dart format` mutating that artifact, **then** a
   new proof.v1 receipt (command `tdd refactor`, `input.feature` set,
   sanctioned refactor provenance) covers the mutated path with the digest
   of the formatted bytes.
2. **Given** the same sanctioned refactor completed, **when** `zfa proof
   check --format json` runs, **then** it exits 0 with `ok: true` and zero
   findings.
3. **Given** the same sanctioned refactor completed, **when** `zfa tdd
   verify --feature <f>` runs (mutation audit unavailable for unrelated
   reasons), **then** the output does NOT contain the proof-preflight
   drift refusal ("failed the proof preflight") and the receipt preflight
   reports ok — the audit phase is reached.
4. **Given** a refactor that mutates no receipted file (clean lib, or only
   unreceipted files changed), **when** the refactor completes, **then** no
   refactor receipt is appended and the receipts tree is byte-identical.
5. **Given** a red preflight or a failing pass (misfire-stop) or a red
   re-proof, **when** the refactor refuses/regresses, **then** no refactor
   receipt is appended (only a completed sanctioned pass refreshes).
