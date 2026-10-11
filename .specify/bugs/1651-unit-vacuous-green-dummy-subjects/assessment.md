# Bug Assessment: engine lane certifies vacuous greens — unit subjects ship as `return 0;` dummies

- **Slug**: 1651-unit-vacuous-green-dummy-subjects
- **Created**: 2026-09-15T16:56:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1651
- **Verdict**: valid — reproduced by code inspection on master f011e3fb; the vacuous-green gate cannot see type-only assertions over scalar dummy bodies
- **Severity**: high (engine certifies `result=complete` on non-implementations)

## Report (verbatim or summarized)

Issue #1651 (follow-on to #1259): `zfa tdd run` certifies `result=complete done=10` on a zcalc probe while all four unit subjects are func-scaffolded dummies (`int subject_u1(int a, int b) { return 0; }`, `double subject_u4(int a, int b) { return 0.0; }`). The post-#1259 generated unit test calls the subject with scaffold representative arguments `(0, 0)` and asserts only `isA<int>()`. The func pass (#1517) rewrites the throwing stub to a scalar dummy, which satisfies the type assertion, so green is certified and terminal. Related: #1259 (original vacuous-green report), #1517 (scaffold dummy), #1488 (acceptance vacuous gate), #1565 (func contract-derived stub provenance), #1323 (arg placeholder two-signal detector).

## Symptom

Unit behaviors reach `state=done` / receipt `complete` although the paired subject implements nothing; the generated test's only real assertion is a return-type check that any scalar dummy satisfies.

## Reproduction

1. `zfa setup zcalc --dart` (fresh package)
2. Spec: Layer Contracts row `Calculator: add(int a, int b) -> int`, FRs tracing `Calculator.add`, acceptance Given/When/Then with concrete values (`Given the integers 2 and 3, When Calculator.add is called, Then the sum 5 is returned`).
3. `zfa tdd plan zcalc` → 10 behaviors (A1-A2, U1-U4, contract:A1-A4)
4. `zfa tdd run zcalc` with the designed hand steps for acceptance (#1488) and contract (#1007) seams
5. Run completes `result=complete pending=0 red=0 green=4 done=6`, final receipt `done=10`
6. `lib/tdd/zcalc/u{1..4}_subject.dart` are all scalar dummies.

## Suspected Code Paths (verified against working tree)

- **Type-only assertion source**: `lib/src/plugins/tdd/services/behavior_test_writer.dart`
  - `_deriveAssertion` (L347-418): the declared-contract branch (L351-353) short-circuits to `_declaredAssertion` **before** the prose `returns N` heuristic (L357-365), so a concrete scenario value never becomes an assertion.
  - `_declaredAssertion` (L429-442): emits `expect(result, isA<T>())` for scalar outcomes — type-only.
  - `_scalarLiteral` (L457-472): invents representative arguments (`int → 0`), never scenario values.
- **Dummy body writer**: `lib/src/plugins/tdd/commands/func_command.dart`
  - `_renderScaffolded` (L594-621) + `_declaredStubBody` (L629-641): scalar declared returns get literal dummies (`int → return 0;`, `double → return 0.0;`, `bool → return true;`, `String → return '<name>';`).
  - Nothing downstream consumes the #1517 scaffold marker (`Scaffolded dummy per \`zfa tdd func\``) to refuse green.
- **Green honesty gate (too narrow)**: `lib/src/plugins/tdd/commands/make_command.dart` step 3c (L1104-1180) refuses green only when `contentIsVacuousGreen(testContent)` (guard-only tests; `lib/src/plugins/tdd/services/vacuous_guard.dart` L375-379). `expect(result, isA<int>())` counts as a real assertion, so dummy-passing typed tests sail through.
- **Engine stop arms**: `lib/src/plugins/tdd/commands/run_driver_core.dart` vacuous-green arms (L2492-2615) and `_handStepViolationFor` (L3327-3387) have no placeholder-body arm.
- **Scenario parsing (wiring gap)**: `lib/src/plugins/tdd/services/spec_parser.dart`
  - `_extractScenarioText` (L1807-1816) keeps only the text after "Then" in `Behavior.description`; the Given/When clauses with the concrete example values are discarded at plan time. No structured Given/When/Then model exists.
  - `behavior.dart` (`Behavior`, L55-110) has no scenario field; the artifact registry record (`services/artifact_registry.dart`) carries only `descriptionSegment`.

## Root Cause Hypothesis

Two gaps compose: (1) the unit test generator ignores the spec's acceptance scenarios entirely — declared-contract shapes preempt the concrete-value heuristic and emit `isA<T>()` with scaffold arguments; (2) the engine's green gate has no notion of a placeholder subject body, so the #1517 func scaffold (`return 0;`) certifies green against a type-only assertion. #1259's fix added the type assertion but did not require the assertion to discriminate on the behavior's observable outcome.

## Proposed Remediation (hard constraints: fix unit test generation + func pass only; do NOT change acceptance lane, contract lane, or receipt format)

1. **Derive scenario-based assertions and arguments for unit behaviors** (`behavior_test_writer.dart`):
   - Extend behavior description handling so concrete scenario examples (Given/When/Then literals) are available to the unit writer at gen time; derive call arguments from the scenario (e.g. `2, 3`) and assert the concrete outcome (`expect(result, equals(5))`).
   - Keep `isA<T>()` strictly as fallback when no scenario value exists.
2. **Refuse terminal green for placeholder bodies**:
   - Add a scalar-dummy body detector single-sourced with the stub writers (func `_declaredStubBody`, wire `_defaultBodyFor`), following the `SubjectProvenance` / `arg_placeholder` idioms.
   - make step 3c: when the paired unit subject body is a detected scalar dummy and the test carries no scenario literal discriminating the outcome, refuse green (new outcome, e.g. `dummy-green`) with a fix remedy; add the matching stop arm + journal violation in `run_driver_core`.
3. Real (non-dummy) implementations must continue to certify green unchanged.

## Acceptance Criteria

1. Generated unit tests assert concrete scenario values (e.g. `subject_u1(2, 3)` → `5`), not just types.
2. `return 0;` dummies fail the generated test (assertion discriminates).
3. `zfa tdd run` refuses terminal green when unit subjects are placeholders.
4. Existing working unit subjects (real implementations) continue to certify green.

## Risks & Considerations

- `test/plugins/tdd/bug_1259_vacuous_green_test.dart` (U5) and `test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart` pin the current `isA<T>()` shape and will need updating to the new contract.
- Must not regress #1488 acceptance-lane behavior or #1565 provenance refusals; receipt schema stays schema-1.
- Scenario values must only be applied to unit behaviors (acceptance lane untouched).

## Open Questions

- None blocking — fix scope is confirmed by the issue's "Concrete asks" and "Hard constraints".
