# Implementation Plan: crash-safe make — journal the interrupt, adopt on resume

**Branch**: `feat/1398-crash-safe-make-journal-interrupt`
**Spec**: [spec.md](./spec.md) · **Issue**: #1398 · **Epic**: #1012
**Created**: 2026-09-16

## Technical Context

**Language/Version**: Dart 3.13 (SDK constraint `^3.11.0` in pubspec.yaml); pure-Dart CLI (`bin/zuraffa.dart`, executable `zfa`), no Flutter in the test tree for this feature.
**Primary dependencies**: `package:test` (dev), `package:crypto` (subject-hash binding, already used by make), `package:path`.
**Storage**: file contracts under `specs/<feature>/tdd/` — cycle-log.md (append-only evidence), artifacts.json (registry), run-state.json, transaction.json (write-ahead step intent). This feature adds `make-interrupt.json` beside them.
**Testing**: `dart test` over throwaway fixture projects (`TddFixture` in `test/plugins/tdd/helpers/tdd_fixture.dart`); real `zfa tdd make` subprocesses for the SIGKILL scenario, `CliRunner(exitOnCompletion: false)` in-process for the make semantics, fake zfa shell script for the driver level.
**Target surface**: `lib/src/plugins/tdd/` only. The make command's already-green branch, the MakeOutcome vocabulary, the step outcome contract (StepRunner), and the run driver's bug-#986 terminal-success arm.

## Constitution Check (project conventions observed)

- **Honesty floor (#1036 family)**: a subject the red evidence never exercised is never certified green — the placeholder gate stays in front of the new adoption; the adoption binds the CURRENT subject hash so post-adoption drift still refuses.
- **Every exit prints the machine summary (FR-010)**: the marker's clear is wired to that same every-exit-path funnel, so "graceful exit" and "summary printed" cannot diverge.
- **Fail closed**: a corrupt/unparseable/foreign marker behaves as absent; unreadable subject files keep the existing fail-closed treatment (refusal stands).
- **Explicit outcomes**: the crash-recovery adoption is EXPLICITLY labeled `adopted-interrupted` — never conflated with `green`, `skipped`, or `adopted` (the #1331/#1345/#942 accounting discipline).
- **One PR per feature; hard constraints**: journal/interrupt detection only — no make-skip logic change, no fingerprint comparison change, no subject-drift recovery path change.

## Design

### Marker service (`MakeInterruptMarker`, new file `services/make_interrupt.dart`)

Mirrors `TddTransaction` (bug #828) in shape and discipline:

- Path: `<featureDir>/tdd/make-interrupt.json` (single-slot, keyed by behavior field — the run driver serializes makes per feature, so at most one make is in flight).
- `begin({behavior})`: write `{schema: 1, feature, behavior, pid, at, status: 'in-progress'}` atomically (tmp file + fsync + rename) — write-ahead BEFORE any subject-mutating work.
- `pendingFor(behavior)`: read the CURRENT file; return the record only when it parses, is `in-progress`, and names the SAME behavior; every other shape (missing, corrupt, different behavior) → null. Fail closed = treated as absent.
- `clear()`: delete when present (idempotent), best-effort — a marker clear must never fail a make.
- Process discrimination: the make READS the marker (previous make's record) BEFORE it OVERWRITES it with its own record — read-before-overwrite is the only discrimination needed; a make never adopts its own marker. Pid is recorded for auditability only (no liveness probes — pid reuse makes them unsound).

### Make command integration (`commands/make_command.dart`)

1. After target/record resolution (before any pipeline work), read `pendingFor(record.behaviorId)` → `interruptedRecovery` (the previous make's crash), then `begin(behavior)` (this make's write-ahead).
2. In the already-green branch, a NEW arm sits in front of the existing structure:
   - `interruptedRecovery` && subject NOT born-green-placeholder → `adoptedReDrive = true` (the #1331 adoption mechanics: green evidence binding the current subject hash) + the explicit resume-after-interruption message.
   - `interruptedRecovery` && placeholder on disk → falls through to the existing refusal (the marker note explains why adoption is withheld).
   - Order vs existing arms: interrupt adoption is checked first; the #1331 tombstone re-drive and #1345 placeholder re-entry arms are unchanged after it.
3. Marker clear on every graceful exit: `_printSummary` — the funnel every terminal path already prints through (FR-010) — clears best-effort. Summary-printed and marker-cleared cannot diverge.
4. Outcome token on the adoption path: `MakeOutcome.adoptedInterrupted` (`adopted-interrupted`), exit 0.

### Outcome vocabulary (`models/generation_plan.dart`)

`MakeOutcome.adoptedInterrupted('adopted-interrupted')` — documented as the #1398 crash-recovery adoption, distinguishable from `green`/`skipped`/`adopted`/`adopted-placeholder`.

### Step outcome contract (`services/step_runner.dart`)

The make success set gains `adopted-interrupted` (same grading as `adopted`: exit 0 + token = success; the token is the terminal classification).

### Run driver (`commands/run_driver_core.dart`)

The bug-#986 arm (make token vs exit-code disagreement) recognizes `adopted-interrupted`: records the green evidence the child did not write (naming the #1398 transition in the captured-output note), advances the behavior, prints `make -> green (adopted-interrupted)`. No other driver arm changes: the #1324 stale-artifacts arm and the generic subject-drift stop remain for the classes that still refuse.

### Why not the driver's TddTransaction as the marker

The driver's write-ahead `transaction.json` records step intent for the WHOLE run (all steps), is cleared/replayed by `_replayJournal` before the loop re-drives, and does not exist for standalone `zfa tdd make` invocations — which must recover too (the doctor workaround prescribes run, but the make contract is standalone). A make-owned marker survives both flows with one mechanism and no replay-order coupling. The driver's transaction stays untouched.

## Risks / Trade-offs

- **Adoption width**: a crash marker present + user hand-edit AFTER the crash would adopt the edited shape. Mitigated: the adoption re-runs the target test honestly (the drift run), binds the current hash, and any later drift refuses; the placeholder gate blocks the vacuous class. Same trust model as #1331's tombstone adoption (the user's explicit reset).
- **Marker left by a make that mutated nothing**: resume adopts only when the target test already passes; otherwise the pipeline re-drives and the marker is cleared at exit. No false adoption (SC-2 requires the passing test).
- **Stale marker after a refusal**: the refusal path clears the marker (graceful exit) — the user's fix (git restore / re-certify) re-drives honestly; the marker's absence then matches the honest state.

## Migration / Compatibility

None required: the marker file is new, additive, and read only by the make of the same behavior. Projects without it behave exactly as before (FR-7). No registry, run-state, cycle-log, or journal schema changes.

## Open Items

None — all decisions recorded above.
