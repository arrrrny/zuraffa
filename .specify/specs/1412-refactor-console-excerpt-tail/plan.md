# Plan: Refactor failure console excerpt shows the diagnostic tail (issue #1412)

- **Branch**: `feat/1412-refactor-failure-console-excerpt-tail`
- **Base**: `master` @ 2ac6b9d7
- **Spec**: [spec.md](spec.md)

## Technical Context

- **Language/runtime**: Dart 3.13 (SDK constraint `^3.11.0`), pure `package:zuraffa`
  CLI code (no Flutter in the changed paths).
- **Primary file**: `lib/src/plugins/tdd/commands/run_driver_core.dart` — the
  shared two-phase driver core behind `zfa tdd run` / `run-engine` / `run-skin`.
- **Secondary file**: `lib/src/commands/build_command.dart` — the post-build
  analyze gate (secondary nit).

## Root Cause (code-level)

`RunDriverCore._printOutputExcerpt` (run_driver_core.dart:3788):

```dart
void _printOutputExcerpt(String output) {
  final lines = output
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .take(3);            // <-- HEAD, not tail
  for (final line in lines) {
    print('   $line');
  }
}
```

For a refactor step the transcript always OPENS with the passing preflight
block, so `take(3)` shows the preflight and hides the failing pass. The
adjacent static `_outputTail` (run_driver_core.dart:3777, issue #1329) already
implements the correct semantics (last-N-lines with an honest truncation
marker) for the cycle-log/journal paths (`_recordStepFailure` call sites at
2059/2696/2812 — those stay untouched).

All nine `_printOutputExcerpt` call sites (the generic step-failure stop, the
refactor not-green skip, the phase-0 spawn failures, the vacuous-guard and
stale-artifact remedy stops) funnel through the ONE method — fixing the method
fixes every failed-step console path at once.

## Design

### Change 1 — console excerpt routes through `_outputTail` (SC-1..SC-4, FR-1..FR-4)

```dart
/// The console excerpt depth (issue #1412): the LAST 10 non-empty lines...
static const int _consoleExcerptLines = 10;

void _printOutputExcerpt(String output) {
  final compact = output
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .join('\n');
  if (compact.isEmpty) return;
  final tail = _outputTail(compact, maxLines: _consoleExcerptLines);
  for (final line in tail.split('\n')) {
    print('   $line');
  }
}
```

- Reuses `_outputTail` verbatim (FR-2/AC3 — no duplication): the honest
  `[... output truncated — showing the last 10 of M lines ...]` marker rides
  along for transcripts deeper than 10 non-empty lines.
- Keeps the pre-fix compactness (FR-3): empty lines are filtered BEFORE the
  tail is taken, so blank padding cannot consume excerpt slots.
- Empty output prints nothing (pre-fix behavior preserved).
- `_outputTail` itself is NOT modified, and its journal/cycle-log call sites
  are NOT touched (FR-4 — the hard constraint).

### Change 2 — ownership-aware gate remedy (SC-5, FR-5)

`build_command.dart`:

- New pure static `analyzerOffendingPaths(String)` — the `path:line:col`
  field of every error/warning severity line (the #1035 line format), deduped
  in first-seen order; info lines never count (they are style, not gate
  evidence).
- New pure static `analyzeGateRemedyLines(String)` — returns the remedy lines
  from the offenders' ownership:
  - all offenders generated (`.g.dart` / `.zorphy.dart`) → the existing
    `Fix the generator or run with --no-analyze to skip this check.`
  - any hand-authored → `generator output offending: ...` (when present) +
    `hand-authored offending (not generator output): <up to 3 files> (+N more)`
    + `Fix the named files, or run with --no-analyze to skip this check.`
- `verifyAnalyzeOrFail` prints the returned lines; the verdict's FIRST line
  (`❌ dart analyze reported <E> error(s) and <W> warning(s) — ...`) is
  byte-identical (the #1407/#1472 `_analyzeGateRefusalPattern` contract).

Both statics are `@visibleForTesting`-exposed pure functions — unit-testable
without spawning `dart analyze` (the same convention as `countAnalyzerIssues`).

## Test Strategy

- **Driver tier** (`test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart`,
  the `bug_1329_step_failure_diagnostics_test.dart` harness): TddFixture +
  fake zfa + `CliRunner.runCapturing`. The fixture's refactor stanza gains an
  additive `flood` outcome (mirroring gen's #1329 flood): a realistic
  transcript — preflight head + pass-block tail, 251 captured lines — exit 1.
  Asserts SC-1, SC-2, SC-3 (short `boom` transcript), SC-4 (cycle-log still
  `200 of 251` — the untouched-path pin).
- **Unit tier** (`test/commands/build_command_unit_test.dart`): new groups for
  `analyzerOffendingPaths` + `analyzeGateRemedyLines` (SC-5).
- **Verify tier**: `dart analyze` on changed files + targeted `dart test` on
  the changed files' suites + `dart format` (SC-6), recorded in
  tdd/verification.md from REAL runs.

## Risks / Trade-offs

- **Console width**: 10 tail lines instead of 3 — accepted by the issue
  ("a short tail, e.g. last 10 lines"); the marker names the dropped count.
- **Marker indent**: the truncation marker prints with the 3-space excerpt
  indent — consistent with every excerpt line.
- **Contract drift**: none — the refusal pattern line and the journal tail
  are pinned by tests (SC-4, #1472 suite).
