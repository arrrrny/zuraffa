# Spec 1324 — fix: run resume skips green-but-not-done behaviors; stale-artifacts outcome named; doctor catches the contradiction

GitHub issue: arrrrny/zuraffa#1324 (severity high — an interrupted run
wedges the feature on every resume; companion to #1323)

## Problem

When `zfa tdd run` stops after a behavior's make went GREEN but before
the journal ladder reached DONE (e.g. the #1323 U6 dead-end after
U1–U5 + A1–A12 were already green), the NEXT resume does not skip or
cleanly re-drive those green-but-not-done behaviors. Observed sequence:

1. A1–A12 + U1–U5 makes are `green` in cycle-log.md (green evidence
   appended); refactor/compose deferred to phase 2; journal NOT done.
2. The run later stops (the #1323 generation-error, a killed driver, a
   lost/corrupt `tdd/artifacts.json` — the registry append is a
   non-atomic read-modify-write).
3. On resume, the driver reports `N already done — skipping` (only the
   DONE behaviors), then re-drives A1 from `gen`: gen writes a FRESH
   guard-only test over the existing pair.
4. `verify-red` on the fresh guard-only test against the
   already-implemented subject → `unexpected-green` (the bare guard
   passes against anything that does not throw UnimplementedError).
5. `make` → `subject-drift` (the subject no longer matches the
   certified shape because it IS the implementation) — the run stops;
   the feature is wedged: re-driving clobbers, making refuses.

`zfa tdd doctor` reports `verdict=healthy, prescription=none` for
exactly this wedged state — doctor's drift detection and the run
driver's resume logic disagree about what healthy means.

Workaround today: `zfa tdd reset <feature>` + one uninterrupted
`zfa tdd run <feature>`, re-applying any test-side hand-deltas.

## Root cause (traced)

- `run_driver_core.dart` `_stepsFor()` maps `BehaviorState.green` to
  the refactor window (start=3) but then demotes ANY behavior whose
  registry record is missing (`!hasGenArtifacts`) back to
  `start = 0` — the full cycle from gen. A green-but-not-done behavior
  reconciles to `green` (evidence beats state, FR-003), so a lost,
  corrupt (FormatException → `[]`), or record-less registry sends it
  back through gen. The write-ahead journal replay re-drives gen the
  same way (`_stepEvidenceLanded` default arm: "gen re-drives").
- The driver's failure path treats `make outcome=subject-drift` as a
  generic honest stop ("resume: fix the failing step") — it does not
  name the detectable contradiction (fresh test + certified green
  evidence + implemented subject) or prescribe the only recovery that
  works (reset).
- `doctor_command.dart` compares stores against each other and the
  tree, but never compares the green evidence's certification time
  against the registry record's `created_at` for the same behavior id —
  a freshly regenerated pair with a stale certification reads healthy.

## Acceptance criteria

- **SC-1 (resume skips green-but-not-done).** Resume must not `gen`
  over a pair whose cycle-log already carries green evidence for the
  current artifact generation (tombstone-filtered; the certified test
  file is backed on disk). Such behaviors resume at the phase-2 steps
  (make for a pending claim — the #694 skip / #1331 adoption
  transitions re-certify; refactor for a green/mocked claim), never at
  gen. The `N already done — skipping` announcement is unchanged.
- **SC-2 (stale-artifacts outcome named).** `verify-red
  unexpected-green` followed by `make subject-drift` — or a
  subject-drift on a behavior that carries green evidence — is a
  detectable contradiction (fresh test + implemented subject): the run
  names it (`result=stale-artifacts`, stopped at `<id>:make`, exit 1)
  and prescribes `zfa tdd reset <feature>` with the reason, instead of
  the generic "fix the failing step". The failed step's diagnostics are
  still recorded (the #1329 discipline).
- **SC-3 (doctor detects the contradiction).** `zfa tdd doctor` detects
  the stale-artifacts contradiction (green cycle-log evidence certified
  BEFORE the registry's current artifact generation for the same
  behavior id), reports `verdict=stale-artifacts` (never healthy) with
  `prescription=reset` and the same `--> fix: zfa tdd reset <feature>`
  the run driver's stop prescribes. Legacy hashless/timestamp-less
  entries fail open (reported, never failed — the doctor's standing
  tolerance).
- **SC-4 (backward compatibility).** Truly red (never green) behaviors
  still resume from gen exactly as before; features with no green
  evidence are unaffected; the doctor's existing checks (migrate /
  adopt / reset / resume) and their priority order are unchanged for
  every state they already handled.

## Out of scope (hard constraints)

- The core engine cycle, the gen pipeline, the make pipeline, the
  verify gate, and the cycle-log format are NOT touched. The registry's
  non-atomic append is noted as the likely trigger but is NOT changed
  by this spec (one issue, one PR).
- No new CLI commands; no cycle-log schema change; no run-state schema
  change.

## Measurement

Per-behavior, from the driver's step invocation log (fake zfa) and the
summary line; per-feature, from the doctor's stdout + verdict JSON.

## Implementation note

The green-evidence set the driver already computes is
tombstone-filtered (`JournalReader.tombstonedBehaviors` subtracted) —
that set IS the "current artifact generation" green evidence. The
certified-test-file backing check reuses the cycle-log `- test:` path
convention (`path::behaviorId` suffix stripped; entries without a
`- test:` line are conservatively backed — the #1264 legacy tolerance).
