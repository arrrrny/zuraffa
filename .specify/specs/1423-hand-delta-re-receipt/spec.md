# 1423-hand-delta-re-receipt

- **Spec ID**: 1423-hand-delta-re-receipt
- **Created**: 2026-09-13
- **Source**: GitHub issue #1423 (SPEC 1423 — PROOF PREFLIGHT REFUSES DESIGNED HAND-DELTA)
- **Type**: bug (P1 — `zfa tdd verify` unreachable for hand-delta'd features; prescribed remedy destroys certified work)
- **Branch**: feat/1423-hand-delta-re-receipt-path
- **Related**: #1308 (hand-delta seam), #1162 (re-certification), #1375 (gen --adopt destructive remedy), #1311 (sanctioned refactor receipt — the pattern)

## Problem

Gen receipts record the test/subject file digests at gen time only. The
designed hand-delta protocol (`zfa tdd run` stops at `<id>:hand` → the agent
hand-writes assertions in the generated test and hand-implements the subject →
`verify-red --re-certify` + make skip close the cycle) mutates those files
AFTER the gen receipt was written, and NO later verb re-receipts them:

- `zfa tdd verify-red --re-certify` appends green evidence and receipts ONLY
  `tdd/cycle-log.md` (`verify_red_command.dart`, the issue #1162 transition).
- `zfa tdd make`'s skip transition appends green evidence and receipts ONLY
  `tdd/cycle-log.md` (`make_command.dart`, the issue #694 transition).

`ProofChecker` applies latest-wins per artifact path, so the latest receipt
for every hand-edited test/subject file remains the pre-hand-delta gen bytes.
`zfa tdd verify`'s proof preflight then refuses the feature:

```
digest mismatch: receipt says c4df44b3dd5, disk has 0c8825e43b92 (action: create)
```

→ NOT_ASSESSED, exit 3. Verify is UNREACHABLE for hand-delta'd features. The
prescribed fix (`zfa tdd gen`) regenerates the guard test and DESTROYS the
hand-delta (the #1375 destructive-remedy class).

Meanwhile `zfa tdd doctor` reports `stores agree — no drift detected` for
exactly this state: the run-state claims are backed by cycle-log evidence,
so the store-vs-store comparison passes while the proof layer is red.

## Goal

The sanctioned hand-delta certification transitions re-receipt the touched
test/subject files with the CURRENT digest (action `update`), so the proof
preflight validates the certified hand-delta instead of demanding its
destruction — exactly what the refactor pass already does for reformatted
subjects (issue #1311, `RefactorReceiptRefresh`).

## Success criteria (measurable)

- **SC-1**: Make's skip transition appends one proof.v1 receipt covering the
  behavior's receipted test/subject paths whose current disk digest differs
  from the latest recorded digest — action `update`, digest re-derived from
  disk (never copied), feature-scoped via `input.feature`, `input.sanctioned`
  and `input.hand_delta` markers, `input.transition == 'skip'`. After the
  skip, `ProofChecker.check()` reports zero `modified` findings for the pair.
- **SC-2**: `zfa tdd verify-red <id> --re-certify` performs the same
  re-receipt (action `update`, current digest, `input.transition ==
  're-certify'`, command `tdd verify-red --re-certify`) for the behavior's
  drifted receipted test/subject paths, appended after the green evidence.
- **SC-3**: The end-to-end hand-delta flow becomes verifiable: gen receipts →
  hand-edit test + subject → `verify-red --re-certify` → make skip →
  `zfa tdd verify --feature <f>` is NOT blocked by the proof preflight (no
  `failed the proof preflight` refusal; the mutation audit phase runs).
- **SC-4**: `zfa tdd doctor <feature>` does NOT report `stores agree` when
  hand-delta drift exists (a registry-recorded test/subject path whose disk
  digest differs from its latest receipt digest): it exits non-zero with a
  `hand-delta drift` line naming the behavior and path, prescribes the
  sanctioned re-receipt transition — never `zfa tdd gen` (destructive,
  #1375). After the sanctioned transitions complete, doctor reports
  `stores agree` again.

## Hard constraints

- Fix ONLY the re-receipt path for hand-delta'd files. Do NOT change gen
  receipts, proof preflight logic (`ReceiptPreflight`,
  `_proofPreflightDrift`, `ProofChecker`), or the state machine.
- Must not break gen-time receipts for non-hand-delta flows.
- The re-receipt is APPEND-ONLY: the original gen receipts stay on disk;
  latest-wins resolves the certified state. No receipt is ever fabricated
  for an unreceipted path, and a missing file is skipped honestly (the
  `deleted` finding stays visible).
- Must pass `dart analyze` with no new warnings.

## Out of scope

- Plain `verify-red` red certification receipts (the red path is unchanged).
- `ProofChecker.appendOnlyBasenames`, the sanctioned-append class (#1327).
- The `adopted` (#1331) and `adopted-placeholder` (#1345) make outcomes.
- Gen `--adopt` semantics (#1375), the ownership preflight, mutation audit.
