# Tasks 1311 — post-refactor receipt refresh (MVP-first, dependency-ordered)

## Phase 1 — RED (behavioral, test-first)

- [ ] T001 Write `test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart`
      fast-tier unit group: `RefactorReceiptRefresh` (service API) —
      B7/B8 (FR-1, FR-4, FR-5). Blocked by nothing; the service does not
      exist yet (red = compile/API failure is not recorded as behavior red;
      the behavior reds are the CLI-level groups below).
- [ ] T002 Same file, CLI group "sanctioned refactor refreshes receipts":
      B1/B2/B3 (FR-1, FR-2) — receipted lib artifact mutated by the pass
      registry → refactor receipt appended with formatted-bytes digests;
      `zfa proof check --format json` exits 0 with zero findings.
- [ ] T003 Same file, CLI group "verify unblocked": B4 (FR-3) — after the
      sanctioned refactor, `zfa tdd verify` output contains the receipt
      preflight ok line and NOT the proof-preflight drift refusal.
- [ ] T004 Same file, CLI group "backward compatibility": B5/B6 (FR-4) —
      clean lib (no mutation) and unreceipted-only mutation append NO
      refactor receipt.
- [ ] T005 Record red evidence (expected failures) in the test file header
      notes and run the groups; confirm the AC2/AC3 groups fail on
      digest drift pre-fix.

## Phase 2 — GREEN (implementation, MVP)

- [ ] T006 `lib/src/plugins/tdd/services/refactor_receipt_refresh.dart`:
      `RefactorReceiptRefresh.refresh` (+ `refreshBestEffort`) — load
      receipts, intersect changed paths with receipted paths, append ONE
      proof.v1 event via `TddGenerationReceipts.write` with `command:
      'tdd refactor'`, honest re-hashed digests, sanctioned provenance
      input (FR-1, FR-5). No-op when the intersection is empty (FR-4).
- [ ] T007 Wire into `RefactorCommand._run`: after the post-re-proof
      misfire-stop check (sanctioned point), call `refreshBestEffort` with
      the pass-registry-changed `lib/` paths; print the refresh line
      before the summary; extend the refactor evidence `capturedOutput`
      with the refreshed count when it fired (FR-1, FR-5). Keep FR-009's
      summary-line-last contract intact.
- [ ] T008 All B1–B8 green; no pre-existing test regressions in the
      touched areas.

## Phase 3 — VERIFY (non-behavioral wiring)

- [ ] T009 `dart analyze` the changed files; `dart test` the touched test
      files only (cloud disk ceiling — never the full suite).
- [ ] T010 `dart format .` — zero remaining formatting diffs.
- [ ] T011 Record verification evidence (test-first red notes, green
      outputs, mutation/audit notes) in `specs/1311-.../tdd/verification.md`.
- [ ] T012 Commit spec-kit artifacts + fix; PR closes #1311.
