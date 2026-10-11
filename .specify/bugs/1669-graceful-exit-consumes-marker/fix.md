# Bug Fix: a non-adopting graceful exit no longer consumes a live crash marker

- **Slug**: 1669-graceful-exit-consumes-marker
- **Fixed**: 2026-09-16
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/verification.md (this directory)

## Summary

`_printSummary` (the every-exit-path funnel) now KEEPS the write-ahead
interrupt marker when a graceful make exit does not adopt the subject while
the crash mutation survives on disk — instead of consuming it and re-creating
the #1036 wedge one refusal later. The keep is gated on a three-part compound
(crash provenance + live drift + non-placeholder subject) computed
synchronously at clear time; every resolving exit consumes the marker exactly
as before.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/commands/make_command.dart` | added `_interruptInherited` + `_interruptDriftContext` fields, the `_interruptCrashDriftLive()` probe, and the keep/clear branch in `_printSummary` | Fields captured at the existing marker-creation site (with the read-before-overwrite result, issue #1398). The probe reuses `parseEntries` (one evidence parse contract) and `subjectIsBornGreenPlaceholder`; it introduces no new parse or hash implementation. |
| `lib/src/plugins/tdd/services/make_interrupt.dart` | doc-only: the marker-class doc's "Commit" bullet now states the #1669 keep refinement | No behavior change in the service; `clearSync` untouched. |
| `lib/src/plugins/tdd/models/generation_plan.dart` | doc-only: `adoptedInterrupted`'s marker-lifecycle sentence updated | No behavior change. |
| `test/plugins/tdd/bug_1669_refusal_keeps_crash_marker_test.dart` | added (e2e tier) | 4 tests over the REAL in-process make (CliRunner + TddFixture, the spec-1398 recovery file's conventions). |

## The keep-compound (the designed decision, resolved from the issue's mitigation)

The funnel keeps the marker iff ALL of:

1. **Crash provenance** — THIS make inherited a previous make's marker at
   begin time (`interruptedRecovery`, the #1398 read-before-overwrite
   signal). This clause is the interpretation added beyond the issue's
   literal "keep when the hash differs": without it, the dishonest hand-edit
   class (a live drift on a make that began clean) would keep a marker, and
   the next resume would ADOPT the hand-edited subject — forging a crash
   record and bypassing the designed #1036 dead-end (the shipped A2 pin).
   In the wedge scenario the clause is satisfied by construction (the
   refusing run inherited the crash marker).
2. **Live drift** — the on-disk subject's sha256 differs from the certified
   hash, using the same green-then-red last-entry basis rule `_subjectDriftRefusal`
   applies. Hashless/legacy evidence and unreadable I/O fail open → consume.
3. **Not the born-green placeholder class** — `subjectIsBornGreenPlaceholder`
   on the current bytes. A marker never legitimizes a vacuous subject; the
   shipped spec-1398 A3/U5 hygiene pins (consume on the vacuous/drift-free
   refusal) are preserved unchanged.

Adopting exits (green / green-with-failed-build / skipped / adopted /
adopted-placeholder / adopted-interrupted / born-green) never meet the
compound: their appended green evidence binds the CURRENT subject hash, so
the drift is resolved by funnel time → consume.

## Tests Added or Updated

- `bug_1669_..._test.dart` A1 (RED pre-fix) — inherited marker + implemented
  crash mutation + `not-certified-red` refusal → marker SURVIVES, stdout
  carries the `issue #1669` retention note, no green evidence binds the
  mutation.
- A2 (pin) — inherited marker, subject matches the certified hash → refusal
  consumes (drift never existed; the U5 no-stale-license class with a
  certified hash present).
- A3 (pin) — identical drift WITHOUT an inherited marker → `subject-drift`
  refusal consumes this run's own marker (no forged crash record; the #1036
  dead-end stands).
- A4 (RED pre-fix) — the full un-wedge arc: wedge refusal keeps the marker →
  certified red restored → resume ADOPTS (`adopted-interrupted`, exit 0),
  green evidence binds the CURRENT hash, marker consumed.
- A5 is pinned by the existing `bug_1398_make_interrupt_recovery_test.dart`
  A3 (inherited marker + placeholder → refusal consumes), regression-run.

## Local Verification

- `dart analyze` on the 3 lib/test files → `No issues found!`
- RED (pre-fix): `dart test test/plugins/tdd/bug_1669_..._test.dart -j 1` →
  A1 + A4 FAIL for the right reason (`Expected: not null / Actual: <null>` —
  the refusal consumed the live crash record); A2 + A3 pass (pins).
- GREEN (post-fix): same command → `+4: All tests passed!`
- `dart test test/plugins/tdd/bug_1398_marker_contract_test.dart -j 1` →
  `+4: All tests passed!` (U1–U4 unit pins).
- Format: `dart format` on the touched files → clean.
- The heavyweight spec-1398 recovery e2e suite (SIGKILL harness + the A2/A3/U5
  refusal pins) runs in the background of this session; its verdict is
  recorded in ./tdd/verification.md (the Step-2 audit).

## Deviations from Assessment

- The assessment (fetch-seeded draft) carried `[NEEDS CLARIFICATION]` in
  Suspected Code Paths / Root Cause / Proposed Remediation; bug-whole never
  runs assess, so the code investigation was performed during this fix and
  is recorded in ./spec.md (FR-001..FR-004) instead of by editing the
  assessment. Root cause confirmed: `_printSummary` cleared unconditionally
  (`_interruptMarker?.clearSync()`); the certified hash lives in
  `tdd/cycle-log.md` entries (green-then-red basis).
- The keep rule adds the crash-provenance clause (compound item 1) beyond
  the issue's literal "hash differs" wording — required to keep the shipped
  #1036 dishonest-class refusal and the spec-1398 no-stale-license contract
  intact; rationale in the section above.
- Residual nuance (accepted, per the issue's chosen trade-off): in the
  #1162/#1430 fail-open classes a kept marker makes the NEXT resume take the
  #1398 adoption arm (outcome=adopted-interrupted) rather than the fail-open
  skip — both append green evidence binding the current shape; only the
  accounting label differs. The `_printSummary` sync contract makes the
  #1162 probe (which runs the target test) unmirrorable at clear time.

## Follow-ups

- The run driver's own make-skip logic is untouched; a future refactor could
  share the certified-hash basis selection between the funnel probe and
  `_subjectDriftRefusal` (kept separate here — the constraint forbids
  touching the #1036 path, and the probe must be sync).
