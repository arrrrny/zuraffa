# Plan — Spec 1345: reset→rerun acceptance placeholder deadlock (compose re-entry)

GitHub issue: arrrrny/zuraffa#1345 · companion to #1331 (adoption) /
#1338 (reset deletes all owned files) / #1036 (placeholder guard)

## Technical Context

The TDD loop drives each behavior through `gen → verify-red → make →
refactor` (`StepRunner.stepOrder`). `make`'s drift check (FR-003) re-runs
the target test before generation; an already-green target engages the
re-drive/skip block in
`lib/src/plugins/tdd/commands/make_command.dart`:

- `_tombstonedReDrive(featureDir, record)` — true when the feature's last
  reset tombstone (`.tdd/journal.json` `phase: reset`) names the behavior
  AND its surviving green evidence predates the tombstone (fail-closed on
  unparseable timestamps). #1331.
- `_subjectIsBornGreenPlaceholderOnDisk(cwd, record)` — the #1036 shape
  predicate over the subject file (`subjectIsBornGreenPlaceholder` in
  `lib/src/plugins/tdd/services/subject_shape.dart`): the scaffolded
  marker, a still-throwing `UnimplementedError` stub, or all-vacuous func
  bodies. Unreadable files fail CLOSED (placeholder).
- `adoptable = reDrive && !placeholder` — the #1331 `adopted` outcome.

The deadlock (#1345): on a re-drive of an acceptance-lane behavior, the
subject on disk IS the born-green placeholder — the exact bytes `zfa tdd
gen` emits (the compose pipeline's input skeleton; #1338's reset deleted
all owned files, gen re-emitted the stub, and the acceptance test is
green-by-construction against the pipeline's own placeholder state). So
`adoptable` is false and the #1036 subject-drift refusal stands. Neither
remediation fits alone:

- adoption would certify green on a vacuous subject — the greenwash #1036
  exists to prevent;
- the refusal dead-ends the documented `reset → doctor → run` recovery
  loop — doctor prescribes `resume`, run dead-ends at `<id>:make`
  subject-drift again.

The intersection has no path. The sanctioned re-entry exists: the make
generation path for acceptance rows ALREADY re-enters the pipeline at
compose/make phase-2 (the #642/#052 composition fallback: `zfa tdd compose
<id>` → `build`, where compose re-implements the stub against the
feature's green unit anchors and is idempotent — `already-composed` — for
a surviving composed product). The fix routes the placeholder re-drive
class into that existing path instead of the refusal, and records the
re-entry with its own terminal outcome token.

## Surfaces Touched

| File | Change |
|---|---|
| `lib/src/plugins/tdd/models/generation_plan.dart` | New `MakeOutcome.adoptedPlaceholder('adopted-placeholder')` — exit 0, green entry appended; distinguishable from `green`/`skipped`/`adopted`. |
| `lib/src/plugins/tdd/commands/make_command.dart` | In the already-green re-drive block: when `reDrive && placeholderOnDisk && rowKind == acceptance`, do NOT refuse — fall through to generation planning (the composition fallback re-enters compose → build) and report `adopted-placeholder`. |
| `lib/src/plugins/tdd/services/step_runner.dart` | Grade `adopted-placeholder` (exit 0) as a terminal make success, same list as `green`/`skipped`/`green-with-failed-build`/`adopted`. |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | The bug #986 fall-through (exit-code/token disagreement → backfill green evidence, advance green) covers `adopted-placeholder`. |
| `lib/src/plugins/tdd/commands/doctor_command.dart` | The `evidence-without-artifact` prescription names the placeholder re-entry (`adopted-placeholder`, #1345) alongside the #1331 adoption. |

## Class Predicate (fail-closed)

The compose re-entry engages only when ALL hold:

1. the target test passed the drift check (already-green);
2. `_tombstonedReDrive` is true — the last reset tombstone names the
   behavior and its surviving green evidence predates it (unparseable
   timestamps fail closed, unchanged);
3. `_subjectIsBornGreenPlaceholderOnDisk` is true — the subject is a
   born-green placeholder shape (a hand-implemented subject keeps the
   #1331 `adopted` path);
4. the test-list row is acceptance-kind (`_rowKind`) — the lane whose
   make pipeline IS compose. Unit/widget/contract rows keep the #1036
   refusal (a func-scaffold/unit re-entry would re-emit a placeholder and
   greenwash — out of scope per the issue's backward-compatibility
   criterion).

Anything else keeps the existing refusal/skip behavior byte-for-byte.

## Why the Re-Entry Cannot Greenwash

The re-entry is NOT an adoption: the make does not certify the vacuous
pass. It runs the SAME generation path a first drive runs — baseline →
plan → composition fallback (`compose` → `build`) → post-run target test →
suite guard → green evidence. Two honest failure modes survive intact:

- zero composable green anchors → the fallback disengages → the honest
  `unexpressible` stop (FR-009) → the run driver defers to phase 2;
- the pipeline or guard fails → the honest failure outcome (the #1036
  failed-make subject-restore contract is untouched).

The appended green entry binds the CURRENT post-re-entry subject hash and
records the compose/build generation steps, so the certification reflects
what the pipeline actually produced.

## Trade-offs Considered

- **Alternative A (gen emits the throwing stub on re-drive so the red
  ceremony re-certifies):** rejected — gen ALREADY emits the stub; the
  green-by-construction acceptance test is green against the stub itself,
  so no red ceremony is reachable without changing the acceptance test
  writer (the core engine cycle — forbidden by the scope fence).
- **Alternative B (widen `adoptable` to include placeholders):** rejected
  — certifies green on a vacuous subject with zero pipeline work; the
  exact #1036 greenwash.
- **Chosen (compose re-entry, `adopted-placeholder`):** reuses the
  sanctioned #642 phase-2 surface, records an honest, distinguishable
  outcome, and leaves every guard class outside the intersection intact.

## Verification Strategy

- B1/B2 (real subprocesses, throwaway fixture projects): the tombstoned
  acceptance placeholder re-drive make exits 0 with
  `outcome=adopted-placeholder`; the appended green entry carries the
  current subject hash and the compose generation step.
- B3 (fake zfa driver): `outcome=adopted-placeholder` is a terminal make
  success — the run completes (`result=complete`).
- B4: doctor's fix line names `adopted-placeholder` / issue #1345;
  prescription `resume`.
- B5/B6: non-acceptance placeholder re-drive and non-tombstoned
  placeholder still refuse (`outcome=subject-drift`); the existing #1331
  `adopted` behavior is regression-tested by the untouched
  `bug_1331_make_adopted_re_drive_test.dart` suite.
- Only the modified files' tests run (cloud disk budget) + `dart format .`
  clean.
