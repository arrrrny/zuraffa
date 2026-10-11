# Issue — #1512 tdd: acceptance lane is a vacuous composition seam

## Dogfood evidence

`zfa tdd run 001-todo-app` on a Flutter todo host (20 acceptance behaviors,
AC-1..AC-20): **every acceptance `make` step reports `unexpressible`**
(`generation_planner.dart` `_unexpressibleReason`: "no generator surface maps
the behavior description … to a `zfa entity create` / `zfa make` / `zfa build`
invocation"), and the acceptance test the lane *does* generate is structurally
vacuous — an empty subject body satisfies it.

## Root cause 1 — the acceptance invocation discards everything

`BehaviorTestWriter._captureInvocation` emits for acceptance kinds:

```dart
final Object? result = (() {
  try {
    subject.$target();          // ← no arguments threaded
    return null;                // ← return discarded
  } on UnimplementedError catch (error) {
    return error;
  }
})();
// sole assertion: expect(result, isNot(isA<UnimplementedError>()));
// result is ALWAYS null → passes for empty body
```

- **No arguments** — declared params from the acceptance row are not threaded.
- **Return discarded** — `return null;` unconditionally.
- **Sole assertion** passes for any subject that does not throw
  `UnimplementedError`, including an **empty body**. The red can never certify
  honestly and green certifies nothing.

Contrast the unit lane (same function): `return subject.$target($args);` +
contract-derived outcome assertions (issue #1259/#1498) — the unit lane
asserts ON the declared outcome surface. The acceptance lane asserts on
nothing.

## Root cause 2 — the planner declares acceptance `make` unexpressible

For acceptance rows — user-scenario compositions that should call through
presenter/controller → store and assert an observable outcome — there is today
no generator surface in the planner's prose ladder, so all 20 rows stop at
`make -> unexpressible` and the cycle can never reach green by construction.

## Why this matters

Acceptance criteria are the outer loop of TDD (the spec's "independently
testable increments"). As built, the acceptance lane can (a) never drive a
real red, and (b) never certify a real green — it is a placeholder that burns
~25 min re-driving every run (acceptance never reaches `done`, so `tdd run`
re-walks all acceptance behaviors before reaching units).

## Expected

1. Derive the invocation surface per acceptance row from declared contract
   rows (Layer Contracts + scenario literals).
2. Assert observable outcomes through the generated stack, mirroring the unit
   lane's contract-derived assertion (the #1259 shape: assert on the declared
   outcome, not the bare not-throw guard).
3. Give the planner a real `make` surface for acceptance rows — even if that
   surface is "compose the existing unit-level generated pieces" (the spec-052
   `tdd compose` lane) — so `unexpressible` becomes rare and honest, not the
   default for the whole lane.

## Hard constraints

- Fix ONLY the acceptance lane in `behavior_test_writer.dart` and
  `generation_planner.dart`. Do NOT change the unit lane, the state machine,
  or the loop semantics.
- Must not break existing unit lane contract-derived assertions.
- Must pass `dart analyze` with no new warnings.

## Related

- #1007 (contract lane) — same "assert on the declared surface" philosophy;
  the acceptance lane needs its composition analogue.
- #912 defect 3 (widget lane scaffolded refusal) — the marker-seam precedent.
- #1259 / #1308 (unit lane vacuous-green guard + remedy surfacing).
- #1504 — contract-lane import fix (same dogfood run).
- #642 / spec 052 — the composition fallback the planner surface names.
