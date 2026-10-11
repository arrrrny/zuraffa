**Template Version**: `zuraffa-1.0`

# Spec: non-adopting graceful exit must not consume a live crash marker (issue #1669)

## Summary

A NON-adopting graceful exit after a crash consumes the crash record while the
crash mutation survives, re-creating the #1036 wedge (#1398 follow-up):

1. Make killed mid-flight → subject mutated green + `make-interrupt.json` present.
2. Resume refuses for an UNRELATED reason (flaky target test → generation-error,
   preflight failure, or log loss → not-certified-red).
3. `_printSummary` (the every-exit-path funnel) clears the marker on EVERY
   graceful exit — including this refusal.
4. Next resume: subject still mutated, marker gone → byte-identical to the
   dishonest hand-edit class → #1036 `subject-drift` refusal dead-ends it.

Source: https://github.com/arrrrny/zuraffa/issues/1669

## Requirements

- **FR-001**: The system MUST keep `specs/<feature>/tdd/make-interrupt.json` on disk and print an `issue #1669` retention note when a graceful make exit does not adopt the subject, THIS make inherited a previous make's interrupt marker at begin time, the on-disk subject's sha256 differs from the certified hash in the evidence registry, and the on-disk subject is not a born-green placeholder.

  - Crash provenance: the read-before-overwrite signal (issue #1398). A make
    that began clean must never keep a marker — that would forge a crash
    record for the dishonest hand-edit class and bypass the designed #1036
    dead-end.
  - Live drift: the certified-hash basis follows the same green-then-red
    last-entry rule the #1036 guard applies (`tdd/cycle-log.md`).
    Hashless/legacy evidence (no certified hash) is "drift never existed" —
    consume.
  - Not the vacuous class: `subjectIsBornGreenPlaceholder` on the current
    bytes. A marker never legitimizes a vacuous subject; the refusal's own
    remedy (restore the certified shape) resolves that drift, and the shipped
    SC-6 hygiene contract (spec 1398 U5/A3) keeps consuming.

- **FR-002**: The system MUST consume the marker on every graceful exit that does not meet the FR-001 compound, exactly as before the fix.

  - Adopting exits (green / green-with-failed-build / skipped / adopted /
    adopted-placeholder / adopted-interrupted / born-green): the appended
    green evidence re-binds the CURRENT subject hash, so the drift is
    resolved.
  - Refusals with no live drift: nothing mutated, the subject matches the
    certified hash, or hashless evidence.
  - Refusals on a born-green placeholder subject (the vacuous class).
  - Refusals from a make that began clean (no inherited marker) — the #1036
    subject-drift dead-end for the dishonest hand-edit class is preserved
    byte-for-byte.

- **FR-003**: The system MUST leave the resume un-wedged when the marker is retained: the next make finds the crash record, adopts the passing subject through the #1398 adoption arm (outcome=adopted-interrupted, exit 0), appends green evidence binding the current subject hash, and consumes the marker. The wedge state (mutation + no marker) MUST be unreachable via graceful exits.

- **FR-004**: The fix MUST NOT change the make-skip logic, the fingerprint comparison, or the #1036 recovery path: the drift signal is computed at clear time inside the summary funnel from the CURRENT disk state (sync read: subject bytes + cycle-log entries), leaving `_subjectDriftRefusal` and the adoption arms unchanged.

## Acceptance Scenarios

1. **Given** a behavior whose certified green evidence binds the stub's hash
   **Type**: acceptance
   (the log-loss flavor: the red entry is gone, the certified hash survives),
   and a crashed make left the interrupt marker on disk AND mutated the
   subject to a real implemented shape (not a born-green placeholder),
   **When** the resumed make exits non-adopting (refuses
   `not-certified-red`), **Then** the interrupt marker file still exists on
   disk and stdout carries the `issue #1669` retention note (FR-001).

2. **Given** the same shape but the on-disk subject still matches the
   **Type**: acceptance
   certified hash (the crash left no mutation), **When** the resumed make
   refuses `not-certified-red`, **Then** the marker is consumed — the drift
   never existed and no stale license survives (FR-002).

3. **Given** the identical drift to scenario 1 but NO marker on disk before
   **Type**: acceptance
   the make begins (the dishonest hand-edit class), **When** the make refuses
   `subject-drift`, **Then** the refusal consumes this run's own marker — a
   make that began clean never forges a crash record, and the #1036 dead-end
   stands (FR-002).

4. **Given** the wedge state of scenario 1 (mutated subject, marker retained
   **Type**: acceptance
   by the refusal), **When** the behavior's red evidence is re-certified and
   the make resumes, **Then** the marker proves the crash: the make adopts
   the passing subject (outcome=adopted-interrupted, exit 0), appends green
   evidence binding the CURRENT subject hash, and consumes the marker (FR-003).

5. **Given** a crashed make whose marker was inherited but whose on-disk
   **Type**: acceptance
   subject is the born-green placeholder class (the vacuous shape), **When**
   the resumed make refuses (the adoption arm withholds), **Then** the marker
   is consumed — the shipped spec-1398 hygiene contract (A3/U5) is unchanged
   (FR-002).

## Constraints

- `_printSummary` stays sync; the drift signal is computed synchronously at
  clear time.
- Fail closed on unreadable subject/log I/O: a probe error consumes (never
  blocks a make, never widens adoption).
- Existing spec-1398 pins (A1/A2/A3/U5) keep passing unchanged.
