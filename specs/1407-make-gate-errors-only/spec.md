# Feature Specification: make gates on errors only — warnings are non-blocking and consistent across lanes

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1407-make-gate-errors-only`

**Created**: 2026-09-11

**Status**: Draft

**Input**: User description: "Issue #1407 — MAKE-GATE: zfa tdd make refuses with generation-error when dart analyze reports 0 errors + 1 pre-existing warning (cross-lane warning coupling)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A warning never fails a make (Priority: P1)

A developer drives a skin-lane widget behavior (`W3`) through `zfa tdd make`
in a rebuild where the project carries a pre-existing analyzer warning left
by the engine lane (an unused import in
`lib/src/data/datasources/credentials/credentials_mock_datasource.dart` —
the gate runs `dart analyze lib`, so the pre-existing warning must live
under `lib/` to reach the gate's verdict).
The make plan's terminal `build` step runs its analyze stage, the analyzer
reports **0 errors and 1 warning**, and the build command's gate refuses
the tree as "does not compile cleanly". Today the make then grades that
refusal through the per-behavior guard and can stop with
`outcome=generation-error` — a warning-level finding treated as a
generation failure, even though 0 errors means the code compiles. The make
must treat warnings as **logged, non-blocking findings**: the warning is
surfaced in the transcript, and the make proceeds through its normal
flow (post-generation target test, suite guard, green evidence). Only
analyzer **errors** may stop the make with `outcome=generation-error`.

**Why this priority**: This is the defect itself. The real-world
zik_zak_v2 login rebuild stopped the skin lane on a warning the engine
lane's own green receipt had already accepted; the workaround (hand-cleaning
warnings before every skin make) is not repeatable for agent-driven runs.

**Independent Test**: A make whose terminal build step is refused by the
analyze gate on 0 errors + 1 warning, with the behavior's own test passing
after generation, completes `outcome=green` (exit 0), prints the
warnings with a non-blocking verdict, and appends the green evidence
entry. (Today: the refusal reaches the per-behavior guard and the make
records `green-with-failed-build` — a failed-build label the loop's
accounting must never need for a mere warning.)

**Acceptance Scenarios**:

1. **Given** a certified-red behavior whose make plan reaches a terminal
   `build` step that the analyze gate refuses with 0 error(s) and ≥1
   warning(s), **When** the make runs and the behavior's own target test
   passes after generation, **Then** the make completes with
   `outcome=green`, exit 0, the green evidence entry is appended, and the
   transcript logs the warning lines plus a `warnings are non-blocking`
   verdict (issue #1407 citation) — the outcome is never
   `green-with-failed-build` nor `generation-error` **Type**: acceptance
2. **Given** the same warnings-only gate refusal but the behavior's own
   target test still fails after generation, **When** the make runs,
   **Then** it stops with `outcome=generation-error` because the red
   target test — not the warning — is the cause; the #1036 failed-make
   contract (subject restore) holds **Type**: acceptance
3. **Given** a build step whose analyze verdict carries 1 or more analyzer
   **errors**, **When** the make runs, **Then** the existing #942 refusal
   stands byte-identically: the per-behavior guard refuses the tolerance,
   the make stops `outcome=generation-error`, and no green entry is
   appended **Type**: acceptance

---

### User Story 2 - The same gate strictness for every lane and transition (Priority: P2)

A feature runs through the two-cycle driver: the engine lane's makes and
the skin lane's makes execute in the same run, and already-green behaviors
take the #694 skip transition. The analyze gate the make applies must be
**the same gate object for every lane and every transition in the run**:
if warnings are non-blocking for an engine-lane make, they must be
non-blocking for a skin-lane make, and the skip transition (which runs no
analyze gate at all) must not coexist with a normal make transition that
refuses on warnings. The fix lives in the one shared make flow so no lane
can drift in strictness again.

**Why this priority**: The cross-lane coupling is what made the defect
confusing in the field — the engine receipt was green while the skin make
refused on the same finding. Consistency is the acceptance criterion the
issue names second, and it is guaranteed structurally by fixing the shared
flow rather than either lane.

**Independent Test**: Drive a widget-lane (skin) behavior and a unit-lane
(engine) behavior through identical warnings-only build refusals in one
fixture feature: both makes complete `outcome=green` with identical gate
logging, and an already-green sibling's make completes `outcome=skipped`.

**Acceptance Scenarios**:

1. **Given** a skin-lane (widget-kind) behavior whose make hits the
   warnings-only gate refusal and whose target test passes after the view
   step, **When** the make runs, **Then** it completes `outcome=green`
   under the same errors-only gate the engine lane gets — identical
   verdict line, identical logging **Type**: acceptance
2. **Given** an engine-lane (unit-kind) behavior under the identical
   fixture conditions, **When** the make runs, **Then** the outcome and
   gate logging match the skin lane's byte-for-byte except the behavior id
   and plan steps **Type**: acceptance
3. **Given** an already-green behavior in the same feature (the #694 skip
   transition), **When** its make runs, **Then** it completes
   `outcome=skipped`, exit 0 — the strictness applied to warnings in the
   normal transition (non-blocking) matches the skip transition's (the
   gate never runs): no inconsistent strictness within the same run
   **Type**: acceptance

---

### User Story 3 - Projects that rely on warnings being blocking can opt back in (Priority: P3)

A project that (unusually) relies on the analyze gate blocking on warnings
must be able to restore the pre-#1407 strictness through the TDD profile —
the tdd plugin's existing machine-readable configuration surface at
`.specify/memory/tdd-profile.md` — without code changes. The default for
every project that does not opt in is errors-only.

**Why this priority**: Backward compatibility is a safety net, not the
product. The issue itself calls warnings-blocking "unusual but possible";
the default must be the fix, with the opt-in as the documented escape
hatch.

**Independent Test**: A profile whose machine-readable Keys block carries
`analyze-gate: warnings-blocking` reproduces the pre-#1407 behavior
(the warnings-only refusal reaches the per-behavior guard and a passing
target test yields `green-with-failed-build`); a profile without the key —
or with `analyze-gate: errors-only` — gets the default errors-only gate.

**Acceptance Scenarios**:

1. **Given** a profile whose Keys block carries
   `analyze-gate: warnings-blocking`, **When** a make hits the
   warnings-only gate refusal with the target test passing, **Then** the
   pre-#1407 grading applies: the refusal reaches the per-behavior guard
   and the make records `outcome=green-with-failed-build`, exit 0
   **Type**: acceptance
2. **Given** a profile without an `analyze-gate` key, **When** a make
   runs under a warnings-only refusal, **Then** the default errors-only
   gate applies (US1 behavior) **Type**: acceptance
3. **Given** a profile carrying `analyze-gate: errors-only` explicitly,
   **When** a make runs under a warnings-only refusal, **Then** the
   errors-only gate applies (identical to the absent-key default)
   **Type**: acceptance

---

### Edge Cases

- What happens when the build step fails for a reason OTHER than the
  analyze gate (build_runner failure, missing builder dependency, DDA
  route failure) while analyzer warnings happen to appear in its output?
  The gate must not engage: the existing #737/#942/#1322 grading paths run
  unchanged. The gate engages only on the build command's own
  analyze-gate refusal verdict naming 0 errors. **Type**: unit
- What happens when the gate message claims 0 errors but the raw build
  output carries analyzer `error -` lines the shared parser counts? The
  shared parser wins (safe-failure): the gate does not engage and the
  honest #942 stop stands. **Type**: unit
- What happens when the warnings-only refusal fires for a behavior whose
  make plan failed at a NON-terminal step or a non-build step? The gate
  does not engage — the same terminal-build-step precondition the #737
  tolerance uses keeps the gate per-behavior by construction. **Type**:
  unit
- What happens when the profile file is missing or unreadable? The
  default errors-only gate applies (fail-open to the fix, never to the
  legacy strictness). **Type**: unit
- What happens when the analyzer reports many warnings (dozens)? The gate
  logs a capped sample of the warning lines plus a remainder count — the
  transcript stays readable. **Type**: unit

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The make's analyze-gate grading MUST treat analyzer warnings
  as non-blocking: a terminal `build` step refused by the analyze gate
  with 0 error(s) and ≥1 warning(s) MUST NOT cause `outcome=green-with-
  failed-build` nor `outcome=generation-error` when the behavior's own
  target test passes after generation; the make MUST proceed through its
  normal flow and complete `outcome=green`.
- **FR-002**: The make MUST log the warnings on the non-blocking path: the
  verdict line naming the counts and the issue #1407 policy, plus the
  analyzer `warning -` lines (capped sample with a remainder count when
  voluminous).
- **FR-003**: Only analyzer ERRORS may stop the make: a build step whose
  analyze verdict carries ≥1 error MUST keep the existing #942 refusal
  (the per-behavior guard refuses, `outcome=generation-error`, no green
  entry) byte-identically.
- **FR-004**: The gate MUST apply the same strictness to all lanes and
  transitions in the same run: the errors-only grading lives in the one
  shared make flow (engine lane, skin lane, composition lane), and the
  #694 skip transition's effective warning strictness (the gate never
  runs) matches the normal transition's (warnings never block).
- **FR-005**: A project MUST be able to opt into the legacy
  warnings-blocking strictness via the TDD profile's machine-readable
  Keys block (`analyze-gate: warnings-blocking`); the default — absent
  key, explicit `analyze-gate: errors-only`, unrecognized value, or
  missing/unreadable profile — MUST be errors-only.
- **FR-006**: The fix MUST NOT change the core engine cycle, the
  verify-red logic, the gen pipeline (PipelineRunner), the dart analyze
  invocation, or what dart analyze reports — only how the make interprets
  the build step's analyze verdict. The gate's scope precondition is the
  same terminal-build-step shape the #737 per-behavior guard uses.

### Success Criteria *(measurable)*

- **SC-001**: A warnings-only gate refusal (0 errors + 1 warning) with a
  passing target test completes `outcome=green`, exit 0, green evidence
  appended — proved by an automated test against the real CLI surface
  (`zfa tdd make`).
- **SC-002**: The same refusal with a failing target test completes
  `outcome=generation-error`, exit 1, no green entry, subject restored —
  proved by an automated test.
- **SC-003**: A build verdict carrying 1 error keeps the #942 refusal
  (`outcome=generation-error`, the `analyzer error(s)` note) — proved by
  an automated test.
- **SC-004**: Widget-lane and unit-lane makes under identical
  warnings-only refusals produce the same outcome token (`green`) and the
  same gate verdict line — proved by an automated test pair.
- **SC-005**: `analyze-gate: warnings-blocking` restores the pre-#1407
  grading (`green-with-failed-build` on a passing target test) — proved
  by an automated test; absent-key and explicit `errors-only` profiles
  behave identically to SC-001.
- **SC-006**: The existing #737/#942/#1322 test pins keep passing (no
  regression in the tolerance family), and `dart analyze` on the changed
  files reports 0 errors and 0 warnings.
