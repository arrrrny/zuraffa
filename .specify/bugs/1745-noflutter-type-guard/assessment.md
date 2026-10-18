# Bug Assessment: noFlutter guard is a bare `package:flutter` substring test — a CORE plan can declare Flutter-typed Key Entities and Presentation Layer Contracts, and presentation contracts land in the engine lane

- **Slug**: `1745-noflutter-type-guard`
- **Created**: 2026-10-17
- **Source**: https://github.com/arrrrny/zuraffa/issues/1745
- **Verdict**: valid
- **Severity**: high (silent misroute; the engine lane stops being pure Dart and cannot go green on its own)

## Report (verbatim or summarized)

The `noFlutter` guard that keeps `04-ENGINE.md` "pure Dart by construction"
tests the row text for the literal substring `package:flutter` only
(`plan_command.dart`, `_flutterReference`). It never inspects the
`### Key Entities` fields nor the `## Layer Contracts` signatures, so a CORE
plan can declare Flutter *types* — `IconData`, `Widget` — and plan cleanly.
Worse, contract behaviors derived from a `**Presentation**` Layer Contract are
classified **CORE by default** (issue #1419: "a contract test is pure Dart, so
it rides the engine"), so the presentation seam is physically emitted into the
engine lane.

Evidence quoted in the issue (`zfa tdd plan shell` on `specs/shell/spec.md`,
`arrrrny/zik_zak_v2`): the plan was accepted with no refusal and
`tdd/04-ENGINE.md` came out carrying

```
| contract:A11 | AppBottomNav.build() -> Widget (controller method contract) | … |
```

plus the Flutter-typed Key Entity, while `04-SKIN.md` carried the widget
behaviors (`W1`–`W3`) as expected — the same `Widget` surface claimed by both
lanes. The reported workaround was to re-scope the spec so the CORE lane is
genuinely Flutter-free.

## Symptom

A lane-split spec whose CORE lane is meant to be provable **before** the skin
exists is accepted with Flutter types in its engine plan. The engine lane's
green then depends on a presentation artifact (`AppBottomNav`) the skin lane
has not produced yet — inverting the dependency the split exists to create.
Expected: plan refuses, naming the offending declaration.

## Reproduction

1. Seed a lane-split spec with `### Key Entities` declaring
   `index: int, icon: IconData, activeIcon: IconData, label: String,
   branchIndex: int?` and `## Layer Contracts` declaring
   `` `AppBottomNav`: `build() -> Widget` ``.
2. Run `zfa tdd plan <feature>`.
3. Observed (pre-fix): exit 0; `04-ENGINE.md` carries the `IconData` entity row
   and `| contract:A1 | AppBottomNav.build() -> Widget (controller method
   contract) | … |`.

Verified in this session on the unfixed tree with the issue's exact shape —
exit 0, and `04-ENGINE.md` carrying both rows.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/plan_command.dart:_resolveLanes` — the
  engine-destined row check (`rowText.contains(_flutterReference)`) and the
  contract loop (`classification.putIfAbsent(b.id, () => Lane.core)`). The
  substring test never matches a Flutter **type**, and the contract loop never
  consults the declaring layer.
- `lib/src/plugins/tdd/commands/plan_command.dart:_deriveContractBehaviors` /
  `_contractCategory` — the layer IS known here (`Presentation` →
  `controller method`), but only the category label survives into the derived
  behavior's description; `_resolveLanes` never sees it.
- `lib/src/plugins/tdd/services/lane_split.dart:_declarations` — writes the
  Key Entities table into `renderEnginePlan` verbatim, with no purity check on
  the field types.
- `lib/src/plugins/tdd/services/spec_parser.dart:parseLayerContracts` — the
  layer label and the verbatim method signatures are both parsed; the guard
  reads neither.

## Root Cause Hypothesis

Confidence: **high**. Two independent holes, both in `plan_command.dart`:

1. The guard is a substring test for the `package:flutter` URI, while the leak
   is by **type name** (`Widget`, `IconData`). A Layer Contract signature
   renders into the contract row as `<Interface>.<method> -> <Return>
   (<category>)`, so the type name reaches the engine plan without the URI ever
   appearing.
2. The contract loop in `_resolveLanes` unconditionally defaults to CORE. The
   declared lane wins when the author writes one, but the **layer the
   declaration came from** is never consulted — so a `**Presentation**`
   contract rides the engine lane by silent default.

## Proposed Remediation

**Preferred**: keep the fix inside `plan_command.dart`.

- Add a Flutter **type** guard (whole-word match for `Widget`, `IconData`,
  `BuildContext`, `Color`, `TextStyle`) alongside the existing
  `package:flutter` test, and apply it to the declarations the engine plan
  renders but no behavior row carries — the Key Entity fields and the Layer
  Contract signatures.
- Make the contract default layer-aware: a contract derived from a
  `**Presentation**` Layer Contract must not default to CORE. Since the SKIN
  plan renders no contract section, refuse it (the author's explicit CORE
  declaration in `## Lanes` stays honored — `declarations win, gaps refuse`).
- Name the offending declaration in each refusal the way the existing guard
  does.

**Alternatives** (considered, not chosen):
- Teach `04-SKIN.md` to render a contract section so a presentation contract
  can ride the skin lane. Structurally better, but it changes the renderer, the
  reader, `zfa tdd split`'s routing and every downstream consumer of a
  contract-kind row — far beyond the smallest reading of this issue.
- Extend the guard to arbitrary behavior-row prose. The issue scopes the ask to
  Key Entity fields and Layer Contract signatures; prose is left alone.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/plan_command.dart`
- `test/plugins/tdd/commands/bug_1745_noflutter_type_guard_test.dart` (new)
- `test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart` (fixture
  label migration — its `PlatformEnvelope` contract was declared
  `**Presentation**` incidentally)

**Tests to add or update**:
- Refuse: Flutter-typed Key Entity; Flutter-typed contract signature; the same
  under a non-Presentation layer.
- Refuse: an undeclared `**Presentation**` contract (no silent CORE default).
- Accept: the same contract with an explicit `contract:A<n>` CORE declaration,
  whose row renders in `04-ENGINE.md`.
- A refused plan writes no lane artifact.

## Risks & Considerations

- **Behavioral break for `**Presentation**`+lanes specs**: `corpus/zik_zak/*`
  (122 tracked files) declare `**Presentation**: XPresenter: present(XState) ->
  XView` with lane splits; they now refuse until the declaration is routed or
  dropped. Nothing in CI plans the corpus, so no test depends on it — called
  out in the PR body rather than editing generated fixtures in a bug-fix PR.
- **Label matching is literal**: the new refusal keys on a layer label
  containing `presentation`. A `**Controller**`-labelled contract (a pure Dart
  controller) keeps its engine default, which is what spec 1007 intends.
- **Whole-word matching** means `StatefulWidget`/`WidgetBuilder` are not
  flagged by this guard (a distinct type the author names explicitly); the
  `package:flutter` test still catches an import.
- Non-lane-split (legacy) plans are untouched: the guard is scoped to the lane
  split, which is where the engine artifact exists.

## Open Questions

None.
