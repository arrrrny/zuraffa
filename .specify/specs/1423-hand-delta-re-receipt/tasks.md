# Tasks: 1423-hand-delta-re-receipt

- **Spec ID**: 1423-hand-delta-re-receipt
- **Created**: 2026-09-13
- Ordering: MVP-first — the red tests (T1) pin every success criterion before
  any implementation lands; behavioural tasks carry the test-first marker.

## Phase 1 — Spec & failing tests (MVP)

- [x] T1 (test-first, behavioural) Write
  `test/plugins/tdd/issue_1423_hand_delta_re_receipt_test.dart`: service-tier
  tests (S1–S5) pinning the `HandDeltaReceipts` contract, end-to-end tests
  (E1–E4) pinning SC-1..SC-4 through the CLI surface against `TddFixture`
  projects. RED before implementation: every SC test fails on master
  (no `hand_delta` receipts exist; doctor prints `stores agree`).
- [x] T2 (non-behavioural) Record the RED evidence
  (`tdd/verification.md` run log, `dart test` transcripts summarized).

## Phase 2 — Minimal re-receipt path (MVP implementation)

- [x] T3 (test-first, behavioural) New service
  `lib/src/plugins/tdd/services/hand_delta_receipt.dart`:
  `HandDeltaReceipts.refresh` (+ `refreshBestEffort`) — normalize the
  recorded test/subject paths, intersect with the receipted set, re-hash
  drifted paths from disk, append ONE sanctioned proof.v1 event
  (`TddGenerationReceipts.write`, action `update`, `input.sanctioned` /
  `input.hand_delta` / `input.transition`). Makes S1–S5 green.
- [x] T4 (test-first, behavioural) `verify_red_command.dart` — the #1162
  `--re-certify` transition calls `HandDeltaReceipts.refreshBestEffort`
  after the green-evidence receipt (command `tdd verify-red --re-certify`,
  transition `re-certify`). Makes E1/E3 green.
- [x] T5 (test-first, behavioural) `make_command.dart` — the skip transition
  (`alreadyGreen` && !`adoptedReDrive` at the step-10 receipt site) calls
  `HandDeltaReceipts.refreshBestEffort` (command `tdd make`, transition
  `skip`). Makes E2/E4 green.

## Phase 3 — Doctor visibility (SC-4)

- [x] T6 (test-first, behavioural) `doctor_command.dart` — new hand-delta
  drift check before the `stores agree` healthy line: latest receipt digest
  vs disk digest per recorded test/subject path; drift ⇒ exit 1, drift lines
  naming behavior + path + both digests, prescription `verify-red <id>
  --re-certify` (red-backed) or `zfa tdd run <feature>`; never
  `zfa tdd gen`. Makes E5/E6 green.

## Phase 4 — Verification & hygiene

- [x] T7 (non-behavioural) `dart analyze` on the changed files — no new
  warnings; `dart format` the touched files.
- [x] T8 (non-behavioural) Full `dart test` on the new spec file green;
  existing tdd-plugin receipt/preflight/doctor suites unaffected.
- [x] T9 (non-behavioural) Write `tdd/verification.md` from the REAL runs;
  update the spec checklist; commit + push; open the PR (Closes #1423).
