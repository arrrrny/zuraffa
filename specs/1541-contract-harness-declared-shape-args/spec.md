**Template Version**: `zuraffa-1.0`

# Spec: 1541-contract-harness-declared-shape-args

## Summary

The contract lane harness (issue #1007's `ContractTestWriter` scaffold)
invokes the contract seam with a bare `null` for every `dynamic`-typed
declared parameter (`_representativeArg` maps `dynamic` and the empty type
to the literal `null`). An argument-validating implementation wired to the
seam — the issue's example is
`Logger logger(dynamic subsystem) => AgentLog.logger(subsystem as String)` —
rejects that scaffold argument: the cast throws `TypeError` ("type 'Null' is
not a subtype of type 'String' in type cast") and a validating
implementation throws `ArgumentError` for invalid names. The emitted
`_captured` helper catches ONLY `UnimplementedError`, so the error escapes
the assertion surface into the runner transcript as an uncaught error.
verify-red's batch classifier grades a failing segment WITHOUT the
`Expected:` / `Actual:` / `TestFailure` assertion signature as
`runner-error` — never a named contract verdict — and the contract cannot be
satisfied by ANY argument-validating implementation (the cycle is stuck in
`runner-error` instead of BLOCKED or satisfied). This feature fixes the
contract test harness ONLY: (1) the scaffold invokes the seam with a
DECLARED-SHAPE representative argument — `dynamic`/empty-typed params get
the unit lane's `provide a representative argument` placeholder seam
(`_argN()`, whose `UnimplementedError` the capture catches) instead of a
bare `null`; (2) `_captured` catches ALL errors — `UnimplementedError` keeps
driving the BLOCKED verdict through the Case 2 assertion, any OTHER captured
error (an `ArgumentError`, `TypeError`, ...) proves the seam is implemented
and validating: the Case 2 assertion passes and the return-type case (when
present) is guarded, recording the outcome as satisfied-with-rejection
instead of escaping uncaught; (3) an argument-validating contract can be
satisfied without shimming the seam. The verify-red classifier, the BLOCKED
verdict, the contract-blocked receipt, and the run driver's state machine
are NOT changed.

## Acceptance Scenarios

1. **Given** a contract behavior whose declared parameter list carries a
   `dynamic`-typed parameter (`ContractDeclaration.parse` resolves it — e.g.
   `Logger.logger(dynamic subsystem) -> Logger`) **When** `zfa tdd gen`
   renders the contract test scaffold **Then** the Case 2 invocation passes
   the unit-lane placeholder seam `_arg0()` as that parameter's argument
   (never the bare literal `null`), the placeholder helper throws
   `UnimplementedError` with a `provide a representative argument`
   instruction naming the declared type and the contract, and the scaffold's
   SCAFFOLD PLACEHOLDERS comment block lists the parameter as one the author
   replaces with a representative value.
2. **Given** the scaffold's `_captured` helper **When** the invoked seam
   throws ANY error (an `ArgumentError` from a validating implementation, a
   `TypeError` from a cast, any other `Error` or `Exception`, or completes
   normally) **Then** the helper returns the error object (or the value) as
   the assertion's actual value instead of letting the error escape uncaught
   — the test body fails, when it fails, through an EXPECT/assertion whose
   transcript segment carries the assertion signature, never through an
   uncaught runner error.
3. **Given** an argument-validating implementation wired to the seam (it
   throws `ArgumentError` for the scaffold's representative argument)
   **When** the contract test executes against the real runner **Then** the
   Case 2 assertion PASSES (the captured `ArgumentError` is not an
   `UnimplementedError` — the seam is implemented), the return-type case
   (when the declared return is a non-nullable scalar) is guarded and does
   NOT run against a captured rejection, the test PASSES
   (satisfied-with-rejection), and verify-red grades it out of the blocked
   class (`classification=unexpected-green`) — the contract is satisfied
   WITHOUT shimming the seam.
4. **Given** a deliberately unimplemented contract seam (the stub throws
   `UnimplementedError`) **When** the contract test executes and verify-red
   grades it **Then** the verdict is unchanged — the captured
   `UnimplementedError` fails the Case 2 assertion and the classification is
   `blocked` with the `contract-blocked.<id>.json` receipt — and a
   non-validating implementation that returns a value of the declared scalar
   return type still passes the return-type case normally (the guard only
   skips the type assertion when the captured outcome is a rejection).
5. **Given** the #1513 golden pin (the pure-Dart default render is
   byte-compared against the committed baseline) **When** the template's
   captured-error handling changes **Then** the committed golden fixture is
   regenerated IN THE SAME CHANGE from the new writer output so the pin
   continues to guard against UNINTENDED render drift.

## Functional Requirements

- **FR-001** (declared-shape representative argument): The contract test
  writer's representative-argument resolver MUST NOT emit the bare literal
  `null` for a `dynamic`-typed (or empty-typed) declared parameter. Such
  parameters MUST resolve to the same `_argN()` scaffold placeholder seam
  the writer already emits for non-renderable complex types, whose
  `UnimplementedError` message instructs the author to provide a
  representative argument for the contract test (naming the declared type
  and the qualified method), matching the unit lane's
  `provide a representative argument` stub discipline.
- **FR-002** (capture catches all errors): The `_captured` helper the
  contract test template emits MUST capture every error the invocation can
  throw (`on Object`) — `ArgumentError`, `TypeError`, `StateError`, any
  other `Error` or `Exception` — returning the thrown object as the
  assertion's actual value. Only a NORMAL return value or a captured error
  object reaches the assertions; no thrown error escapes the test body as
  an uncaught runner error.
- **FR-003** (BLOCKED unchanged for unimplemented seams): A captured
  `UnimplementedError` MUST keep driving the existing BLOCKED verdict path:
  the Case 2 assertion `isNot(isA<UnimplementedError>())` (its text, its
  reason, and its position) is unchanged, so an unimplemented seam still
  fails through an assertion and verify-red still grades `blocked` with the
  contract-blocked receipt.
- **FR-004** (satisfied-with-rejection): A captured error that is NOT an
  `UnimplementedError` MUST pass the Case 2 assertion (the implementation is
  real — it validated and rejected the scaffold argument), and when the
  declared return type has a return-type case (Case 3, non-nullable scalar
  returns) the template MUST guard that case so the type assertion runs only
  when the captured outcome is NOT a rejection — the test then passes and
  verify-red grades it out of the blocked class (satisfied-with-rejection).
  The scaffold comments name the rejection semantics (issue #1541) so the
  author reads what happened, not a silent skip.
- **FR-005** (scope — harness only): The fix MUST NOT change the verify-red
  batch classifier, the blocked verdict, the contract-blocked receipt shape,
  the run driver's state machine, the contract SEAM template
  (`ContractSubjectWriter`), the unit/acceptance lanes, or the golden
  harness writer's own capture helper. The dart analyze issue count MUST
  NOT grow.
- **FR-006** (golden regeneration): The committed #1513 golden fixture MUST
  be regenerated from the updated writer so its byte-comparison pin stays
  green, and the fixture's `int`-parameter render (unaffected by FR-001)
  keeps proving the default render's stability.

## Success Criteria

- **SC-1**: Rendering a contract behavior with a `dynamic` parameter
  (`Logger.logger(dynamic subsystem) -> Logger`, any category) produces a
  test body whose Case 2 invocation is `impl(_arg0())` and which contains
  NO `impl(null)`; the placeholder helper and the SCAFFOLD PLACEHOLDERS
  comment name the declared type `dynamic`.
- **SC-2**: Rendering any parseable contract emits a `_captured` helper that
  catches all errors (an `on Object` catch arm); the emitted test for an
  argument-validating implementation executes to a PASS against the real
  runner (exit 0), and verify-red grades `classification=unexpected-green`
  — no transcript segment for the contract test is ever classified
  `runner-error` from an uncaught scaffold-argument rejection.
- **SC-3**: The slow-tier e2e (real `dart test` subprocess) proves the
  unimplemented seam STILL grades `classification=blocked` with the
  contract-blocked receipt (FR-003) and the implemented-but-rejecting seam
  grades `classification=unexpected-green` (FR-004) — both through the
  existing verify-red path, with no changes to verify-red or the driver.
- **SC-4**: The full fast-tier suite passes with no new failures (the
  #1007 fast-tier pins — `Case 1 of 3` / `Case 2 of 3` / `Case 3 of 3`,
  `isNot(isA<UnimplementedError>())`, one test per behavior — unchanged for
  scalar-typed contracts), and `dart analyze lib test bin` reports no NEW
  issues against the pre-change baseline.
- **SC-5**: The regenerated #1513 golden fixture matches the new default
  render byte for byte, and the byte-comparison test passes.

## Assumptions

- The `dynamic` parameter's real declared shape is unrecoverable at render
  time (the plan description carries `dynamic` verbatim), so the scaffold
  asks the author for a representative value — the same remedy the unit
  lane already uses for non-schematicable types; this is the declared
  contract of FR-001, not a limitation to be fixed later.
- A captured non-`UnimplementedError` rejection counts as
  satisfied-with-rejection because the contract lane's Case 2 semantics
  already declare the outcome space binary (an `UnimplementedError` = the
  contract unsatisfied; anything else = the implementation is real) — the
  harness only stops that outcome from escaping as an uncaught error.
- `void`-return seams, nullable complex types, and the unparseable-contract
  refusal shape are unaffected (the seam renders `Object?` for `void` per
  issue #1443; nullable complex types already resolve to `null`
  legitimately — the declared shape IS nullable).
- The unit lane's own capture helper (behavior_test_writer) and the golden
  harness writer's capture helper are separate surfaces with separate
  pinning suites; this feature deliberately leaves both untouched.
