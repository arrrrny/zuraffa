# Bug Assessment: `zfa tdd doctor` does not detect receipt digest drift

- **Slug**: tdd-doctor-receipt-digest-drift
- **Created**: 2026-10-22
- **Source**: https://github.com/arrrrny/zuraffa/issues/1978 (host `github.com` — allowlisted; read via `gh issue view`, not an HTTP fetch)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Issue #1978 (open, filed by arrrrny, labeled `bug` + `tdd`):

> `zfa tdd doctor <feature>` reports a healthy feature while `zfa tdd verify
> --feature <feature>` fails its receipt preflight with dozens of digest
> mismatches. The two commands disagree about the same state.
>
> ```
> $ zfa tdd doctor 002-subscription-error-vocabulary --repair
> zfa tdd doctor: feature 002-subscription-error-vocabulary (specs/002-subscription-error-vocabulary/tdd)
>   stores agree — no drift detected
> {"command":"doctor","feature":"002-subscription-error-vocabulary","verdict":"healthy","prescription":"none","drifts":[]}
>
> $ zfa tdd verify --feature 002-subscription-error-vocabulary
> zfa tdd verify: receipt preflight — FAIL
>    receipts checked: 386, findings: 74
>    [modified] test/tdd/001-purchase-store/u1_test.dart — digest mismatch: receipt says 3989017dae5c, disk has fbf3fab4334b (action: update); reproduce with: zfa tdd verify-red U1 --re-certify
> ```
>
> **Ask**: make `zfa tdd doctor` run the same receipt-digest check `zfa tdd
> verify`'s preflight runs, and report it as a drift with the per-file
> prescription (`verify-red --re-certify` / `make --born-green`).

## Symptom

`zfa tdd doctor` compares the TDD stores against each other (spec ↔ artifacts
↔ ledger) and never re-derives a receipt's recorded digest against the bytes
on disk, so a feature whose receipts drifted prints `stores agree — no drift
detected` and exits 0 (`verdict: healthy`). `zfa tdd verify` runs the receipt
preflight (spec 0996) before its mutation audit, re-derives every receipted
artifact's digest, and refuses the feature with `receipt preflight — FAIL`.
Expected: the two commands agree about one state — a feature whose receipts
have drifted is not healthy, and the doctor names the file and the transition
that repairs it.

## Reproduction

1. In a project that ships proof receipts (`<project>/.zfa/receipts/`), let a
   receipted artifact's bytes change after the receipt was written (e.g. the
   release reformatted the generated lane).
2. `zfa tdd doctor <feature> --project <root>` → `stores agree — no drift
   detected`, exit 0, verdict `healthy`.
3. `zfa tdd verify --feature <feature> --project <root>` → `receipt preflight
   — FAIL`, `receipts checked: N, findings: M`, one `[modified] <path> —
   digest mismatch: receipt says …, disk has … (action: update); reproduce
   with: <repro>` per drifted file.

Reproduced in-repo (the regression test of this fix, on the pre-fix tree):
the doctor printed `stores agree — no drift detected` while `ReceiptPreflight`
on the same fixture reported a `modified` finding for the same file.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/doctor_command.dart` — the doctor's checks:
  legacy-layout ownership, registry-vs-disk, path-form, import resolution,
  stale-artifacts, hand-delta proof drift (`_handDeltaProofDrifts`, spec
  1423), evidence hash chain. None of them re-derives a receipt digest for an
  artifact outside the queried feature's registry records.
- `lib/src/plugins/tdd/services/receipt_preflight.dart` — the gate
  `zfa tdd verify` runs: `ProofChecker.check()` over EVERY receipt in
  `.zfa/receipts/` (digest drift) plus the audited-subject coverage check.
- `lib/src/core/proof/proof_checker.dart` — the digest re-derivation both
  gates share (`kindModified` findings, the latest-wins receipt resolution,
  the sanctioned-append exemption for `cycle-log.md`).

## Root Cause Hypothesis

`zfa tdd doctor` and `zfa tdd verify` answer "is this state healthy?" from two
different check sets. The doctor's checks are store-vs-store (plus the
feature-scoped hand-delta digest check of spec 1423, which only looks at the
paths the queried feature's registry records). The verify receipt preflight
re-derives the digest of EVERY receipted artifact in the project. The
receipt-digest class therefore has no doctor counterpart, so a feature reads
`healthy` while the release gate refuses it — the two commands disagree about
the same state (issue #1978). Confidence: high (reproduced in-repo).

## Proposed Remediation

**Preferred**: give the doctor the check the preflight runs. After the
existing checks, `zfa tdd doctor` re-derives every receipted artifact's
digest through the shared `ProofChecker` (the very class the receipt
preflight validates) and reports each drifted file as a drift line naming the
file, the recorded and the current digest, the receipt's owning feature, and
the transition that re-binds the receipt to the current bytes. The fix line
lists the per-file prescriptions (the receipt's own reproduction command:
`zfa tdd verify-red <id> --re-certify`, `zfa tdd make contract:<id>
--born-green`). The destructive generator re-drive (`zfa tdd gen`, issue
#1375) is never prescribed — a `gen` receipt's repro is replaced by the
sanctioned re-certification transition, picked by the artifact's KIND
(a generator receipt owns the test AND the subject of a behavior: the red
re-certification for the test, the born-green hand transition for the
subject).

**Alternatives** (optional):
- Scope the check to the queried feature's own receipts (`input.feature`) —
  smaller blast radius, but doctor and verify would still disagree whenever
  the preflight's project-wide gate refuses the feature.
- Reuse the preflight service wholesale — adds the `missing_receipt`
  coverage class (feature-scoped, about the audit scope) the issue does not
  ask for.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/doctor_command.dart`
- `test/plugins/tdd/issue_1978_doctor_receipt_digest_drift_test.dart`

**Tests to add or update**:
- the drifted receipted artifact is reported by `zfa tdd doctor` (never
  `stores agree`), the drift line names the file and the per-file
  prescription;
- the doctor's finding is the same check the receipt preflight runs;
- the destructive generator re-drive is never prescribed;
- the drifted SUBJECT of a generator receipt is re-bound with the born-green
  transition, the drifted TEST with the red re-certification;
- a receipt whose digest still matches the bytes on disk leaves the feature
  healthy.

## Risks & Considerations

- The doctor now exits non-zero for a project whose ANY feature's receipts
  drifted — that is the preflight's own scope (the gate refuses the audit for
  the same reason), but the drift lines name the owning feature so the
  operator can tell whose artifact drifted.
- The check reads every receipted artifact (the preflight's cost); the
  doctor stays read-only.
- The `cycle-log.md` append-only exemption of the shared `ProofChecker`
  applies, so the append-only cycle-log receipts do not false-positive.

## Open Questions

- None — the issue's ask is unambiguous: run the preflight's receipt-digest
  check in the doctor and report it as a drift with the per-file
  prescription.
