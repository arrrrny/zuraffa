# Spec 1327 — cycle-log append after receipt: the run driver must close a complete run with a terminal cycle-log receipt

GitHub issue: arrrrny/zuraffa#1327
Severity: high — the #1311 remediation refreshed the receipts for the
refactor pass's reformatted subject files, but a sanctioned complete run
STILL fails `zfa proof check` with exactly one digest-drift finding on
`specs/<f>/tdd/cycle-log.md` (the same unexecutable-remedy class as #1311:
the printed remedy re-enters a cycle that can never re-receipt the file).

## Problem

The run driver's post-make phases append evidence to
`specs/<f>/tdd/cycle-log.md` AFTER the last receipt covering that log was
written:

1. `zfa tdd make` appends the behavior's green evidence and THEN writes a
   `tdd make` proof.v1 receipt covering the log's bytes at that moment
   (`make_command.dart`, `TddGenerationReceipts.writeBestEffort`).
2. The refactor step (`zfa tdd refactor`) appends its refactor evidence to
   the same log afterwards. The #1311 refresh
   (`RefactorReceiptRefresh`) covers only the pass-registry-changed `lib/`
   paths intersected with receipted paths — the log itself is never
   re-hashed.
3. The meta run (`zfa tdd run`) appends the unified two-cycle journal
   entry to the log after both lanes complete
   (`LaneReceipts.appendUnifiedJournalEntry`) — again uncovered.

`ProofChecker` re-derives every recorded digest and resolves latest-wins
per artifact path, so the stale `tdd make` digest produces:

```
[modified] specs/deal_list/tdd/cycle-log.md
  digest mismatch: receipt says 53edad53319b, disk has ed5c496d050c (action: update)
proof: 27 receipt(s), 14 artifact(s) verified, 1 finding(s) — FAIL
```

The printed remedy (`reproduce with: zfa tdd make`) is a no-op on the
completed behavior (outcome=skipped — it never re-receipts). The invariant
the user relies on before committing — `result=complete` implies
`zfa proof check` OK — is broken on EVERY sanctioned complete run.

Timeline from the issue: the latest receipt covering `cycle-log.md` is
`15:28:32-tdd_make-A1.json`; the run then appended A1's refactor evidence
(`[run] A1 refactor -> refactored`) to the same log before exiting.

## Acceptance criteria (from the issue)

1. **Terminal receipt at run end**: after the last append to
   `cycle-log.md`, the run driver MUST refresh or append a terminal
   receipt covering `cycle-log.md`; `zfa proof check` passes with zero
   findings on a sanctioned complete run.
2. **Append-only log semantics (ALTERNATIVE)**: treat append-only logs as
   receipt-exempt with prefix verification in the checker — the
   ALTERNATIVE approach; the issue grants either terminal receipt OR
   append-prefix verification.
3. **result=complete implies proof check OK**: a run that exits complete
   (all behaviors green/done) MUST pass `zfa proof check` with zero
   digest-drift findings.
4. **Backward compatibility**: runs that are NOT complete (stopped early,
   pending behaviors remain) continue to have receipt drift on
   `cycle-log.md` — expected and correct (the run mutated files after its
   receipts).

## Locked decisions

1. Fix ONLY the run driver's post-make receipt refresh (terminal receipt
   for `cycle-log.md`). The core engine cycle, the make/compose/view
   artifact generation, the refactor pass, the verify gate, and the
   `ProofChecker` check algorithm are UNCHANGED.
2. Remediation shape: the TERMINAL-RECEIPT branch of criterion 2's
   either/or. The append-prefix checker exemption is deliberately NOT
   implemented: `ProofChecker` cannot distinguish a complete run's
   post-receipt appends from a stopped run's post-receipt appends (both
   are pure byte appends after the receipted prefix), so prefix
   verification would erase the incomplete-run drift findings that
   criterion 4 pins as expected-and-correct. The two criteria are jointly
   satisfiable only by the terminal receipt.
3. The terminal receipt is ONE appended proof.v1 document (command
   `tdd run` / `tdd run-engine` / `tdd run-skin`, `input.feature`,
   `sanctioned: true`, `terminal: true`) re-hashing
   `specs/<f>/tdd/cycle-log.md` to its FINAL bytes via the existing
   `ReceiptStore`/`TddGenerationReceipts` machinery. Latest-wins in
   `ProofChecker` makes it authoritative; the original generation
   receipts stay on disk (append-only provenance).
4. The terminal receipt fires ONLY on a complete run (`result=complete`).
   A run that stopped early, errored, or was refused preflight writes
   nothing — its receipt drift stays the honest record (criterion 4).
5. Best-effort discipline (mirrors `TddGenerationReceipts.writeBestEffort`
   and `RefactorReceiptRefresh.refreshBestEffort`): a receipt-write
   failure warns on stderr and never flips the run's exit code; the loss
   stays fail-visible through `zfa proof check`.

## Functional requirements

- **FR-1 (terminal receipt)**: when the run driver family (`zfa tdd run`,
  `zfa tdd run-engine`, `zfa tdd run-skin`) finishes a lane drive with
  `result=complete`, it MUST end with a proof.v1 receipt covering
  `specs/<feature>/tdd/cycle-log.md` whose digest is re-derived from the
  log's final on-disk bytes (never copied from an older receipt), written
  after the run's last append to the log (the meta run's unified journal
  entry included).
- **FR-2 (complete implies proof OK)**: after a sanctioned complete run,
  `zfa proof check` reports zero findings and exits 0; the drift finding
  on `cycle-log.md` is gone.
- **FR-3 (backward compatibility)**: a run that does NOT complete writes
  NO terminal receipt; the pre-existing drift findings on
  `cycle-log.md` remain exactly as before the fix.
- **FR-4 (best-effort)**: a terminal-receipt write failure is reported on
  stderr, never fatal to the run that already drove.
- **FR-5 (append-only provenance)**: the terminal receipt APPENDS to
  `.zfa/receipts/`; no receipt is ever rewritten or deleted.

## Success criteria (measurable)

- SC-1 (AC1/AC3): drive a fixture feature to `result=complete` twice
  (the second drive appends the unified journal entry after the receipt
  that stands for the last `tdd make` coverage) — `zfa proof check
  --format json` exits 0 with `ok: true`, `valid: true`, zero findings.
  Pre-fix this fails with exactly one `modified` finding on
  `specs/<f>/tdd/cycle-log.md` ("digest mismatch: receipt says …, disk
  has … (action: update)").
- SC-2 (AC1): the receipts tree after the complete run contains the
  terminal receipt: command `tdd run`, `input.feature` = the feature,
  `input.sanctioned = true`, `input.terminal = true`, one `files[]` entry
  for `specs/<f>/tdd/cycle-log.md` with `action: 'update'` and
  `sha256` equal to the digest of the log's final bytes.
- SC-3 (AC1, lane): a standalone `zfa tdd run-engine` that completes from
  a receipted pre-run log state ends with the same terminal coverage
  (command `tdd run-engine`) and `zfa proof check` passes.
- SC-4 (AC4): a run that stops early (a pending behavior stops at its
  make step after the red evidence landed) leaves the `modified` finding
  on `cycle-log.md` in place and appends no new terminal receipt.
- SC-5 (FR-4): the checker algorithm is untouched — no diff outside the
  run-driver surfaces, the new service, tests, and spec artifacts.
