# Assessment — #1512 acceptance lane is a vacuous composition seam

Date: 2026-09-11
Branch: `fix/1512-acceptance-vacuous-composition`
Scope: acceptance lane ONLY — `lib/src/plugins/tdd/services/behavior_test_writer.dart` + `lib/src/plugins/tdd/services/generation_planner.dart`.

## Evidence

`zfa tdd run 001-todo-app` on a Flutter todo host (20 acceptance behaviors, AC-1..AC-20): every acceptance `make` reports `unexpressible`, and the acceptance test the lane generates passes on an empty subject body.

## Root cause 1 — the acceptance invocation discards everything

`BehaviorTestWriter._captureInvocation` computes the shape-derived argument
expressions (`$args`) and then DISCARDS them for acceptance kinds, emitting:

```dart
final Object? result = (() {
  try {
    subject.$target();          // ← no arguments threaded
    return null;                // ← return discarded
  } on UnimplementedError catch (error) {
    return error;
  }
})();
```

with the sole assertion `expect(result, isNot(isA<UnimplementedError>()));`.
Because the capture returns `null` unconditionally, the assertion passes for
ANY non-throwing subject — including an empty body. The unit lane (same
function, `return subject.$target($args);` + `_declaredAssertion`) asserts ON
the declared outcome surface; the acceptance lane asserts on nothing.

## Root cause 2 — the planner's default for acceptance rows is unexpressible

`GenerationPlanner.plan()` routes acceptance rows through the prose branches
only: entity prose (branch 1.5), CRUD prose with its #758 acceptance sub-gate
(branch 2), and function-intent verbs (branch 3). A user-scenario acceptance
row that names none of those keywords falls to branch 4 — `_unexpressibleReason`:
"no generator surface maps … to a `zfa entity create` / `zfa make` / `zfa
build` invocation". All 20 dogfood rows stop there; the make composition
fallback (#642) then needs composable anchors that a pure acceptance feature
never has, so the cycle can never reach done by construction.

## Compile-safety constraint (discovered during assessment)

The acceptance subject lifecycle keeps a `void <name>()` signature end to end:
the gen stub (`SubjectWriter` acceptance branch), the wired subject
(`wire_command._stubSignature` preserves `void`), and the composed subject
(`compose_command` preserves the stub's return type). Dart forbids using a
void expression as a value (`use_of_void_result` — verified with the Dart
3.13 analyzer), so `return subject.$target($args);` is ILLEGAL against the
shipped void stub. The acceptance capture can thread arguments and return the
result ONLY when a declared `UnitContractShape` supplies a non-void renderable
return (the surface the declared contract implies); undeclared rows keep the
void-safe call form and their vacuity is named by the designed hand-delta seam
(the #1259 `vacuousGuardMarker` comment) instead of staying silent.

## Remediation (implemented on this branch)

1. `_captureInvocation` — acceptance kinds thread the declared `$args` and
   return the subject's result when the declared shape carries a non-void
   renderable return (mirroring the unit lane's capture, issue #1259/#1035
   lint rules included); void-safe otherwise (args still threaded when
   declared).
2. `_deriveAssertion` — the undeclared acceptance bare-guard fallback emits
   the `vacuousGuardComment` (the machine-greppable marker + remedy), so an
   acceptance test whose assertion set is only the guard is never silently
   vacuous; `contentIsVacuousGreen` refuses it mechanically.
3. `GenerationPlanner.plan()` — new acceptance composition branch BEFORE the
   generic misfire: an entity name derivable from the row (explicit target,
   `create <Name>`/`entity <Name>` prose, or the #758/#873 capitalized-trace
   extractor) routes to the #609/#610/#758 entity pipeline (entity create →
   make → tdd wire → build); every other acceptance row routes to the
   spec-052 composition lane (`tdd compose <id> --feature <f>` → build — the
   issue's sanctioned "compose the existing unit-level generated pieces"
   surface). `unexpressible` stops being the lane default; the honest #758
   refusal (CRUD prose, no entity named) stays.

## Out of scope (hard constraints)

- The unit lane (byte-for-byte unchanged; pinned by existing #1035/#1259 tests).
- The state machine and run-loop semantics (no run_driver/make_command edits).
- SubjectWriter/gen_command (the acceptance subject stays the void scenario
  runner; declared-shape subject rendering is the #1498/#1500 direction).
