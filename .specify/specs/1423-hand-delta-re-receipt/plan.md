# Plan: 1423-hand-delta-re-receipt

- **Spec ID**: 1423-hand-delta-re-receipt
- **Created**: 2026-09-13

## Technical Context

- **Gen receipt timing**: `zfa tdd gen` writes the artifact registry
  (`specs/<feature>/tdd/artifacts.json`) and one proof.v1 receipt per run
  under `.zfa/receipts/` via `TddGenerationReceipts.write`
  (`lib/src/plugins/tdd/services/tdd_generation_receipt.dart`) — each
  receipted file carries `(path, action, sha256, bytes, snapshot?)` of the
  bytes AT GEN TIME. `input.feature` scopes the receipt to the feature;
  `zfa tdd verify`'s proof preflight (`_proofPreflightDrift` in
  `verify_command.dart`) collects exactly those paths and refuses on the
  first `ProofChecker` finding.
- **Latest-wins resolution**: `ProofChecker.check()`
  (`lib/src/core/proof/proof_checker.dart`) loads receipts oldest-first and
  indexes `latest[entry.path]` as it walks — a LATER receipt covering the
  same path supersedes the older gen digest WITHOUT any change to the check
  algorithm. This is the property the fix relies on (same as #1311).
- **The #1311 precedent (the pattern)**: `RefactorReceiptRefresh`
  (`lib/src/plugins/tdd/services/refactor_receipt_refresh.dart`) intersects
  the refactor pass' changed paths with the receipted set, re-hashes the
  survivors from CURRENT disk bytes, and appends ONE sanctioned proof.v1
  event (command `tdd refactor`, `input.sanctioned`/`input.refactor`). Best
  effort: a receipt failure warns on stderr and never flips the verb.
- **Make skip transition**: `make_command.dart` — `alreadyGreen` (the drift
  re-run passed) with no #1331 adoption is the issue #694 skip transition;
  the shared receipt site (step 10) writes ONLY
  `tdd/cycle-log.md` today. The #1036 subject-drift guard runs BEFORE it,
  so a skip that reaches the receipt site has already validated the subject
  shape against the certified evidence.
- **verify-red re-certify**: `verify_red_command.dart` — the issue #1162
  `--re-certify` transition requires certified red evidence AND a subject
  hash that differs from it (the born-green vacuity is refused), appends
  green evidence bound to the CURRENT subject hash, and writes the cycle-log
  receipt (command `tdd verify-red --re-certify`) ONLY.
- **Proof preflight drift check**: `_proofPreflightDrift` scopes receipted
  paths by `input.feature` (plus `specs/<feature>/`) and returns the FIRST
  `ProofChecker` finding — the `digest mismatch: receipt says …, disk has …
  (action: create)` line of the repro. UNCHANGED by this spec.
- **Doctor**: `doctor_command.dart` compares stores (registry, run-state,
  cycle-log) and prints `stores agree — no drift detected` only when every
  check passes. It never reads `.zfa/receipts/` today — the proof layer is
  invisible to it (SC-4's blind spot).
- **Language/SDK**: Dart 3.13.3 stable, pure Dart. Tests: `package:test`,
  the `TddFixture` convention (`test/plugins/tdd/helpers/tdd_fixture.dart`)
  with real `dart test` subprocesses for the end-to-end tiers.

## Architecture

```
 hand-delta (designed):  gen ──▶ <id>:hand stop ──▶ hand-edit test+subject
                              ──▶ verify-red --re-certify ──▶ make skip ──▶ verify

 BEFORE (bug):           receipts: [gen: test@A, subject@B, cycle-log@…]
                         disk:     test@A', subject@B'   (A'≠A, B'≠B)
                         verify-red --re-certify → +receipt(cycle-log@C) only
                         make skip              → +receipt(cycle-log@D) only
                         latest-wins ⇒ test@A, subject@B  ⇒ PREFLIGHT REFUSES

 AFTER (fix):            HandDeltaReceipts.refresh(command, transition,
                                  artifactPaths: [testPath, subjectPath])
                           ├─ normalize both to project-relative POSIX
                           ├─ keep only paths ALREADY receipted (never fabricate)
                           ├─ keep only paths whose disk digest ≠ latest digest
                           ├─ missing files skipped honestly (deleted stays visible)
                           └─ ≥1 survivor ⇒ append ONE proof.v1 event
                                command: 'tdd make' | 'tdd verify-red --re-certify'
                                files:   {survivor: 'update'} (digest from disk)
                                input:   {sanctioned: true, hand_delta: true,
                                          transition: 'skip'|'re-certify', feature}
                         latest-wins ⇒ test@A', subject@B' ⇒ PREFLIGHT VALIDATES

 doctor (SC-4):          new check before the healthy line:
                           for each registry record's test/subject path:
                             latest receipt digest ≠ disk digest
                               ⇒ drift line (behavior + path + both digests)
                               ⇒ verdict drift, exit 1
                               ⇒ fix: verify-red <id> --re-certify (red-backed)
                                      | zfa tdd run <feature> (no red evidence)
                               ⇒ never `zfa tdd gen` (#1375 destructive remedy)
```

## Contract deltas

| Site | Before | After |
|---|---|---|
| make skip (step 10 receipt site) | receipts cycle-log only | + appends hand-delta event for drifted receipted pair (SC-1) |
| verify-red `--re-certify` | receipts cycle-log only | + appends hand-delta event for drifted receipted pair (SC-2) |
| doctor | "stores agree" while proof layer red | hand-delta drift check before healthy (SC-4) |
| gen receipts / preflight / state machine | — | UNCHANGED |

## Risks / notes

- The re-receipt fires ONLY on actual drift (digest differs) → idempotent:
  a second skip/re-certify over an already-healed pair writes nothing.
- Unreceipted artifact paths (no gen receipt, e.g. legacy fixtures) are not
  this bug's class — skipped, never fabricated provenance.
- `TddGenerationReceipts.write` skips non-existent files; the service still
  checks existence to keep the report honest (nothing refreshable ⇒ no
  receipt document at all).
- Receipt writes are best-effort (stderr warning on failure) — a receipt
  failure must never flip a sanctioned certification (the #1311 contract).
- Doctor's new check loads the receipt store lazily and fails open (unread
  receipts ⇒ no hand-delta findings; the preflight still gates verify).
