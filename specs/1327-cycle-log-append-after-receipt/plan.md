# Plan 1327 — terminal cycle-log receipt at run end (result=complete implies proof check OK)

GitHub issue: arrrrny/zuraffa#1327

## Technical Context

- **Language/runtime**: pure Dart (SDK ^3.11.0; toolchain Dart 3.13.3). No
  Flutter in the changed paths — Constitution VII (pure-Dart core) holds.
- **Run driver surfaces**: `RunCommand` (`run_command.dart`, the meta
  driver) chains `RunDriverCore.drive(lane: 'engine'|'skin')`; the
  standalone lanes `RunEngineCommand` / `RunSkinCommand` call the same
  core. Lane steps spawn as subprocesses (`gen`/`verify-red`/`make`/
  `refactor`); `make` appends green evidence to
  `specs/<f>/tdd/cycle-log.md` then receipts the log (`tdd make` receipt);
  `refactor` appends refactor evidence after the #1311 lib/ refresh; the
  meta run appends the unified two-cycle journal entry
  (`LaneReceipts.appendUnifiedJournalEntry`) after both lanes complete —
  the LAST append in a meta run.
- **Proof receipts**: proof.v1 documents under `.zfa/receipts/`
  (`receipt_store.dart`: `GenerationReceipt`, `GenerationReceiptFile
  {path, action, sha256, bytes, snapshot?}`, timestamped append-only
  names, oldest-first load). `ProofChecker` (`proof_checker.dart`)
  re-derives every digest, latest receipt per path wins; a NEWER receipt
  with fresh digests for a path supersedes older ones WITHOUT any checker
  change. `zfa proof check` exits 0 iff findings are empty.
- **Verify gate scoping**: `zfa tdd verify`'s proof preflight scopes by
  `input.feature == featureName` OR file paths under
  `specs/<featureName>/` — a terminal receipt that re-declares the feature
  and covers the log path is recognized with zero changes to the gate.
- **Receipt write machinery**: `TddGenerationReceipts.write` hashes the
  CURRENT bytes of every mapped file (skips missing files, no-op when
  nothing exists) and stamps `input.feature`; `writeBestEffort` reports
  failures on stderr. `RefactorReceiptRefresh.refreshBestEffort` (#1311)
  established the best-effort sanctioned-event pattern this plan reuses.

## Approach

Append ONE terminal proof.v1 receipt at run end — the issue's remediation
(a), achieved with the existing latest-wins machinery (no checker change):

- New service `CycleLogTerminalReceipt`
  (`lib/src/plugins/tdd/services/cycle_log_terminal_receipt.dart`) with
  `refreshBestEffort({projectRoot, feature, command})`: maps
  `<projectRoot>/specs/<feature>/tdd/cycle-log.md` → `'update'` and calls
  `TddGenerationReceipts.write` with `command` (`tdd run` / `tdd
  run-engine` / `tdd run-skin`), `target`/`input.feature` = the feature,
  `input: {sanctioned: true, terminal: true}`. Digests are re-derived from
  the log's FINAL bytes at write time (FR-1, honest provenance). Failures
  are caught, warned on stderr with the issue reference, never fatal
  (FR-4). A missing log file writes nothing (`write` skips it).
- `RunCommand._run` (meta): after `appendUnifiedJournalEntry` + the
  structured meta journal entry — the point after the run's LAST append to
  the log — call the service with `command: 'tdd run'`, then print the
  summary line (the summary stays the final stdout line, FR-009/FR-010).
- `RunEngineCommand._run` / `RunSkinCommand._run` (standalone lanes):
  after `drive()` returns `result=complete`, call the service with
  `command: 'tdd run-engine'` / `'tdd run-skin'` before the summary line.
  Non-complete outcomes return early on their existing paths and write
  nothing (FR-3).
- The checker, the verify gate, make/compose/view, the refactor pass, and
  the engine cycle are untouched (SC-5).

Why the terminal receipt and not the append-prefix checker exemption: the
checker sees only bytes. A complete run's post-receipt appends and a
stopped run's post-receipt appends are indistinguishable byte-prefix
growth, so prefix verification would erase the incomplete-run drift
findings that acceptance criterion 4 declares expected-and-correct. The
terminal receipt keeps the drift semantics intact for every non-complete
run while making `result=complete` imply proof check OK.

## Non-goals / risks

- The proof checker algorithm and its finding vocabulary are unchanged
  (forbidden surface).
- `make`'s own receipt (the last `tdd make` one) stays stale on disk —
  by design, append-only provenance; latest-wins resolves it.
- The skin conformance mode's cycle-log appends (spec 1005 path) are a
  separate driving mode outside this issue's repro; the lane terminal
  receipt still covers the standard skin lane. Not changed here.
- A vacuous complete re-run (all behaviors DONE, zero steps spawned)
  still appends the unified journal entry and still gets the terminal
  receipt — the invariant is per-run, not per-append.
- Risk: extra receipts per run (one per complete lane/command) — bounded,
  timestamped, append-only; matches the per-step receipt volume make
  already produces.

## Test strategy

End-to-end through the public CLI surface (`CliRunner.runCapturing`) with
the TddFixture two-cycle harness (`test/plugins/tdd/run_command_test.dart`
conventions): the scripted fake zfa appends red/green evidence exactly
like the real steps; a seeded `tdd make` receipt stands for the real
make's coverage (the fake cannot compute digests). The drift precondition
is asserted before the fix-dependent assertions. Backward compat pins the
stopped-run drift. Red protocol: per-file `dart test` only (cloud disk
ceiling), never the full suite.
