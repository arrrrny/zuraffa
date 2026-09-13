# Tasks: 1549-fence-aware-remaining-readers

- **Spec ID**: 1549-fence-aware-remaining-readers
- **Created**: 2026-09-13

Dependency order: T001 (vendored helper, non-behavioural) → T002 (iterator +
its tests, red → green) → T003 (reader fence fixtures, RED evidence) →
T004 (reader conversions, green) → T005 (verify + evidence). T003's fixtures
predate T004's green run in evidence terms and are committed with the red
phase so the suite's expectations match the spec before the fix lands.

## T001: Vendor the shared fence-aware splitter (non-behavioural)

- Copy `lib/src/plugins/tdd/services/cycle_log_sections.dart` and
  `test/plugins/tdd/services/cycle_log_sections_test.dart` from
  `origin/fix/cycle-log-phantom-sections` (PR #1543) BYTE-IDENTICAL
  (`git checkout <sha> -- <paths>`); hard constraint — no edits, no fork.
- Run the vendored suite → 12/12 green (helper contract locked on this
  branch).
- Tests: `test/plugins/tdd/services/cycle_log_sections_test.dart`

## T002: Shared entry-sections iterator (red → green)

- NEW `lib/src/plugins/tdd/services/cycle_log_entry_sections.dart`:
  `CycleLogEntrySection` (header / behavior / kind / bodyLines) +
  `parseCycleLogEntrySections(String raw)` built on
  `splitCycleLogSections()`:
  - skips the preamble chunk and every non-`Cycle:` section
  - strips a byte-0 header's leading `## ` (first chunk only — the legacy
    split contract keeps it)
  - `behavior` = first whitespace token after `Cycle:`; `kind` = the
    parenthesized tail
  - `bodyLines` verbatim, fenced output included
- NEW `test/plugins/tdd/services/cycle_log_entry_sections_test.dart`:
  header grammar, byte-0 prefix, preamble/non-Cycle skipping, in-fence
  `## Cycle:` stays in bodyLines, inline `- output: ``` ` dialect.
- Tests: `cycle_log_entry_sections_test.dart`

## T003: Red fixtures — one in-fence `## Cycle:` scenario per reader

- `test/plugins/tdd/services/provenance_scanner_test.dart`: new group —
  red entry with in-fence `## Cycle: PHANTOM (refactor)` +
  `changed: lib/src/phantom.dart`; real refactor entry attributes
  `lib/src/real.dart` with its action command; phantom file NEVER
  attributed (SC-1).
- `test/plugins/tdd/services/ci_referee/failure_artifacts_test.dart`:
  new test — red entry whose output contains an in-fence `## Cycle:` line
  and a failing frame after it; exactly one artifact, excerpt reaches the
  end of the captured output, `failingLine` is the post-phantom frame, the
  in-fence line stays verbatim in the excerpt (SC-2).
- `test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart`:
  new test — red entry with in-fence `## Cycle: PHANTOM (green)` +
  `- kind: green`, real green sibling; receipts cover the subjects;
  `PHANTOM` never greens, feature completes `complete(real)` (SC-3).
- Run all three files → RED; evidence: `tdd/red-1549.log` (exit 1, one
  failure per reader, each failing on the phantom-driven expectation).

## T004: Green — route the three readers through the iterator

- `provenance_scanner.dart` `_collectRefactorAttributions`: iterate
  `parseCycleLogEntrySections()`; `inRefactorSection = entry.kind ==
  'refactor'`; body scan unchanged; `currentCommand` hoisted outside the
  entry loop (cross-entry persistence preserved).
- `ci_referee/failure_artifacts.dart` `_parseRedEntries`: iterate entries;
  `entry.kind != 'red'` → skip; per-entry `currentTest`/`inOutput`/`output`
  state; unchanged closeEntry emission at entry end.
- `ci_referee/feature_provenance_reader.dart` `_readGreenBehaviors`:
  iterate entries; skip empty `behavior`; body `- kind:` … `green` check
  unchanged; `greens.add(entry.behavior)`.
- No other lib/ changes; no model/writer changes.
- Tests: T003 fixtures turn green alongside the existing suites.

## T005: Verify + evidence (non-behavioural)

- `rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*`
- `dart analyze` on every changed `.dart` file → no new issues vs the
  112-pre-existing-info baseline (SC-6)
- Targeted suites for every changed lib file's test counterpart (SC-5)
- `dart format` on changed files → 0 changed (SC-6)
- Evidence logs under `tdd/` (red-1549.log, green-1549.log);
  `tdd/verification.md` written from the actual runs.
