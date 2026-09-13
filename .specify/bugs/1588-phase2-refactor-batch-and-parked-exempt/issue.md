# Issue #1588 — Phase-2 refactor pass runs full-suite preflight + build per behavior; skips all when any parked

## Symptom

`zfa tdd run` phase-2b (the refactor pass) spawns `zfa tdd refactor <id>` once
per green behavior. Every spawn re-runs the whole refactor pipeline
independently:

1. full-suite preflight (`refactor_command.dart` step 3),
2. whole-project pass registry — resolved `zfa build`, `dart format lib/`,
   `dart fix --apply lib/` (step 5),
3. re-proof — a FULL suite when the passes changed nothing (step 7).

Measured on the calculator corpus (10 behaviors): A1 refactor = 127.4s
(preflight + build + format/fix + re-proof); A2, U1-U4 each paid ~32-44s of
preflight + "not-green -> skipped" = ~2.7 minutes for zero passes applied.

## Two distinct problems

### 1. Economics (per-behavior full pipeline)

Phase 1 already did per-behavior builds inside make. #741 fixed the same
economics for make/verify-red with the once-per-run suite baseline; the
phase-2 refactor pass was never included. The Nth green behavior's refactor
re-pays preflight + build + format/fix + re-proof even though the (N-1)th
invocation just proved the identical tree state.

### 2. Coupling (parked behaviors poison the gate)

A parked BLOCKED contract behavior's test is red on disk (verify-red
certified the unsatisfied contract; make never spawns). The run baseline
(#741) is captured BEFORE phase 1 (step 6b) — on a fresh feature the parked
behavior's test file does not exist yet at baseline time, so at phase-2b its
failure counts as a NEW failure vs the baseline (#922 diff). Every refactor
preflight refuses (`not-green`), every green behavior's refactor is skipped,
zero passes apply.

## Measurable success criteria

1. Batch the pass registry per feature — one suite preflight for the batch;
   re-proof stays scoped (spec 069 T001 covering tests).
2. Parked/blocked behaviors are exempt from the refactor gate — their
   registered tests are excluded from the preflight/re-proof failing sets
   (the #922 "no NEW failures" economics, extended to parked tests that the
   baseline cannot know about).
3. No refactor applied = no wasted preflight/build time on that behavior.

## Hard constraints

- Fix ONLY the phase-2 refactor loop and the pass registry. Do NOT change
  the make step, the state machine (RunState/BehaviorState), or the suite
  runner (SingleTestRunner).
- `dart analyze` with no new warnings.
- A flag-less standalone `zfa tdd refactor` keeps the absolute-green
  contract (spec 048 FR-001) — the batch/exemption economics apply only
  when the driving run opts in.
