# Bug Assessment: tdd run does not treat make=skipped as a terminal success

- **Slug**: 986-tdd-run-make-skipped-misclass
- **Created**: 2026-09-05
- **Source**: https://github.com/arrrrny/zuraffa/issues/986
- **Verdict**: valid
- **Severity**: high

## Report

`zfa tdd run` halts on behaviors whose `make` step reports the issue #694
skip transition (`outcome=skipped`) instead of advancing past them. In the
reporter's feature the run stopped at the second acceptance behavior while
its target test demonstrably passed, and the stop surfaced as the
generation-error family; direct `zfa tdd make <id>` for the same behavior
reported `outcome=skipped` with exit 0 and appended green evidence.

## Symptom

- `[run] A1 make -> skipped` — the first already-green behavior advanced.
- The run then stopped at the next behavior's make; the driver's honest-stop
  line carried a make failure outcome (`outcome=generation-error` in the
  reporter's transcript) and the run ended `result=stopped` with
  `stopped_at=A2:make`, leaving an already-green behavior RED.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart` — `_driveBehavior`'s
  make-outcome handling in the `!result.success` branch: any make result
  that is not graded success falls through to the honest stop unless an
  explicit mapping engages.
- `lib/src/plugins/tdd/services/step_runner.dart` — the make success set
  (`green` / `skipped` / `green-with-failed-build`, exit 0).

## Root Cause

The #693 remediation taught the driver to treat make's already-green report
(`drift`, which exited NON-ZERO under the #657 contract) as a terminal
success: it mapped `drift → green`, recorded the green evidence the drift
path never wrote, advanced the behavior GREEN, and let refactor proceed.
The #694 skip transition then RENAMED the outcome to `skipped` and changed
its contract to exit 0 + green evidence, and StepRunner's make success set
gained `skipped`. But the driver's own mapping was dropped with the old
token: a `skipped` token that arrives through the failure branch — exit
code disagreeing with the token (binary skew, or the #657/#694-era
non-zero already-green contract) — has NO driver-side terminal-success
mapping and falls through to the honest stop. That is the same
mapping-table gap #693 closed for `drift`, re-opened for `skipped` by the
rename: the run halts on an already-green behavior, which the reporter
observed as the generation-error family.

Confidence: **high** (reproduced deterministically at the driver layer —
see RED evidence in tdd/verification.md).

## Proposed Remediation

Driver-layer only (make's skip-transition semantics stay untouched):

- In `_driveBehavior`'s failure branch, recognize `make` +
  `outcome=skipped` as a TERMINAL success regardless of the exit code
  (the outcome token is make's own classification of an already-green
  target): record the green evidence when make's write did not land
  (idempotent, provenance-labeled — the #693 driver-recorded pattern),
  advance the behavior GREEN via `_targetStateFor('make')`, print
  `[run] <id> make -> green (skipped)`, and continue the step window so
  refactor proceeds as usual.

## Open Questions

- None blocking. The reporter's exact child-side transcript (why the
  spawned make reported generation-error instead of skipped in their
  environment) is not reproducible from this repository; the driver-layer
  contract demanded by the issue — skipped is terminal, the run advances —
  is closed by this remediation for every path the driver owns.
