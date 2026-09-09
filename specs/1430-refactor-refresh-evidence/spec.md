# Feature Specification: The refactor pass must not strand the green evidence it just certified

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `1430-refactor-refresh-evidence`

**Created**: 2026-09-09

**Status**: Draft

**Input**: User description: "Issue #1430 — tdd run: the refactor pass invalidates the green evidence it just certified — every resume hits subject-drift and cannot resume through the loop"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A run-driven feature resumes clean through the loop (Priority: P1)

A developer drives a feature with `zfa tdd run` whose plan holds at least one
acceptance behavior and at least one behavior that stops for a designed
hand-delta step (the #1308 vacuous-guard workflow). The run certifies a
behavior green — the cycle log records the subject-hash fingerprint — and
then the fixed pass-registry refactor cycle (`zfa build`, `dart format lib/`,
`dart fix --apply lib/`) rewrites files under `lib/`, including the
just-certified subject, and re-proofs the suite green against the new
shapes. The run later stops for the designed hand-delta step. When the
developer finishes the hand work and re-runs `zfa tdd run <feature>`, the
resume must advance through the already-done behavior's make step — the
loop's own refactor being the only change to the certified subject since
certification. Today the resume refuses: make's honest guard compares the
stale certified hash against the reformatted file, reports
`subject-drift (stale-artifacts)`, and the driver prints "this state cannot
resume through the loop", prescribing a full `zfa tdd reset` that destroys
evidence the loop itself produced and verified.

**Why this priority**: The loop manufactures the exact state its resume path
refuses. Every hand-delta-driven feature — the designed workflow for specs
whose unit rows carry void/entity-traced contracts (#1259/#1308) — re-pays
one manual `--re-certify` per already-done behavior on every resume, and the
only printed remedy destroys certified evidence. This is the defect itself.

**Independent Test**: Certify one behavior green in a feature whose next
behavior stops for a hand step, let the refactor pass reformat the certified
subject, then re-run the feature: the resume advances past the certified
behavior's make step with no manual `--re-certify`.

**Acceptance Scenarios**:

1. **Given** a feature where behavior A1 certified green with a recorded
   subject-hash, the loop's refactor pass reformatted/rewrote A1's subject
   file under `lib/tdd/<feature>/`, and the run stopped for a hand-delta
   step on a later behavior, **When** the developer re-runs
   `zfa tdd run <feature>`, **Then** the resume reaches A1's make step and
   advances past it via the already-green transition — no
   `subject-drift (stale-artifacts)` refusal, no manual `--re-certify`
   **Type**: acceptance
2. **Given** the same feature reached green-plus-refactored state through
   the loop alone, **When** the run's cycle log is read, **Then** the green
   evidence a later make's guard consults carries a subject-hash matching
   the on-disk post-refactor subject — the certified evidence and the disk
   never disagree about a rewrite the loop itself performed and re-proved
   **Type**: acceptance

---

### User Story 2 - The honest guard stays honest (Priority: P2)

A subject that drifts for any reason other than the loop's own refactor
pass — a hand edit to a certified subject between runs, an out-of-band tool
rewrite — must still be refused exactly as today: `subject-drift
(stale-artifacts)` with the #1036 diagnosis and the #1162 `--re-certify`
remedy. The fix widens what the loop forgives (its own sanctioned rewrite),
never what the guard tolerates (unexplained drift).

**Why this priority**: Errors-are-an-API is the repo's recovery contract.
The #1036 guard exists to catch a certified subject whose shape no longer
matches its evidence; relaxing it for arbitrary drift would green-wash
unverified subjects.

**Independent Test**: Certify a behavior green, hand-edit its subject file
outside any run, re-run the feature: the resume still refuses with
`subject-drift (stale-artifacts)` naming the hash mismatch.

**Acceptance Scenarios**:

1. **Given** a behavior whose green evidence recorded a subject-hash, and
   the subject file was changed after certification by anything other than
   the loop's refactor pass, **When** a later make reaches the behavior's
   already-green transition, **Then** it refuses with the existing
   `subject-drift` diagnosis (certified hash vs current hash, issue #1036
   citation, #1162 remedy) **Type**: acceptance

---

### User Story 3 - No green-washing through the refactor (Priority: P3)

A refresh of certified evidence must never outrun its proof. The refactor
pass re-proofs the suite after its rewrite; only a re-proof that actually
exercised a touched behavior's test licenses refreshing that behavior's
evidence. If the refactor's rewrite breaks the suite, the existing failure
path fires unchanged and no evidence is refreshed.

**Why this priority**: Defense in depth — without it, a future scoped
re-proof optimization would silently certify unproved subjects.

**Independent Test**: A refactor pass whose rewrite touches a certified
subject and whose re-proof covers that behavior's test refreshes the
evidence; a refactor whose re-proof fails refreshes nothing and reports the
existing regression.

**Acceptance Scenarios**:

1. **Given** a refactor pass that rewrote a certified subject and whose
   re-proof ran green over a scope that includes that behavior's test,
   **When** the pass completes, **Then** the behavior's certified green
   evidence is refreshed to the post-rewrite subject-hash **Type**: unit
2. **Given** a refactor pass whose rewrite breaks the suite, **When** the
   re-proof fails, **Then** the run stops via the existing re-proof failure
   reporting and no certified evidence is refreshed **Type**: unit
3. **Given** a refactor pass that did not touch any certified subject's
   file, **When** the pass completes green, **Then** the cycle log gains
   exactly what it gains today (the refactor entry) and no behavior's green
   evidence changes **Type**: unit

---

### Edge Cases

- What happens when the refactor rewrites the subject of a behavior that is
  NOT yet certified (still pending or red)? No green evidence exists to
  refresh; the pass must leave it alone and the next certify stamps the
  then-current hash naturally. **Type**: unit
- What happens when the refactor rewrites several certified subjects in one
  pass? Every touched behavior's evidence is refreshed under the same
  green-re-proof gate. **Type**: unit
- What happens when the run driver's stale-artifacts stop fires today — can
  it still fire? Yes, but only for genuine out-of-band drift (US2); the
  loop-caused variant becomes unreachable. **Type**: unit
- What happens to red-evidence subject-hashes (the #1162 re-certification
  basis) when the refactor touches a red-certified subject? Red-basis drift
  already fails open through the implemented-subject acceptance; this
  feature must not regress that path. **Type**: unit

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The refactor pass MUST leave every behavior's certified green
  evidence consistent with the on-disk subject when the only change to that
  subject since certification was the pass's own rewrite — a feature the
  loop drove to green-plus-refactored MUST resume through
  `zfa tdd run <feature>` with zero manual `--re-certify` steps
- **FR-002**: A certified behavior's green evidence subject-hash MAY be
  refreshed past the pass's rewrite ONLY when the pass's re-proof proved
  the suite green against the new shapes over a scope that exercised that
  behavior's test — a scoped re-proof that does not cover a touched
  behavior's test MUST be widened to cover it before any refresh, or the
  refresh MUST NOT happen
- **FR-003**: Genuine subject drift — any post-certification change to a
  certified subject NOT performed by the loop's refactor pass — MUST still
  be refused with the existing `subject-drift (stale-artifacts)` diagnosis,
  hash comparison, issue #1036 citation, and #1162 remedy, unchanged
- **FR-004**: The refactor pass's existing re-proof failure path MUST be
  unchanged: a rewrite that breaks the suite stops the run with the current
  diagnostics and refreshes no evidence
- **FR-005**: A refactor pass that touches no certified subject MUST
  produce exactly today's observable effects (refactor cycle entry, pass
  receipts refresh) and no additional cycle-log writes
- **FR-006**: Either implementation shape is acceptable — refreshing the
  certified evidence after a green re-proof, or exempting
  `lib/tdd/<feature>/` registry-owned subjects from the `format`/`fix`
  passes — provided every FR above holds; red-evidence semantics (#1162)
  and the tombstone/born-green escape hatches (#1331) MUST NOT regress

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The issue's exact repro (certify A1 green → refactor pass
  reformats the subject → hand-delta stop → resume) completes the resumed
  A1 make step with zero manual `--re-certify` invocations
- **SC-002**: 100% of out-of-band post-certification subject edits still
  refuse with `subject-drift (stale-artifacts)` on resume
- **SC-003**: A refactor that breaks the suite still stops with the existing
  re-proof diagnostics in 100% of such runs, with no evidence write
- **SC-004**: The existing TDD plugin suites (the #1308 hand-step remedy
  suite, the stale-artifacts suite) stay green

## Assumptions

- The fix shape (evidence refresh vs pass exclusion) is a plan-phase
  decision; the hash-chained cycle log appends entries rather than editing
  history, so a refresh will most likely land as a new certified-green
  evidence entry carrying the post-rewrite hash — the guard reads the last
  green entry per behavior
- The stale-artifacts terminal stop in the run driver stays for genuine
  drift; only the loop-caused variant becomes unreachable
- Scope is the run driver phase-2b refactor pass and the make already-green
  guard's interplay; `zfa tdd refactor` run standalone gets the same
  reconciliation so the two entry points cannot diverge
- Sibling issues #1423 (hand-delta re-receipt) and #1430's quoted #1308
  workflow are context, not scope: this feature only fixes the
  refactor-strands-evidence defect
