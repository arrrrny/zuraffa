# TDD Test List: 1423-hand-delta-re-receipt

- **Spec ID**: 1423-hand-delta-re-receipt
- Derivation: spec.md SC-1..SC-4 × plan.md contract deltas. Every behavior
  has a failing test BEFORE its implementation task (T3–T6 land after T1
  runs red). Suite:
  `test/plugins/tdd/issue_1423_hand_delta_re_receipt_test.dart`.

## Service tier — HandDeltaReceipts (fast, pure dart:io)

| id | behavior | pins | red on master |
|---|---|---|---|
| S1 | drifted receipted test+subject → fired, ONE appended event: action `update`, digests re-derived from disk, sanctioned+hand_delta+transition markers, feature-scoped; ProofChecker zero `modified` after | SC-2 mechanics | yes (service doesn't exist) |
| S2 | no drift (digests match latest receipts) → fired=false, NO receipt document | hard constraint (idempotence) | yes |
| S3 | unreceipted artifact paths → fired=false, never fabricated provenance | hard constraint | yes |
| S4 | missing file skipped honestly; `deleted` finding stays visible | hard constraint | yes |
| S5 | absolute (legacy) AND project-relative (#1397) recorded forms both normalize | #1397 compat | yes |

## End-to-end tier — CLI against TddFixture (slow, real `dart test`)

| id | behavior | pins | red on master |
|---|---|---|---|
| E1 | hand-implemented subject + `verify-red --re-certify` → hand-delta receipt appended; follow-up make skip clean | SC-2 | yes (cycle-log-only receipt) |
| E2 | hand-written assertions + hand-implemented subject; plain verify-red certifies red (NO hand-delta receipt — red path unchanged); make skip re-receipts the pair; ProofChecker zero `modified` | SC-1 | yes |
| E3 | full hand-delta flow: gen receipts → hand edits → `--re-certify` → make skip → `zfa tdd verify` NOT blocked by the proof preflight (audit phase reached, no `failed the proof preflight`) | SC-3 | yes (NOT_ASSESSED exit 3) |
| E4 | make skip over an UNCHANGED pair appends NO hand-delta receipt (gen receipts still validate) | hard constraint | no (pins the line) |
| E5 | hand-delta drift present → doctor exits non-zero, does NOT print `stores agree`, drift line names behavior+path, prescribes `--re-certify`, never `zfa tdd gen` | SC-4 | yes |
| E6 | after the sanctioned transitions complete → doctor prints `stores agree` again | SC-4 (converse) | no (vacuous pre-fix — converse pin) |

## Red-green protocol

1. Run the E-tier on master ⇒ E1–E3, E5 RED; E4/E6 green (backward-compat
   and converse pins, recorded in `tdd/verification.md`).
2. Implement T3 ⇒ S-tier green. T4 ⇒ E1 green. T5 ⇒ E2 green. T6 ⇒ E5/E6
   green, then E3 green end-to-end.
3. No implementation may make E4 red (the no-op contract is load-bearing).
