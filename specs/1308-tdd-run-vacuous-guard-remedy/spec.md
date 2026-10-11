**Template Version**: `zuraffa-1.0`

# Spec: 1308-tdd-run-vacuous-guard-remedy

## Summary

`zfa tdd run <feature>` stops hard at the first UNIT behavior whose generated
test is the bare `UnimplementedError` guard. `make` refuses green
(`outcome=vacuous-green`, the issue #1259 remediation) — but it was
`zfa tdd gen` itself, one step earlier in the same run, that emitted the
vacuous test. The run output gives no actionable remedy, so the two-cycle
driver dead-ends. This feature surfaces the vacuous-green REMEDY in the
run/stop messages and at gen time, without changing the engine cycle, the
verify gate semantics, or the contract scanner.

## Acceptance Scenarios

1. **Given** a fallback-routed UNIT behavior (no `traces:` line to a declared
   contract row) whose generated test is the bare UnimplementedError guard
   **When** `zfa tdd run` stops at that behavior's `make` step with
   `outcome=vacuous-green` **Then** the stop message prescribes the exact
   remedy: `add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run
   zfa tdd gen, re-run zfa tdd run` (the generic resume-only guidance is
   replaced by this actionable guidance; the summary line keeps the machine
   contract `stopped_at=<id>:make` for the fallback path).
2. **Given** `zfa tdd gen` emits a guard-only test (no real outcome
   assertion) for a fallback-routed behavior **When** the gen step completes
   (it does NOT fail — the test is still emitted) **Then** gen emits a loud
   warning naming the gap (no `traces:` line derives a real outcome
   assertion) and prescribing the same remedy, and `zfa tdd run` forwards the
   warning lines into the run transcript so the warning is impossible to
   miss in the run output.
3. **Given** a behavior whose traced contract row returns `void` or an entity
   type (the generated test carries the `zfa:tdd: vacuous-guard` marker)
   **When** `zfa tdd run` stops at that behavior's `make` step with
   `outcome=vacuous-green` **Then** the run driver surfaces the
   `vacuousGuardMarker` as the DESIGNED hand-delta seam — one explicit, named
   hand step in the journal (`stopped_at=<id>:hand` replaces the generic
   `stopped_at=<id>:make`) — telling the user exactly what to write (an
   assertion on the observable outcome) and where (the generated test file
   path), and the journal entry names the hand step.
4. **Given** existing specs whose `traces:` lines already derive real outcome
   assertions (scalar declared returns) or whose prose matches the
   `returns N` / `throws X` heuristics **When** the suite runs
   **Then** behavior is unchanged: no new warnings, no new stop-message
   text — the new warnings/stop messages fire ONLY on the fallback path (no
   traces) or on the entity/void-returning traced path.

## Functional Requirements

- **FR-001**: When the run driver stops on a `make` step whose outcome is
  `vacuous-green` for a behavior whose generated test does NOT carry the
  `zfa:tdd: vacuous-guard` marker (the fallback path: guard emitted without
  a traced contract row), the stop message MUST prescribe the exact remedy:
  `add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd
  gen, re-run zfa tdd run`.
- **FR-002**: When `zfa tdd gen` writes a guard-only unit test for a
  fallback-routed behavior (no contract shape; prose heuristics did not
  match), gen MUST emit a loud warning naming the gap and prescribing the
  FR-001 remedy. The generated test is still emitted; gen's exit code is
  unaffected (the gen step does not fail).
- **FR-003**: The run driver MUST forward the gen-time guard-only warning
  into the run transcript (the run captures the gen child's output; a
  successful gen prints nothing of it today), so the warning is impossible
  to miss in the run output.
- **FR-004**: When the run driver stops on a `make` step whose outcome is
  `vacuous-green` for a behavior whose generated test CARRIES the
  `zfa:tdd: vacuous-guard` marker (the traced entity/void path), the driver
  MUST surface the marker as the designed hand-delta seam: the stop is
  reported as the named hand step `stopped_at=<id>:hand` (replacing the
  generic `stopped_at=<id>:make` in the summary line and the journal), the
  stop message names what to write (an assertion on the observable outcome)
  and where (the generated test file), and the journal entry carries a
  hand-step violation naming the same guidance.
- **FR-005**: The remedy vocabulary (the exact remedy string, the warning
  token, the marker test) lives in the messaging layer (`vacuous_guard.dart`)
  so gen, the writer, and the run driver share one source — no drift.
- **FR-006**: Hard constraints preserved: the core engine cycle, the verify
  gate semantics, and the contract scanner are unchanged; the generated test
  shape is unchanged (the guard is still emitted when appropriate — the fix
  is about surfacing the right guidance); `make`'s vacuous-green refusal
  semantics are unchanged (issue #1259 stands).

## Success Criteria

- **SC-1**: A fallback-routed vacuous-green run stop prints the exact
  FR-001 remedy string (grep-able verbatim) and keeps the summary machine
  contract `stopped_at=<id>:make`.
- **SC-2**: A guard-only fallback gen emits the warning (named token +
  remedy) AND still writes the test file AND exits 0; a scalar-contract gen,
  a prose-matched gen, and a traced-entity gen emit NO fallback warning.
- **SC-3**: A marker-carrying vacuous-green run stop reports
  `stopped_at=<id>:hand` in the summary line and the journal entry, with a
  journal violation naming what to write and where.
- **SC-4**: The existing #1259 vacuous-green refusal suite and the run
  driver suites pass unchanged (no behavioral regression on the guarded
  paths).
