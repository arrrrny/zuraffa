# Verification: 1423-hand-delta-re-receipt

- **Spec ID**: 1423-hand-delta-re-receipt
- **Date**: 2026-09-13
- **Suite**: `test/plugins/tdd/issue_1423_hand_delta_re_receipt_test.dart`
- **Method**: every result below is from a REAL `dart test` run on this
  machine (Dart SDK 3.13.3, linux/x64). No step is claimed that was not run.

## RED (pre-fix, commit 468a94cd — E-tier only, compiles on master)

Command: `dart test test/plugins/tdd/issue_1423_hand_delta_re_receipt_test.dart --preset=all`

| id | verdict | evidence |
|---|---|---|
| E1 | RED | `Expected an object with length of <1> / Actual []` — `verify-red --re-certify` appended no hand-delta receipt (cycle-log only) |
| E2 | RED | same shape at the make skip transition (`hasLength of <0>`) |
| E3 | RED | `zfa tdd verify: NOT_ASSESSED — the feature's artifacts failed the proof preflight (digest drift before the audit)` — `digest mismatch: receipt says d3ffe51e61b7, disk has 2d969f64c7e0 (action: create); reproduce with: zfa tdd gen A3` — the issue's exact repro |
| E4 | GREEN (pin) | no hand-delta receipt over an unchanged pair (backward compat holds pre-fix) |
| E5 | RED | `a drifted hand-delta must not read healthy: Actual: <0>` — doctor printed `stores agree — no drift detected`, exit 0 |
| E6 | GREEN (pin) | doctor `stores agree` after the transitions (vacuous pre-fix — no proof check existed; converse pin) |

Result: `00:40 +2 -4: Some tests failed.` — E1/E2/E3/E5 red, E4/E6 green,
exactly the test-list prediction.

## GREEN (post-fix)

Command: `dart test test/plugins/tdd/issue_1423_hand_delta_re_receipt_test.dart --preset=all`

`00:58 +11: All tests passed!` — E1–E6 + S1–S5 green:

- **E1 / SC-2**: `verify-red --re-certify` appends ONE proof.v1 event
  (command `tdd verify-red --re-certify`, action `update`, digest re-derived
  from the hand-implemented bytes, `input.sanctioned/hand_delta/transition`
  markers, feature-scoped); gen receipt retained (append-only);
  `ProofChecker` zero `modified` after; follow-up make skips cleanly.
- **E2 / SC-1**: make's skip transition performs the same re-receipt
  (transition `skip`); the plain red-certification path appends NO
  hand-delta receipt.
- **E3 / SC-3**: the full hand-delta flow (gen receipts → hand-edited test +
  subject → `--re-certify` → make skip) reaches `zfa tdd verify`'s mutation
  audit — no `failed the proof preflight` refusal.
- **E4**: skip over an UNCHANGED pair appends nothing (gen receipts still
  validate; `ProofChecker` findings empty).
- **E5 / SC-4**: doctor exits non-zero, never prints `stores agree`, drift
  line names behavior + path + both digests, prescribes
  `zfa tdd verify-red A5 --re-certify`, and the string `zfa tdd gen` does
  not appear anywhere in the output.
- **E6 / SC-4 converse**: after the sanctioned transitions, doctor prints
  `stores agree` again, exit 0.
- **S1–S5**: service contract — one appended event re-hashed from disk,
  idempotent no-op without drift, no fabricated provenance for unreceipted
  paths, vanished files skipped honestly (`deleted` stays visible), legacy
  machine-absolute recorded forms normalize (#1397 compat).

## Static analysis

`dart analyze` over the five changed Dart files: `No issues found!`
(no new warnings; the issue's hard constraint).

## Formatting

`dart format` over the five changed files: 3 reformatted (formatting-only
delta), re-run green afterwards.

## Regression sweep (chunked, disk-safe; kernel cache cleared between chunks)

| batch | files | result |
|---|---|---|
| receipt-preflight | bug_969_proof_receipts, receipt_preflight, tdd_generation_receipt_snapshot, bug_924_verify_preflight, bug_1045_verify_preflight_classification | `+23: All tests passed!` |
| doctor | bug_840_recovery_commands, bug_874_doctor_cross_feature_adoption, bug_969_json_verdict_envelope | `+28: All tests passed!` |
| hand-seam | issue_1323 (seam + driver), issue_1330, issue_1308 (remedy + driver), issue_1482 (preflight ×3) | `+22: All tests passed!` |
| core-commands | bug_828, bug_846, bug_1259, bug_1324, bug_1331, bug_1345, bug_1430 | `+9: All tests passed!` |
| bug_1162 (slow) | bug_1162_bug_subject_green_path + bug_1162_subject_shape | `+17 -1` — the single failure (A-1162e) reproduces IDENTICALLY on stashed pre-fix lib/ (verified); pre-existing environment failure, not a regression |
| make suites (slow) | make_command_test + 1036 + declared_071 + strict_071 | `+41 -4` — the four failures (U-829g, U-829h, SC-004, A15) reproduce IDENTICALLY on stashed pre-fix lib/ (verified); pre-existing environment failures, not regressions |

Gen-time receipts for non-hand-delta flows: unchanged — E4/S2 pin the no-op
line, the receipt-preflight batch (which asserts `tdd gen` receipt contents
and the verify preflight refusals) is fully green, and no gen/preflight/
state-machine source file is touched by this change (delta: one new service,
two receipt-site call sites, one doctor check).
