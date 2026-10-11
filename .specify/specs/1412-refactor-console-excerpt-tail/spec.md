# Feature Specification: Refactor failure console excerpt shows the diagnostic tail

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1412-refactor-failure-console-excerpt-tail`

**Created**: 2026-09-15

**Status**: Draft → Implemented

**Input**: GitHub issue #1412 — "RUN: failed refactor step's console excerpt prints the passing preflight head (take(3)) instead of the diagnostic tail — real build-pass failure invisible in run output"

**Related**: #1329 (cycle-log/journal tail semantics — the established contract this spec extends to the console), #1589 (blocked-contract hand surface, adjacent driver surface)

## Problem

When `zfa tdd run` spawns a refactor step that fails, the run's console
excerpt shows the FIRST 3 lines of the child transcript
(`_printOutputExcerpt`, `take(3)`). For any refactor step those first 3
lines are the passing preflight block:

```
zfa tdd refactor: preflight suite
   command: <suite template>
   preflight exit: 0
```

The operator sees `[run] U7 refactor -> runner-error` next to
`preflight exit: 0` — a contradiction. The real cause (e.g. the build
pass exiting 1 on analyzer warnings in hand-authored files) is visible
only in `tdd/journal.json` / `tdd/cycle-log.md` or by re-running the
standalone verb. The failure is IN the run output's data but not in its
console excerpt, because the excerpt prints the head — the least
diagnostic part.

Issue #1329 already established the correct semantics for the recorded
evidence paths: "failures end in the error (stack traces, the failing
summary line), the head is the least diagnostic part" — implemented as
`_outputTail` (last-200-lines with an honest truncation marker), used by
the cycle-log error entry and the journal error object. The console path
simply never adopted it.

## User Scenarios & Testing

### User Story 1 — Operator sees the real failing pass in run output (Priority: P1)

An operator drives `zfa tdd run <feature>`; the refactor step's build
pass fails (exit 1) after a green preflight. The run stops honestly, and
the console excerpt under the `step failed` line shows the DIAGNOSTIC
TAIL of the child transcript — the applying-passes block naming the
failing pass and its exit code — not the passing preflight head.

**Why P1**: this is the exact reported failure mode; a contradiction in
the run output costs a re-run of a minutes-long verb to diagnose.

#### Acceptance Scenarios

1. **Given** a refactor step whose transcript carries a passing
   preflight head and a failing-pass tail (`pass: build`, `exit: 1`,
   `pass "build" failed — misfire-stop.`), **when** the run driver
   stops on it, **then** the console excerpt contains the failing-pass
   lines and does NOT contain the preflight head lines.
2. **Given** a failed-step transcript longer than the console excerpt
   depth, **when** the excerpt prints, **then** it carries the same
   honest truncation marker wording `_outputTail` produces
   (`[... output truncated — showing the last N of M lines ...]`) —
   visible proof the console path reuses the #1329 helper.
3. **Given** a failed-step transcript shorter than the excerpt depth,
   **when** the excerpt prints, **then** every non-empty line prints
   (no marker, no dropped diagnostics) — the common small-failure case
   is unchanged in content.

### User Story 2 — Recorded evidence paths stay byte-identical (Priority: P1)

The cycle-log error entry and the journal error object keep the #1329
tail semantics untouched (hard constraint). The fix is scoped to the
console excerpt path only.

#### Acceptance Scenarios

1. **Given** the same failing refactor step, **when** the run records
   the step failure, **then** the cycle-log error entry still truncates
   at the LAST 200 lines with the same marker (unchanged from #1329),
   and the journal error object still carries the same `output_tail`.
2. **Given** any green or otherwise-successful step, **when** the run
   prints progress, **then** no excerpt prints at all (unchanged).

### User Story 3 — Build-gate failure message names file ownership (Priority: P2)

`zfa build`'s post-build analyze gate refuses on warnings in
hand-authored files with "Fix the generator or run with --no-analyze" —
misdirecting the operator at generated code. The gate's refusal message
should name the offending files' ownership: which offenders are
generator output (`.g.dart` / `.zorphy.dart`) and which are
hand-authored, with the remedy following the ownership.

**Why P2**: secondary nit from the same issue; scope-permitting polish
on the diagnostic path, no behavioral gate change.

#### Acceptance Scenarios

1. **Given** an analyze output whose error/warning lines all point at
   hand-authored files, **when** the gate refuses, **then** the remedy
   names the hand-authored files and says they are not generator output,
   instead of "Fix the generator".
2. **Given** an analyze output whose offenders are all generated files,
   **when** the gate refuses, **then** the remedy keeps the existing
   "Fix the generator" wording.
3. **Given** the refusal verdict's first line, **when** any remedy
   prints, **then** the `dart analyze reported <E> error(s) and <W>
   warning(s)` wording is byte-identical to today (the #1407/#1472
   readers parse exactly that pattern — a contract that must not drift).

## Requirements

### Functional Requirements

- **FR-1**: The failed-step console excerpt printed by
  `_printOutputExcerpt` shows the last N lines of the step's captured
  output (the diagnostic tail), where N is a small console-appropriate
  constant (10), not the first 3.
- **FR-2**: The tail is derived through the existing `_outputTail`
  helper (or a thin composition of it) — no second tail implementation;
  the honest truncation marker rides along.
- **FR-3**: Empty/whitespace-only lines never consume excerpt slots
  (the pre-fix excerpt was compact; it stays compact).
- **FR-4**: The cycle-log and journal tail paths (`_outputTail` at its
  #1329 call sites) are byte-identical in behavior — no parameter
  changes, no call-site changes.
- **FR-5** (secondary): the build gate refusal prints an ownership
  verdict naming offending files as generator output or hand-authored
  (deduped, capped listing with a remainder count), and the remedy line
  matches the ownership; the verdict's count line is unchanged.

### Key Entities

- `RunDriverCore._printOutputExcerpt` — the console excerpt printer
  (the ONLY changed output path).
- `RunDriverCore._outputTail` — the #1329 tail helper (REUSED, not
  modified).
- `BuildCommand.verifyAnalyzeOrFail` / new pure statics — the gate
  refusal message (secondary).

## Success Criteria (measurable)

- **SC-1**: Driver-level test: with a failing refactor step whose
  transcript has a preflight head and a failing-pass tail, the captured
  run stdout contains `pass: build`, `exit: 1` and
  `pass "build" failed — misfire-stop.` in the excerpt block, and does
  NOT contain `preflight exit: 0` (proved by the fake-zfa flood
  transcript in `bug_1412_refactor_excerpt_tail_test.dart`).
- **SC-2**: The same test asserts the honest truncation marker wording
  (`truncated` + `last 10 of`) appears when the transcript exceeds 10
  non-empty lines — the `_outputTail`-reuse proof.
- **SC-3**: A short (≤10 non-empty lines) failing transcript prints all
  of its non-empty lines and no truncation marker.
- **SC-4**: The same failing step's cycle-log error section still shows
  the #1329 contract: `200 of 251` truncation for a 251-line transcript
  (byte-identical recorded evidence — hard constraint regression-pinned).
- **SC-5**: Unit tests for `analyzerOffendingPaths` +
  `analyzeGateRemedyLines`: hand-authored-only offenders flip the remedy
  to the ownership-naming lines; generated-only offenders keep the
  "Fix the generator" line; info lines and summary lines never produce
  offenders; duplicates dedupe.
- **SC-6**: `dart analyze` on changed files: no issues; all new and
  touched test files green; `dart format` clean.

## Constraints

- Fix the console excerpt path ONLY; cycle-log/journal tail unchanged
  (from the issue's hard constraints).
- One PR per feature; branch `feat/1412-refactor-failure-console-excerpt-tail`.
- The refusal count-line pattern (`dart analyze reported ...`) is a
  read contract of the make (#1407) and refactor registry (#1472) — must
  not change.
