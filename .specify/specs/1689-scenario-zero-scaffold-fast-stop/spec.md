**Template Version**: `zuraffa-1.0`

# Spec: 1689-scenario-zero-scaffold-fast-stop

## Overview

On a unit behavior whose generated test carries a scenario-derived
assertion (post-#1679, e.g. `expect(subject.subject_u1(2, 3),
equals(5))`), make's func pass still scaffolds a #1517 zero-value dummy
(`return 0;`-class body), then runs the target test, watches it fail,
restores the certified-red stub, and stops `generation-error`. The
30–40s attempt (func write + target `dart test` compile/run + restore)
is **provably wasted work**: a zero-value scaffold can never satisfy an
`equals(<scenario literal ≠ zero>)` assertion, and the func pass
currently has no path to a smarter body.

Observed on the zcalc3 probe (master 8e6346e5, 2026-09-17):

```
[run] U1 make — generation pipeline
[run] U1 make … 30s elapsed
[run] U1 make -> generation-error
   → func
   target test exit: 1
   make: target test still fails after generation
```

Cycle-log span for that make: **37.5s** (`U1 error at 17:18:52`). The
recovery the stop prescribes is the hand step — which is where the flow
was always going to end for this behavior class.

The #1679 flow makes scenaried unit behaviors the COMMON case (any FR
whose spec row has concrete Given/When/Then values gets a real
assertion — verified: U1 derived `subject_u1(2, 3)` / `equals(5)`). For
every one of those behaviors, the current make spends ~37s discovering
that its own scaffold cannot pass its own test. On a zik_zak-scale
feature set (dozens of scenaried FRs per feature) this is
dozens of guaranteed-wasted attempts per feature, each scaling with
target-compile time.

Scope guard (hard constraints from the issue): the fix touches ONLY the
pre-flight gate in the make pipeline. The #1679 scenario derivation and
the #1517 zero-scaffold semantics are untouched. One PR per spec. The
fix must: (1) detect the scenario-assertion × zero-scaffold
intersection BEFORE the attempt, (2) stop with the same honest
hand-step remedy, (3) not skip attempts for non-scenaried behaviors,
and (4) remain correct when func grows real generation (the gate
self-removes: it keys on the scaffold being a zero-value literal, so it
goes silent with no code change once that stops being true).

## Acceptance Scenarios

1. **Given** a certified-red unit behavior whose plan schedules a func
   step, whose subject is gen's parametrized scalar stub (the shape
   func rewrites), and whose paired test asserts a scenario-derived
   concrete outcome that differs from the scaffold's dummy literal
   (`int` return → `return 0;` vs `equals(5)`), **When** `zfa tdd make
   <id>` finalizes its plan, **Then** the make stops BEFORE the
   pipeline — no `tdd func` subprocess is spawned (absent from the zfa
   argv log), no post-generation target test runs, the stop names the
   intersection and the single-sourced hand-step remedy, the subject
   survives byte-identical (#1036 contract), no green evidence is
   appended, and the summary line grades the stop with its own
   `would-never-pass` outcome (exit 1) — the same honest stop the
   post-generation failure prescribed, minus the ~37s.
   **Type**: acceptance
2. **Given** the same pair but the test's value assertion names the
   scaffold's own dummy literal (`equals(0)` for an `int` return,
   `equals(true)` for `bool`, `equals(0.0)` for `double`, the subject
   function's own name for `String`), **When** `zfa tdd make <id>`
   runs, **Then** the gate stays SILENT — the attempt proceeds exactly
   as before (the scaffold may legitimately satisfy that assertion; the
   engine's existing gates own whatever the attempt certifies).
   **Type**: acceptance
3. **Given** a non-scenaried unit behavior (guard-only, or the
   type-only + marker shape), **When** `zfa tdd make <id>` runs,
   **Then** nothing changes: the vacuous-green preflight (#1259/#1488)
   and the placeholder refusal (#1651) refuse fast exactly as today,
   and no attempt is ever skipped by the new gate (their assertion sets
   carry no `equals(<literal>)` value assertion).
   **Type**: acceptance
4. **Given** a unit behavior whose subject is NOT gen's stub (a real
   implementation, a hand-authored body, or the contract-derived
   entity-typed stub func skips per #1565), **When** `zfa tdd make
   <id>` runs, **Then** the gate is silent — the drift check, the plan,
   and the pipeline run exactly as today (fail-open on every foreign or
   unreadable shape; the gate never refuses on absence of evidence).
   **Type**: acceptance
5. **Given** a real implementation with a discriminating scenario test,
   **When** `zfa tdd make <id>` runs, **Then** the unchanged paths
   certify green as today (the drift check's skip transition, #694) —
   the gate never touches a behavior the func pass would not scaffold.
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The make MUST pre-flight the plan's func step: when the
  behavior's test-list row is unit-kind, the plan schedules `tdd func`
  (and did not skip it per #1565), the on-disk subject is gen's
  provenance-marked parametrized stub whose declared return type is in
  the #1517 literal-dummy vocabulary (`int` → `0`, `double` → `0.0`,
  `bool` → `true`, `String` → the function's own name), and the paired
  test carries a value assertion (`equals(<literal>)`) whose literal
  provably differs from that dummy, the make MUST stop before executing
  the plan. The stop MUST print the diagnosis naming issue #1689, the
  scaffold's dummy, the declared return type, and the offending
  assertion literal, plus the single-sourced `--> fix:` hand-step
  remedy. Fail-open: a missing/unreadable subject or test, a
  non-matching stub shape, a nullable/`void`/`num`/entity declared
  return (the still-red UnimplementedError scaffold, not a zero value),
  a legacy no-arg stub, or an unparseable assertion literal keeps the
  attempt running exactly as today — the gate never refuses on absence
  of evidence.
- **FR-002**: The fast stop MUST grade its own outcome —
  `make: behavior=<id> outcome=would-never-pass feature=<f>` — exit 1,
  no green entry, and it MUST flow through the same every-exit-path
  summary funnel (#1398) and verdict envelope as every other stop. The
  run driver's generic make-failure arm owns the loop semantics
  (unchanged): the make child's remedy excerpt is the recovery the
  operator sees.
- **FR-003**: The gate predicate and the remedy MUST be single-sourced
  in one service beside its sibling gates (the #1651
  `scalar_dummy_subject.dart` precedent) so the make stop and any later
  surface cannot drift. The predicate MUST reuse
  `SubjectProvenance.funcRewritableStubPattern` — the same pattern func
  matches — and MUST mirror `_declaredStubBody`'s literal vocabulary
  exactly (the writers' dummy set: `0`, `0.0`, `true`, `false`, a
  quoted string), so a prediction cannot disagree with what func would
  write.
- **FR-004**: The literal comparison MUST be value-aware: `0` and
  `0.0` compare equal numerically (an `int` dummy DOES satisfy
  `equals(0.0)` — Dart `num` equality), booleans and string contents
  compare by value, and mixed kinds compare unequal. A literal the
  comparator cannot parse is never treated as discriminating (safe
  direction: the attempt runs).
- **FR-005**: The gate MUST NOT change the #1679 scenario derivation,
  the #1517 zero-scaffold semantics, the #1565 plan-skip, the #1259/
  #1488/#1651 refusal gates, the drift check, the pipeline, or the
  run-loop state machine beyond the new outcome entry. Byte-for-byte
  machine contract untouched for every shape the gate stays silent on.
- **FR-006**: Self-removal (the issue's constraint 4): the gate keys on
  the scaffold being a zero-value literal of the declared return — when
  func grows real generation (a smarter body for scalar declared
  returns), the predicted dummy stops existing and the gate goes silent
  with NO code change in the gate.

## Success Criteria (measurable)

- **SC-001**: The e2e probe (fixture project, real `dart test`
  subprocesses, fake-zfa argv log): pre-fix, the scenaried make spawns
  `tdd func`, runs the post-generation target test, and stops
  `generation-error`; post-fix, the same make spawns NOTHING, stops
  `outcome=would-never-pass`, prints the #1689 diagnosis + remedy, and
  completes in a fraction of the pre-fix wall time (the doomed func
  write + target-test compile/run + restore never happen).
- **SC-002**: The pre-fix vs post-fix wall-time delta is printed by the
  probe run and recorded in `tdd/verification.md` (the measurable
  analogue of the zcalc3 37.5s span; the fixture's absolute time scales
  with its target-compile time).
- **SC-003**: Non-scenaried pins (guard-only, type-only+marker, real
  implementation) keep their exact pre-fix outcomes and spawn shapes
  (SC acceptance scenarios 2–5, green).
- **SC-004**: `dart analyze` on the changed files reports no issues;
  `dart format .` leaves zero diffs; the new service + command + enum
  changes pass their unit tests (predicate truth table) and the e2e
  probe.

## Non-Goals / Out of scope

- The `zfa tdd func` command and `_declaredStubBody` are untouched (the
  #1517 semantics stand; when func grows real generation the gate
  self-removes per FR-006).
- The #1679 scenario derivation, the test writer, and the scenario
  resolver are untouched.
- The UnimplementedError-scaffold class (nullable/`num`/entity declared
  returns) is NOT in scope — the issue's class is the zero-VALUE
  scaffold; a still-red scaffold failing a scenario assertion is a
  different (pre-existing) stop shape.
- The run driver gains no new stop arm: the generic make-failure arm
  already surfaces the make child's remedy excerpt, and the loop
  semantics (state advance, honest stop) are the generic ones — the
  same messaging-only relationship the #1308 contract documents.
- The #1651 boundary classes (a dummy satisfying a zero-matching value
  assertion) are unchanged.
