**Template Version**: `zuraffa-1.0`

# Spec: 991-non-scalar-param-hand-delta-seam

## Overview

A declared Layer Contract row with a non-scalar parameter type (e.g.
`StreamErrorHandler: reason(Object error) -> String`) makes `zfa tdd gen`
emit an `_argN()` placeholder helper whose body throws
`UnimplementedError('provide a representative argument for <target>
(declared param N: <type>)')`. The red is honest. But when `zfa tdd make`
runs its generation plan and the target test still fails, make reports the
generic `outcome=generation-error` ("target test still fails after
generation") — the stop output NEVER names the actual remedy. The remedy
(hand-editing a generated test to replace `_arg0()` with a representative
value) only exists inside a thrown exception message mid-test-output, and
it collides with the pipeline's own "refactor: never edit tests" rule.
This spec makes the designed hand-delta seam SURFACED: make recognizes the
`_argN()` placeholder as the failure cause and stops with
`hand-delta-required` naming the exact edit; and the common `Object` case
never dead-ends at all because `_scalarLiteral` generates a representative
value for it.

## Acceptance Scenarios

1. **Given** a certified-red unit behavior whose generated test carries an `_argN()` placeholder helper and whose post-generation target-test run fails with the placeholder's throw message in the transcript, **When** the user runs `zfa tdd make <behavior-id>`, **Then** make stops with `outcome=hand-delta-required` (exit 1, no green evidence appended) and the stop output names the EXACT edit: replace `_arg0()` in the generated test file with a representative `Object`, then re-run `zfa tdd make <behavior-id>`.
   **Type**: acceptance
2. **Given** the user applied the hand-edit (replaced `_argN()` with a representative value), **When** the user re-runs `zfa tdd make <behavior-id>`, **Then** make re-certifies red (or green) FROM THE UPDATED TEST via its drift check (the target test is re-run before generation — the pre-existing certified-red entry never skips that verification), and the cycle proceeds to generation and green.
   **Type**: acceptance
3. **Given** a declared contract param of type `Object`, **When** `zfa tdd gen` writes the paired unit test, **Then** `_scalarLiteral` covers `Object` and the generated capture site passes `Object()` as the representative argument — no `_argN()` placeholder helper is emitted for an `Object`-typed param, so the common case never dead-ends into the hand-delta seam.
   **Type**: acceptance
4. **Given** scalar-typed contract params (`String`, `int`, `num`, `bool`, `double`), **When** `zfa tdd gen` writes the paired unit test, **Then** the representative literals are unchanged (`'sample'`, `0`, `false`, `0.0`) — backward compatibility is preserved.
   **Type**: acceptance
5. **Given** a run-driver lane driving a behavior whose make stops with `outcome=hand-delta-required`, **When** the run stops, **Then** the run reports the named hand step `stopped_at=<id>:hand` (the issue #1308 hand-step contract) and the remedy line names the exact edit — the generic `stopped_at=<id>:make` stop is reserved for genuinely unknown failures.
   **Type**: acceptance

## Functional Requirements

- **FR-001**: `zfa tdd make` MUST detect the `_argN()` placeholder as the
  cause of a still-failing target test after generation. Detection is
  two-signal: (a) the generated test file carries the named marker helper
  (`_argN() => throw UnimplementedError('provide a representative
  argument for ...')`), and (b) the failing run transcript carries the
  placeholder's message token ("provide a representative argument for").
  Both signals must agree before the hand-delta diagnosis is reported.
- **FR-002**: When the `_argN()` placeholder is diagnosed, make MUST stop
  with `outcome=hand-delta-required`, exit non-zero, append no green
  evidence, and restore the subject byte-identically (the existing
  failed-make contract, issue #1036). The stop output MUST name the exact
  edit: the placeholder identifier (`_arg0()`), the test file path
  (project-relative), the declared type of the parameter, and the re-run
  command (`then re-run zfa tdd make <behavior-id>`).
- **FR-003**: The hand-delta seam (`outcome=hand-delta-required`) MUST
  remain an escape hatch for truly un-schematicable types: entity-typed
  and other non-scalar params keep the `_argN()` placeholder generation
  path unchanged. The fix surfaces the seam; it does not eliminate it.
- **FR-004**: `_scalarLiteral` in the behavior test writer MUST cover
  `Object` with the representative expression `Object()`, so an
  `Object`-typed declared param generates a real argument at the capture
  site and never emits an `_argN()` placeholder.
- **FR-005**: After the hand-edit, re-running make MUST re-verify the
  updated test (the drift check re-runs the target test before
  generation) and MUST NOT skip that verification because the cycle-log
  already holds a certified-red entry for the behavior.
- **FR-006**: The run driver MUST treat a `hand-delta-required` make stop
  as the named hand step (`stopped_at=<id>:hand`) with the remedy in the
  stop output and the lane journal — messaging parity with the issue
  #1308 vacuous-green hand step. The state advance and honest-stop
  semantics stay the generic ones.
- **FR-007**: Scalar-typed contract params continue to work unchanged —
  the `String`/`int`/`num`/`bool`/`double` representative literals and
  all existing outcomes (`green`, `skipped`, `generation-error`, ...)
  keep their current semantics.

## Success Criteria

- SC-1: A make run on a still-failing `_argN()` test stops with
  `outcome=hand-delta-required` (never the generic `generation-error`)
  and the remedy names the exact edit (AC1).
- SC-2: A make re-run after the hand-edit re-certifies from the updated
  test and completes green (AC2) — proven by a test that hand-edits the
  generated test between two make invocations.
- SC-3: An `Object`-typed contract param generates `Object()` at the
  capture site — no `_argN()` helper in the generated test (AC3).
- SC-4: The scalar literals are byte-identical to the pre-change
  behavior (AC4).
- SC-5: The run driver reports `stopped_at=<id>:hand` with the remedy
  for a `hand-delta-required` make stop (AC5).

## Out of Scope

- The core engine cycle, the contract scanner, the gen pipeline, and the
  verify gate semantics are unchanged (hard constraint).
- No new representative-value inference for entity-typed params (the
  `Object?` degradation and the `_argN()` seam for them stand).
- No change to the `Never`/`dynamic` param handling.
