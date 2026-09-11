# Fix: acceptance lane — thread args, assert declared outcomes, real make
# surface (#1512)

- **Slug**: 1512-acceptance-vacuous-composition
- **Files changed (hard constraint: acceptance lane ONLY)**:
  - `lib/src/plugins/tdd/services/behavior_test_writer.dart`
  - `lib/src/plugins/tdd/services/generation_planner.dart`
- **Unit lane**: byte-for-byte unchanged (pinned by A-1512-d1/d2 and the
  pre-existing #1035/#1259 suites).
- **State machine / loop semantics**: no run_driver / make_command /
  subject_writer / gen_command edits.

## Change 1 — `BehaviorTestWriter._captureInvocation` (root cause 1)

The acceptance capture previously emitted `subject.$target(); return null;`
unconditionally — the shape-derived `$args` were computed and discarded, the
subject's return was discarded, and the sole assertion passed for any
non-throwing subject (an empty body). Now:

- **Declared non-void renderable return** (`shape != null`,
  `shape.returnType != 'void'`, `isRenderableDartType`): the acceptance
  capture mirrors the unit lane exactly — `final result` (inferred, the
  #1035 lint rule) + `return subject.$target($args);` with the declared
  argument expressions threaded. The capture can then carry the subject's
  actual result, so the `_declaredAssertion` surface (`isA<T>()` for scalar
  outcomes, the marker seam for entity outcomes) is satisfiable for real.
- **Undeclared / void-declared acceptance rows**: the capture stays
  VOID-SAFE — `final Object? result` + a statement call with declared args
  threaded when a shape supplies them + `return null;`. Dart forbids using
  a void expression as a value (`use_of_void_result`, verified with the
  analyzer), and the acceptance subject's generated lifecycle (gen stub →
  `tdd wire` → `tdd compose`) keeps a `void <name>()` scenario-runner
  signature, so emitting `return subject.$target($args);` unconditionally
  would break the pair's compile at RED time. Vacuity for these rows is
  named instead of silently kept (Change 2).

## Change 2 — `BehaviorTestWriter._deriveAssertion` fallback (root cause 1)

The undeclared acceptance fallback's assertion set was the bare
`expect(result, isNot(isA<UnimplementedError>()));` with NO marker — the
structurally vacuous shape. The acceptance branch now emits the designed
hand-delta seam (the #1259 `vacuousGuardComment` + marker) before the guard,
so:

- the artifact names the vacuity and the exact remedy (never silent);
- the shared `contentIsVacuousGreen` detector refuses it mechanically
  (the `--born-green` gate, which is kind-agnostic, now refuses
  marker-carrying acceptance tests);
- the UNIT lane's #1308 two-class dispatch is untouched (the marker stays
  ABSENT on the unit fallback path — pinned by A-1512-d2).

## Change 3 — `GenerationPlanner.plan()` branch 3b (root cause 2)

A new acceptance branch sits between the function-intent branch (3) and the
generic misfire (4), reachable only by rows that previously died in
`_unexpressibleReason` ("no generator surface maps …"):

- **Entity derivable from the row** (explicit `target` →
  `_extractEntityName` prose → `_extractCapitalizedTrace` for `A<n>` ids,
  the #758/#873 extractor): the #609/#610/#758 entity pipeline —
  `entity create -n <Name>` → `make <Name>` → `tdd wire <id> --entity
  <Name> --feature <f>` → `build` (the exact argv branch 2 already emits
  for acceptance rows; `entity create` stays idempotent under make's #829
  gate).
- **Otherwise**: the spec-052 composition lane — `tdd compose <id>
  --feature <f>` → `build` (the exact argv `CompositionPlanner` emits
  through make's #642 fallback) — the issue's sanctioned "compose the
  existing unit-level generated pieces" surface. The compose command
  fail-closes with the actionable `no-green-units` stop when the feature
  holds no composable anchors, so the loop terminates honestly instead of
  re-driving the row every run.

`unexpressible` becomes rare and honest for acceptance rows: only the #758
refusal (branch 2's CRUD-prose-with-no-entity, which names the remedy)
keeps it. Declared contract rows never reach this branch — the declaration
ladder resolves them first (unchanged).

## Backwards compatibility

- Unit lane: byte-for-byte (same capture, same assertion, same warning).
- Widget/ffi/persistence/theme/platform/contract lanes: untouched (their
  templates never route through the acceptance branches).
- Every pre-existing planner expectation for acceptance rows (U-718e,
  A-758a/b/c/d/e, U-873a/b/c) passes unchanged — those rows are caught by
  branches that precede 3b.
