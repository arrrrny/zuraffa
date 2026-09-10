# Bug Assessment: lane-split plan silently drops spec-derived Layer Contract behaviors (contract rows never reach 04-ENGINE.md)

- **Slug**: 1419-lane-split-drop-contract-behaviors
- **Created**: 2026-09-11
- **Source**: https://github.com/arrrrny/zuraffa/issues/1419
- **Verdict**: valid
- **Severity**: high (silent coverage loss)

## Report (verbatim record in issue.md)

`zfa tdd plan` on a spec declaring BOTH `## Layer Contracts` (spec 1007) and
`## Lanes` (spec 1000) derives the contract behaviors but never writes them
into the lane-split plans. The legacy (no-Lanes) path renders them; the same
spec loses contract behaviors the moment it declares lanes — silently, exit 0,
no refusal, no coverage-gate failure.

## Symptom (reproduced in this session, pre-fix)

Fixture spec: `## Layer Contracts` (MessageTransport: send/acknowledge) +
`## Lanes` (CORE: A1-A3, U1-U3). `zfa tdd plan` exits 0 and writes
`04-ENGINE.md` with only the A/U rows — `contract:A1`/`contract:A2` appear in
the route log (`route: contract:A1 -> contract lane [declared:
MessageTransport]`) but NOT in the engine plan. `TestListReader` resolves no
contract rows from the split files; gen/make/run/verify never see the
declared method contracts.

The bug record `test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart`
was RED before the fix (engine-plan contract section absent, reader kind
drift, declared-id clobber, SKIN-declared contract id accepted).

## Root Cause

`lib/src/plugins/tdd/commands/plan_command.dart`, the lane-split block
(`if (laneResult != null)`, issue #1000):

1. `engineRows`/`skinRows` are built from `expressible` (via
   `_derivedLaneRows`) + `_ffiLaneRows(preservedFfi, ...)` +
   `laneResult.handRows` — `contractBehaviors` is never added. The shared
   engine renderer has no contract section either, so the rows the route log
   claims (`route: contract:A<n> -> contract lane`, written at line ~808)
   never reach the artifact — the exact silent-drop class bug #1432 closed
   for platform rows (its fix explicitly left this path "open issue #1419").
2. `_resolveLanes` never sees `contractBehaviors`: the classification map has
   no entry for `contract:A<n>` ids, so the lane-coverage accounting counts
   nothing for them (the drop has no witness), a `contract:A1` declaration in
   `## Lanes` falls into the hand-rows branch (`declaredHandIds -
   derivedIds`) and wins with the anonymous
   `core behavior declared in ## Lanes` description + `LANE:CORE` trace +
   unit kind — clobbering the derived description, `Interface.method` trace,
   contract kind, and BLOCKED semantics.

## Remediation (all in plan_command.dart, per the hard constraint)

1. **Split path**: build contract lane rows
   (`_contractLaneRows(contractBehaviors, laneResult)` — description,
   `sourceCriterion` trace, contract kind, reconciled state, lane from the
   classification, CORE by default) and add them to `engineRows`/`skinRows`.
   Because the shared engine renderer (lane_split.dart) owns no contract
   section, the plan writes the contract-loop section itself — the same
   title, intro, and 4-column rows the legacy single-file path (`_render`)
   writes, so `TestListReader` resolves the rows with contract kind and the
   spec-1007 BLOCKED semantics unchanged. The shared renderer and every
   other subsystem stay untouched.
2. **Lane-coverage counting**: pass `contractBehaviors` into
   `_resolveLanes` (and `_heuristicLaneResolution` for the #1309
   regeneration path) so the classification counts them — CORE by default
   (spec 1007: a contract test is pure Dart, so it rides the engine), the
   declared lane wins for a CORE declaration. A SKIN/BOTH declaration of a
   derived contract id refuses (the SKIN plan renders no contract section —
   honoring it would silently drop the row again; the remedy names the CORE
   move). The engine noFlutter guard applies to contract rows like any
   engine-destined row.
3. **Hand-rows branch**: the derived-id set gains the contract ids, so a
   `contract:A<n>` declaration consults the derived contract behavior
   before falling through to the anonymous hand-row template — the row
   carries the derived description, `Interface.method` trace, contract kind,
   and reconciled (BLOCKED-capable) state.

## Hard constraints honored

- ONLY `plan_command.dart` changed in the assessment-time plan (plus the
  new bug test file); the review round added `lane_split.dart` — see the
  note below.
- Core engine cycle, gen pipeline, verify gate, spec-parser: untouched.
- One PR per bug: `fix/1419-lane-split-drop-contract-behaviors`.

## Review round (post-assessment revision)

The automated review of the fix PR proved the same silent-drop class was
still reachable through `zfa tdd split` — `SplitCommand` routes
`BehaviorKind.contract` rows CORE and calls the same `renderEnginePlan`,
which owned no contract section, so the migrated `04-ENGINE.md` omitted
the rows its own meta-index and receipt classified. Remediation point 1
("the plan writes the contract-loop section itself") was therefore
revised: the section now lives in the shared renderer —
`renderContractLoopSection` in `lane_split.dart`, called from
`renderEnginePlan` over the `BehaviorKind.contract` rows it already
receives, and from the legacy `_render` path. The `skinRows` spread of
the contract rows was dropped: `_resolveLanes` refuses every non-CORE
declaration of a derived contract id, so it was unreachable.

`fix.md` records the final shape; the remediation section above is the
plan as of assessment time.
