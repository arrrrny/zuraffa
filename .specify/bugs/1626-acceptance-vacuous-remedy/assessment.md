# Bug Assessment: acceptance vacuous-green refusal prescribes the FR-traces remedy, which cannot produce a real acceptance assertion

- **Slug**: 1626-acceptance-vacuous-remedy
- **Created**: 2026-09-14T00:00:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1626
- **Verdict**: valid (reproduced by inspection + the measured loop in the issue; root cause confirmed in source)
- **Severity**: high (workflow dead-end: every fresh spec's first acceptance behavior stops with an unprovable remedy)

## Report (summarized)

On a fresh CORE spec, `zfa tdd run` stops at the first acceptance behavior with a
`vacuous-green` refusal (the #1488 gate, working as designed) — but the remedy it
prints (add `traces:` → re-plan → re-gen) cannot make an acceptance test
non-vacuous, because the acceptance lane deliberately ignores the contract shape
(#1512). Following the printed remedy loops forever; the path that actually works
(hand-write the outcome assertion outside the capture + implement the scenario
runner + attestation header + `zfa tdd make <id> --born-green`) is never named.
Issue: https://github.com/arrrrny/zuraffa/issues/1626

## Symptom

`zfa tdd make` (and the run driver's make-vacuous-green stop) refuses an
acceptance row with the traces/re-plan/re-gen remedy. Following it exactly
(edit the traces cell, re-plan, re-gen) regenerates a test that is STILL
guard-only — the acceptance lane ignores the contract-derived shape by design —
so the same refusal fires again: an infinite loop.

## Reproduction

1. Fresh spec with an acceptance behavior (e.g. `zfa tdd run calculator`).
2. `A1 verify-red -> certified`, then `A1 make -> vacuous-green`.
3. The refusal prints: `--> fix: add traces: <ContractRow> to the FR, re-run zfa
   tdd plan, re-run zfa tdd gen, re-run zfa tdd run — or hand-edit the lane plan
   (...) traces cell to FR-00N, Row.method and re-run zfa tdd gen`.
4. Follow it exactly: `zfa tdd gen A1` regenerates the test with the trace in
   the group label but the assertion set stays the UnimplementedError guard
   (`kind=acceptance`, `zfa:tdd: acceptance-guard` fallback shape, #1512).
5. `zfa tdd make A1` refuses again with the SAME remedy — loop.

## Suspected Code Paths (confirmed)

- `lib/src/plugins/tdd/commands/make_command.dart` step 3c (~L1142): the
  vacuous-green refusal branches unit-vs-acceptance, but the acceptance branch
  prescribes `vacuousGuardFallbackRemedyFor(...)` — the traces/re-plan/re-gen
  wording.
- `lib/src/plugins/tdd/commands/run_driver_core.dart` make-`vacuous-green` arm
  (~L2466): marker-present → the traced `:hand` seam (correct); marker-absent →
  `_vacuousFallbackRemedy` (the traces wording) for ALL rows, including
  acceptance rows.
- `lib/src/plugins/tdd/services/vacuous_guard.dart`: `vacuousGuardFallbackRemedyFor`
  is the shared wording source; `acceptanceFallbackGuardToken`
  (`zfa:tdd: acceptance-guard`) marks the acceptance fallback shape.
- NOT affected: the gen-time guard-only warning (`behavior_test_writer.dart`
  ~L221) is gated on `BehaviorKind.unit` — acceptance rows never get it.

## Root Cause Hypothesis (confirmed)

The #1626 gap is a wording bug, not a gate bug: the two refusal surfaces borrow
the FALLBACK-routed remedy (traces/re-plan/re-gen) for acceptance rows, but the
acceptance lane cannot consume a contract-derived shape (#1512: "the
contract-derived shape rides ONLY the plain-function pair (unit lane)") — so the
prescribed remedy is unexpressible there. The correct path is the designed hand
step (#1411): one non-guard `expect` outside the capture flips
`contentIsVacuousGreen`, the scenario runner is implemented in the subject, the
`<id>:hand` attestation header is added, and `zfa tdd make <id> --born-green`
certifies the hand transition. That path is already documented in the repo's own
fixture (`test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart`, helper
`outcomeAssertedAcceptanceTest`) — the runtime messages just never adopted it.

## Proposed Remediation

Refusal wording only (no gate, no lane, no hand-step-mechanics change):

1. Add a shared wording builder to `vacuous_guard.dart`:
   `acceptanceVacuousHandStepRemedyFor({behaviorId, testPath, subjectPath})` —
   names the hand step: write an assertion on the observable outcome OUTSIDE the
   capture in `<test path>` (the guard-only test is the RED surface), implement
   the scenario runner in `<subject path>`, add the attestation header
   (`handStepHeader(id)`), then run `zfa tdd make <id> --born-green`; states WHY
   (the acceptance lane ignores the contract shape, #1512 — traces/re-plan/re-gen
   cannot produce a real acceptance assertion).
2. `make_command.dart` step 3c: the acceptance branch renders the new remedy
   (test path + subject path from the registry record, project-relative posix).
3. `run_driver_core.dart` make-vacuous-green marker-absent arm: when
   `row.kind == BehaviorKind.acceptance`, print the acceptance explanation + the
   new remedy (paths via `_existingGeneratedTestPath` + the artifact registry,
   conventional-layout fallbacks); unit/fallback rows keep
   `_vacuousFallbackRemedy` unchanged. `stopped_at=<id>:make` preserved for
   acceptance (the honest fallback-routed class, #1512).
4. Update the two pins in `bug_1488_acceptance_vacuous_green_test.dart` (A1/A4)
   that lock the OLD (looping) acceptance wording; all unit-lane pins
   (#1483/#1308/#1518 suites) stay untouched.

## Risks & Considerations

- Messaging-only change, but the acceptance wording is user-facing contract:
  the #1488/#1512 pin suites must be re-pointed deliberately, not silently.
- The run driver stop class stays `stopped_at=<id>:make` for acceptance rows —
  machine contract unchanged (the #1512 classification docs require it).
- Kindless/legacy rows fail open exactly as before (no kind → no refusal; the
  run driver's marker-based classification is untouched).

## Open Questions

- None — the issue names the measured working path and the fixtures confirm it.
