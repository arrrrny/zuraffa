# Fix: acceptance lane — a real make surface + honest fallback naming (#1512)

- **Slug**: 1512-acceptance-vacuous-composition
- **Files changed (hard constraint: acceptance lane ONLY)**:
  - `lib/src/plugins/tdd/services/behavior_test_writer.dart`
  - `lib/src/plugins/tdd/services/generation_planner.dart`
  - `lib/src/plugins/tdd/services/vacuous_guard.dart` (the acceptance
    fallback vocabulary constants only — no logic, no unit-lane behavior)
- **Unit lane**: byte-for-byte unchanged (pinned by A-1512-d1/d2 and the
  pre-existing #1035/#1259 suites).
- **State machine / loop semantics**: no run_driver / make_command /
  subject_writer / gen_command edits.
- **Round-2 review correction (PR #1522)**: the original Change 1 claimed to
  thread the row's declared args and return its declared result. It did not
  ship — `gen_command.dart` resolves a `contractShape` only for
  `BehaviorKind.unit`, and the paired acceptance subject is a
  parameterless `void <target>()` scenario runner (`subject_writer.dart`,
  preserved by `tdd wire` / `tdd compose`), so the branch was unreachable in
  production and would have been a `use_of_void_result` + arity compile
  error against the pair `gen` actually emits. Change 1 is therefore
  REMOVED (the reviewed option (b)): the acceptance capture is the
  void-safe, argument-free form, and the row's declared outcome is asserted
  through the composition lane Change 3 routes to. The original Change 2
  marker is likewise replaced by a distinct acceptance token (see below).

## Change 1 — `BehaviorTestWriter._captureInvocation` (root cause 1)

`gen` never supplies a contract shape to an acceptance behavior, and the
paired acceptance subject is a PARAMETERLESS `void <target>()` scenario
runner whose lifecycle (`gen` stub → `tdd wire` → `tdd compose`) preserves
that signature. The acceptance capture is therefore the VOID-SAFE,
ARGUMENT-FREE form — `final Object? result` + `subject.<target>();` +
`return null;` — and a directly-injected `contractShape` is INERT for
acceptance (no arg helpers, no threaded args, no returned result). `make`'s
vacuous-green refusal is unit-scoped by design (`make_command.dart` step 3c:
"acceptance rows keep the legacy skip transition — the composition lane is
deferred by design, FR-009"), so the guard-only acceptance test is the
lane's correct red surface: the stub throws, the capture returns the error,
the guard fails; the composition lane then implements the subject and the
guard certifies green.

The capture's other half — "assert the declared outcome surface" — is
delivered by the composition lane (Change 3), not by this writer: the
acceptance subject is a void scenario runner with no return value to assert
on.

## Change 2 — `BehaviorTestWriter._deriveAssertion` fallback (root cause 1)

The undeclared acceptance fallback's assertion set is the bare
`expect(result, isNot(isA<UnimplementedError>()));`. The acceptance branch
now names its gap with the acceptance-lane token
(`acceptanceFallbackGuardToken` / `acceptanceFallbackGuardComment`,
`vacuous_guard.dart`) — NOT the #1259 `vacuousGuardMarker`:

- marker presence is the run driver's traced hand-delta discriminator
  (`stopped_at=<id>:hand`, `run_driver_core.dart`), and this fallback is not
  a traced contract — the marker reclassified its honest
  `stopped_at=<id>:make` gap and prescribed an assertion the void scenario
  runner cannot carry;
- the shared `contentIsVacuousGreen` detector still refuses the guard-only
  set mechanically through its content backstop — the refusal never depended
  on the marker;
- the UNIT lane's #1308 two-class dispatch is untouched (the marker stays
  ABSENT on the unit fallback path — pinned by A-1512-d2).

## Change 3 — `GenerationPlanner.plan()` branch 3b (root cause 2)

A new acceptance branch sits between the function-intent branch (3) and the
generic misfire (4), reachable only by rows that previously died in
`_unexpressibleReason` ("no generator surface maps …"):

- **Entity derivable from an explicit prose signal** (`summary.target`, which
  make resolves from `entity <Name>` prose, or the `entity <Name>` /
  `create <Name>` matcher `_extractEntityName` uses): the #609/#610/#758
  entity pipeline — `entity create -n <Name>` → `make <Name>` → `tdd wire
  <id> --entity <Name> --feature <f>` → `build` (the exact argv branch 2
  already emits for acceptance rows; `entity create` stays idempotent under
  make's #829 gate). The #758/#873 capitalized-trace extractor is
  deliberately NOT consulted: it returns the first non-stopword capitalized
  token anywhere in the prose, and this branch's FIRST step
  (`entity create -n <Name>`) would then create the entity the wire step was
  supposed to misfire on — scaffolding use-cases/repositories/DI for a
  fabricated entity ("the User signs in." → `entity create -n User`).
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
ladder resolves them first (unchanged) — and make's traced-entity resolver
(`_tracedEntityFor`) is unit-scoped, so this branch sees undeclared scenario
prose only.

## Backwards compatibility

- Unit lane: byte-for-byte (same capture, same assertion, same warning).
- Widget/ffi/persistence/theme/platform/contract lanes: untouched (their
  templates never route through the acceptance branches).
- Every pre-existing planner expectation for acceptance rows (U-718e,
  A-758a/b/c/d/e, U-873a/b/c) passes unchanged — those rows are caught by
  branches that precede 3b.

