# Plan — Spec 1324: resume skips green-but-not-done behaviors; stale-artifacts outcome; doctor catches the contradiction

GitHub issue: arrrrny/zuraffa#1324

## Technical Context

Dart 3.13+ CLI (`bin/zfa.dart`, package `zuraffa`). The TDD plugin lives
under `lib/src/plugins/tdd/`. The two surfaces this spec touches:

### 1. `lib/src/plugins/tdd/commands/run_driver_core.dart` (resume window + stop naming)

Current defects, traced:

- `_stepsFor(state, inFlightStep, {hasGenArtifacts})` maps
  `green`/`mocked` to the refactor window (start=3) but the
  `!hasGenArtifacts` demotion resets `start = 0` unconditionally — a
  green-but-not-done behavior with a lost/corrupt/record-less registry
  re-enters at gen and clobbers the certified pair with a fresh
  guard-only test. The same is true when a surviving in-flight marker
  names `gen` for such a behavior.
- `_driveBehavior`'s honest-stop arm prints
  `resume: fix the failing step, then re-run` for
  `make outcome=subject-drift` — it never names the stale-artifacts
  contradiction (fresh test + implemented subject + green evidence) nor
  prescribes the reset loop that actually recovers the feature.

Fix design:

- `drive()` already computes the tombstone-filtered evidence sets
  (`greenEvidence` — the current artifact generation's green evidence)
  and now additionally computes, ONCE per run, the set of behaviors
  whose LAST green evidence entry is backed by its certified test file
  on disk (`- test:` path, `::behaviorId` suffix stripped, absolute or
  project-relative; entries without a `- test:` line are conservatively
  backed — the #1264 legacy tolerance). New private helper
  `_certifiedGreenBacked(evidence, projectRoot)`.
- `_stepsFor` gains two optional parameters
  (`hasGreenEvidence`, `greenTestBacked`). AFTER the existing start
  computation, if the window would begin at gen (`start == 0`) while
  the behavior has backed current-generation green evidence, the window
  resumes at phase 2 instead: `start = 2` (make) for a pending claim —
  the #694 skip / #1331 adoption transitions re-certify honestly — and
  `start = 3` (refactor) otherwise. Every other window is untouched;
  behaviors without green evidence keep the exact old windows (SC-4).
- `_driveBehavior` gains a local `sawUnexpectedGreen` flag (set by the
  existing verify-red `unexpected-green` skip arm) and the
  tombstone-filtered green-evidence set as a parameter. BEFORE the
  generic honest-stop arm, a `make outcome=subject-drift` on a behavior
  with (`sawUnexpectedGreen` OR green evidence) stops with
  `result=stale-artifacts` at `<id>:make` (exit 1), names the
  contradiction, prescribes `--> fix: zfa tdd reset <feature>` with the
  why, and records the failed step's diagnostics via the existing
  `_recordStepFailure` (#1329 discipline: the cycle-log `error` entry
  and the journal error object stay intact).

### 2. `lib/src/plugins/tdd/commands/doctor_command.dart` (stale-artifacts check)

Current defect, traced:

- The doctor never compares the green evidence's `- at:` certification
  time with the registry record's `created_at` for the same behavior
  id. After gen re-ran over a certified pair (the #1324 re-drive
  class), every store looks self-consistent (records own existing
  files, state claims are evidence-backed) → `verdict=healthy`.

Fix design:

- New deterministic check (priority slot after the `2d`
  evidence-without-artifact check, before the import-resolution check):
  for each behavior whose LAST green evidence entry exists, when the
  feature's registry records a `created_at` for the same behavior id
  that is STRICTLY AFTER the green entry's `- at:`, the certification
  predates the current artifact generation → stale-artifacts. Both
  timestamps parse-guarded (`DateTime.tryParse`); a missing/unparseable
  timestamp fails OPEN (never fails what it cannot read — the doctor's
  standing legacy tolerance). Reported per behavior id with both
  timestamps; verdict `stale-artifacts`, prescription `reset`, fix line
  `zfa tdd reset <feature>` with the why (matching the run driver's
  stop). Exit 1. The header priority list is updated.

## Compatibility invariants (checked by the red→green suite)

- A behavior with NO green evidence keeps the exact pre-fix windows
  (pending → gen; red → make; blocked → verify-red; done → skip).
- The `N already done — skipping` banner, the phase-2 make/refactor
  passes, the deferral machinery, and every exit code are unchanged.
- The doctor's existing checks fire in their existing priority for
  every state they handled before; the new check can only turn a
  would-be `healthy` (or a later check) into `stale-artifacts/reset`
  for the new contradiction class.
- No cycle-log, run-state, registry, or verdict-envelope schema
  changes.

## Test strategy

Driver-level suite over the scripted fake zfa binary
(`TddFixture.writeFakeZfa` + `setStepOutcome`), one behavior per SC,
mirroring the issue's repro: corrupt registry (the kill-mid-write
shape), green-but-not-done A1, fresh pending U6. RED first on the
pre-fix tree, then GREEN. Single-file runs only
(`dart test --preset=all test/plugins/tdd/<file>.dart`) — cloud-agent
disk ceiling; the full suite is never run.
