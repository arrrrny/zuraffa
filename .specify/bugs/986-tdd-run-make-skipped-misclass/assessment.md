# Bug Assessment: `zfa tdd run` mis-classifies `make=skipped` as `generation-error`

- **Slug**: 986-tdd-run-make-skipped-misclass
- **Created**: 2026-09-05
- **Source**: https://github.com/arrrrny/zuraffa/issues/986
- **Verdict**: valid — the halt is real; the report's root-cause attribution is imprecise, AND a residual driver-layer gap remained (closed by this remediation)
- **Severity**: high

## Symptom

On a resumed `zfa tdd run` over a feature whose behaviors are already green
(committed passing tests), the first make reports the issue #694 skip
transition and is ACCEPTED (`[run] A1 make -> skipped`), but the next
behavior's make halts the whole run:

```
[run] A1 make -> skipped
[run] A1 refactor -> deferred (phase 2)
[run] A2 make -> generation-error
zfa tdd run: step failed — behavior=A2 step=make outcome=generation-error
run: ... result=stopped ... stopped_at=A2:make
```

Direct `zfa tdd make A2` on the same tree reports `outcome=skipped`, exit 0.

## Root-cause investigation (this repo, commit f1d6e382 ≈ the reporter's
2026-09-03 rebuild; re-checked at HEAD 77e69f24)

1. **The report's stated root cause is disproved by its own output.** The
   driver-layer parser (`StepRunner`, `lib/src/plugins/tdd/services/step_runner.dart`)
   has accepted `outcome=skipped` as a terminal make success since the #694
   remediation (commit d7ec22ed, PR #708): make success = exit 0 AND
   `outcome ∈ {green, skipped}` (plus `green-with-failed-build` since #942).
   The reporter's own transcript proves it: `A1 make -> skipped` was accepted
   and advanced to refactor. A parser that "does not treat skipped as
   terminal" would have halted at A1.

2. **The real halt chain.** `[run] A2 make -> generation-error` means the
   make CHILD honestly printed `make: behavior=A2 outcome=generation-error`
   (the only emitter of that summary is the tdd make command). For that, the
   child's in-run drift check must have FAILED (`alreadyGreen == false`), so
   make entered the generation path: plan → pipeline → terminal `build` step.
   In the reporter's tree (39 pending behaviors' generated stubs on disk, 24
   pre-existing suite failures) the project-wide `build`/analyze step fails,
   and the #737 per-behavior tolerance cannot engage because the #942 gate
   requires the failed build's output to carry NO analyzer errors — which a
   tree full of pending stubs cannot satisfy. Result: an honest
   `generation-error` for a behavior whose own test already passes, and an
   honest FR-007 stop in the driver. The direct invocation succeeds only
   because its drift check passes on that same tree — the drift failure under
   the driver is environmental (in-run transient: fresh kernel compile
   contention or a momentary non-compiling tree), which is why it does not
   reproduce deterministically outside the reporter's machine.

3. **Empirical reproduction in this repo.** A faithful miniature of the
   resumed state (behaviors certified RED with red evidence, subjects
   already implemented so the target tests pass, a third behavior left as a
   red stub for the baseline) was built and driven with the REAL CLI
   (`dart bin/zfa.dart tdd run … --timeout 15`). Result at HEAD:

   ```
   [run] A1 make -> skipped
   [run] A1 refactor -> deferred (phase 2)
   [run] A2 make -> skipped
   [run] A2 refactor -> deferred (phase 2)
   ```

   Both skipped makes accepted, run advances — the parser contract holds at
   HEAD. When the drift check is made to fail in-run (subject compile
   breakage, the forklift shape), the make child reports
   `generation-error` and the driver halts — confirming chain (2).

4. **The regression surface that WAS broken.** `run_command_test.dart`'s
   `bug #691` test — the adjacent "already-green behavior + verify-red
   unexpected-green + make=skipped advances" scenario — was committed
   FAILING (verified in a worktree at its own commit 33241f86) and never ran
   in CI because the suite is tagged `slow`. It over-seeds complete
   red+green evidence, which the bug #682 reconcile legitimately promotes to
   DONE before the drive, so its contract assertions could never pass. The
   issue #986 scenario had NO passing end-to-end regression at the run level.

5. **The residual driver-layer gap (the fall-through this remediation
   closes).** The parser contract being correct for the exit-0 skip does not
   make `skipped` terminal on every driver path. When #694 renamed the
   already-green outcome from `drift` (which exited NON-ZERO under the #657
   contract) to `skipped` (exit 0), the driver's own already-green mapping
   from the #693 remediation (`drift → green` in `_driveBehavior`'s failure
   branch) was dropped with the old token. A `skipped` token that reaches the
   failure branch — exit code disagreeing with the token (binary skew, or the
   #657/#694-era non-zero already-green contract) — has no driver-side
   terminal-success mapping and falls through to the honest stop: the run
   halts on an already-green behavior. Reproduced deterministically (RED
   evidence in tdd/verification.md): `run: feature=090-run-driver
   result=stopped pending=2 red=1 green=0 done=0 stopped_at=B-001:make` with
   the stop line `outcome=skipped`. That is the same mapping-table gap #693
   closed for `drift`, re-opened for `skipped` by the rename — and it is the
   driver-layer defect the issue's hard constraint names.

## Hard constraints (task)

- Fix ONLY the driver-layer parser in `tdd run` to recognize `skipped` as a
  terminal make outcome — including the failure-branch fall-through (5).
- Do not change the skip transition semantics (#694): make keeps producing
  `outcome=skipped` exit 0 with green evidence; nothing in make, verify-red,
  or the reconcile changes.
- One PR for the bug.

## Proposed remediation (implemented)

- `lib/src/plugins/tdd/commands/run_command.dart` (driver-layer only):
  `_driveBehavior`'s failure branch now recognizes `make` +
  `outcome=skipped` as a TERMINAL success regardless of the exit code —
  make's outcome token is the step's own terminal classification of an
  already-green target. The driver records the green evidence when make's
  write did not land (idempotent — never a duplicate — and
  provenance-labeled `bug #986`, the #693 driver-recorded pattern), advances
  the behavior GREEN via `_targetStateFor('make')`, prints
  `[run] <id> make -> green (skipped)`, says so explicitly when the exit
  code disagrees with the token, and continues the step window so refactor
  proceeds as usual (the pre-spawn deferral and the phase-2 pass handle a
  not-yet-green suite as before).
- `test/plugins/tdd/run_command_test.dart`:
  - Repair `bug #691` — seed the honest stuck-red resume state (red evidence
    ONLY; no green evidence seed), so the drive actually reaches
    verify-red → unexpected-green → skip-to-make → make=skipped → refactor
    → done. RED at HEAD (fails as committed), GREEN after the repair.
  - Add `bug 986` — a resume whose makes ALL report the #694 skip
    transition completes the feature (exit 0, every behavior done, phase-2
    refactor pass runs the deferrals) and never prints `generation-error`.
    Mutation-verified: removing `skipped` from the StepRunner make
    terminal-success set turns this test red.
  - Add two `bug #986` driver tests for the failure-branch mapping — make
    reporting `skipped` with a disagreeing exit code advances the behavior
    and completes the feature (RED pre-fix), and an existing green evidence
    entry is never duplicated.
- `.specify/bugs/986-tdd-run-make-skipped-misclass/`: this assessment, the
  verbatim issue, and REAL verification evidence under `tdd/`.
