# Plan 1311 — post-refactor receipt refresh via a sanctioned refactor provenance event

GitHub issue: arrrrny/zuraffa#1311

## Technical Context

- **Language/runtime**: pure Dart (SDK ^3.11.0; toolchain Dart 3.13.3). No
  Flutter in the changed paths — Constitution VII (pure-Dart core) holds.
- **Run driver (refactor phase)**: `lib/src/plugins/tdd/commands/run_driver_core.dart`
  spawns every step as a subprocess (`StepRunner.run`: `tdd <step>
  <behavior-id> --feature <f> --project <dir>`). The phase-1 refactor step
  and the phase-2b refactor pass both spawn `zfa tdd refactor`
  (`RefactorCommand`), which owns the fixed pass registry
  (`refactor_passes.dart`: resolved `zfa build` → `dart format lib/` →
  `dart fix --apply lib/`). A change inside `RefactorCommand` therefore
  covers BOTH the run-driven refactor phases and standalone
  `zfa tdd refactor` — one surface, no driver changes.
- **Proof receipt format**: proof.v1 documents under `.zfa/receipts/`
  (`lib/src/core/project/receipt_store.dart`: `GenerationReceipt`,
  `GenerationReceiptFile {path, action, sha256, bytes, snapshot?}`,
  timestamped append-only names `…-<cmd>-<target>.json`). Receipts are
  written at artifact-write time by `TddGenerationReceipts.write[BestEffort]`
  from plan/gen/verify-red/make/wire/view/func/compose.
- **proof_check.dart**: `lib/src/core/proof/proof_checker.dart` re-derives
  every digest; `latest` = last receipt per artifact path (records sorted
  oldest-first, later receipt wins). A new receipt with fresh digests for a
  path supersedes older receipts for that path — WITHOUT any change to the
  checker. `zfa proof check` (lib/src/commands/proof_command.dart) exits 0
  iff findings are empty.
- **Verify gate**: `zfa tdd verify` (verify_command.dart) refuses with
  NOT_ASSESSED (exit 3) when `_proofPreflightDrift` (feature-scoped via
  `input.feature`) finds drift, then runs the spec-0996 `ReceiptPreflight`
  (all receipts must validate; audited subjects must be covered). Both read
  the same receipts the refactor event refreshes.

## Approach

Append-only provenance event (issue option (a)) that also achieves the
re-hash effect (option (b)): after a sanctioned refactor completes
(preflight green/tolerated, all passes exit 0, re-proof green/tolerated),
the refactor command computes the intersection of the pass-registry-changed
`lib/` paths with every receipted path and, when non-empty, appends ONE
proof.v1 receipt via the existing `ReceiptStore` + `TddGenerationReceipts`
machinery:

- `command: 'tdd refactor'`, `target: <feature>`, `repro: 'zfa tdd
  refactor --feature <feature>'`
- `input: {feature, sanctioned: true, refactor: true, passes: [names]}`
- one `files[]` entry per mutated receipted path: `action: 'update'`,
  `sha256`/`bytes` of the CURRENT on-disk bytes (honest, re-derived —
  never copied from the old receipt).

Latest-wins in `ProofChecker` makes the refreshed digests authoritative;
the verify preflight scoping (`input.feature`) recognizes the paths because
the original generation receipts already declare the feature and the event
re-declares it. The proof check algorithm, the verify gate semantics, the
engine cycle, and make/compose/view are untouched.

## Non-goals / risks

- test.v1 (`TestReceiptStore`, the `zfa test` plugin family) usecase
  bindings are a separate receipt kind; `dart format` does not touch
  `test/`, and the issue's repro involves the proof.v1 family only.
  Out of scope (would change test.v1 semantics — forbidden surface).
- Best-effort failure mode mirrors `TddGenerationReceipts.writeBestEffort`:
  a receipt-write failure warns on stderr and never flips a sanctioned
  refactor to a failure (fail-visible later via `zfa proof check`, honest).
- The summary-line contract (FR-009: `refactor: feature=<f> outcome=<o>
  applied=<n>` as the FINAL stdout line) is preserved — refresh prints
  happen before the summary.

## Milestones

1. RED — failing tests pinning FR-1..FR-5 (see tdd/test-list.md).
2. GREEN — `RefactorReceiptRefresh` service + minimal wiring in
   `RefactorCommand._run` (after the post-re-proof misfire-stop check,
   before the evidence append and the summary line).
3. VERIFY — targeted tests, `dart analyze` on changed files, `dart format .`,
   evidence recorded in tdd/verification.md.
