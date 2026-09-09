# Tasks — Spec 1324

Dependency-ordered, MVP-first. Behavioral tasks (B*) carry the TDD
red→green loop; the implementation tasks (T*) are the non-behavioral
scaffolding the behaviors drive out.

## Group 1 — Resume skips green-but-not-done behaviors (SC-1)

- [ ] B1. (behavior) Resume never re-drives gen for a green-but-not-done
  behavior whose registry record is lost (corrupt `artifacts.json`, the
  kill-mid-write shape): with A1 green-but-not-done (green+red evidence,
  certified test file on disk, run-state `green`) and U6 fresh-pending,
  the resume drives A1 at phase 2 (refactor) and the full U6 cycle, and
  reaches `result=complete`; the step log contains NO `gen A1`.
- [ ] T1. `run_driver_core.dart`: `_certifiedGreenBacked(evidence,
  projectRoot)` — the once-per-run set of behaviors whose last green
  evidence entry is backed by its certified test file (the `- test:`
  path convention; entries without a test line fail open).
- [ ] T2. `run_driver_core.dart`: `_stepsFor` gains
  `hasGreenEvidence`/`greenTestBacked` and demotes a gen-starting window
  to phase 2 (make for pending claims, refactor otherwise) only when
  both hold; all other windows byte-identical.

## Group 2 — The stale-artifacts outcome (SC-2)

- [ ] B2. (behavior) A make `subject-drift` on a behavior that carries
  green evidence stops with `result=stale-artifacts` at `<id>:make`
  (exit 1), names the contradiction (fresh test + implemented subject +
  green evidence), prescribes `--> fix: zfa tdd reset <feature>` with
  the why, and the generic "fix the failing step" hint is gone; the
  cycle-log records the failed step's diagnostics (outcome
  `subject-drift`).
- [ ] B3. (behavior) The same-drive sequence — verify-red
  `unexpected-green` (skipped, already green) followed by make
  `subject-drift` — names `stale-artifacts` too (the
  `sawUnexpectedGreen` arm).
- [ ] T3. `run_driver_core.dart`: `_driveBehavior` gains the
  `sawUnexpectedGreen` flag and the green-evidence set; the new stop arm
  sits before the generic honest stop, records diagnostics via
  `_recordStepFailure`, and preserves the exit-code contract (exit 1).

## Group 3 — Doctor catches the contradiction (SC-3)

- [ ] B4. (behavior) `zfa tdd doctor` on the stale-artifacts state (green
  evidence certified BEFORE the registry record's `created_at` for the
  same behavior id, files present, claims evidence-backed) reports the
  drift by behavior id with both timestamps, `verdict=stale-artifacts`,
  `prescription=reset`, the `zfa tdd reset` fix line, exit 1 — never
  `verdict=healthy`.
- [ ] B5. (behavior) Guards: (a) a registry record created BEFORE the
  green certification stays healthy; (b) legacy entries without a
  parseable `- at:` fail open (healthy, no false positive); (c) the
  evidence-without-artifact check keeps its priority (a missing
  certified test file still prescribes resume, not reset).
- [ ] T4. `doctor_command.dart`: the deterministic stale-artifacts check
  (both timestamps `DateTime.tryParse`-guarded, fail-open) slotted after
  the evidence-without-artifact check; header priority list updated.

## Group 4 — Backward compatibility (SC-4)

- [ ] B6. (behavior) A truly red (never green) behavior still resumes
  from gen: a fresh pending U6 with no evidence and no record drives the
  full cycle (gen → verify-red → make → refactor) to
  `result=complete`; the step log contains `gen U6`.
- [ ] B7. (behavior) A feature with no green evidence anywhere is
  unaffected end-to-end: the driver's windows, the summary line shape,
  and the doctor's healthy verdict for a clean feature are unchanged.

## Group 5 — Verification

- [ ] V1. `dart analyze` the changed files (zero issues); `dart format .`
  zero diff; single-file test runs only (cloud-agent disk ceiling) with
  pre/post kernel-cache cleanup.
- [ ] V2. `tdd/verification.md` records the actual RED and GREEN run
  results (pass/fail counts per file) and the interrupted-run resume
  demonstration for the PR.
