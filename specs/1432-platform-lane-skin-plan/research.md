# Research: platform-typed acceptance scenarios dropped from lane plans (#1432)

## R1 — Where exactly does the drop happen?

**Decision**: The silent drop is in the lane-split renderers, not the router.

**Findings** (traced on the head tree):

- Routing is CORRECT: the router resolves a `Type: platform` marker (and a
  `traces:` reference to a channel contract row) to `BehaviorKind.platform`
  and classifies it to the SKIN lane; the route log's
  `route: A1 -> platform lane [declared: type marker, spec line 57]` is
  truthful. No refusal fires because the behavior IS declared in `## Lanes`.
- Rendering drops it: `LaneRow.kind` carries `platform` truthfully, but
  `renderSkinPlan` (`lane_split.dart`) renders only
  `acceptance`/`widget`/`unit` sections and `renderEnginePlan` only
  `acceptance`/`widget`/`unit`/`ffi`. A `platform` row matches no filter in
  EITHER file → the row exists in no artifact.
- Downstream consequence: `TestListReader` resolves run rows from the split
  files; with the row absent, run/run-skin drive 12 declared-but-rendered
  behaviors and report green — the coverage gate never sees A1–A5.

**Rationale**: fixing the renderer (not the router) preserves the router's
correct lane decision and matches the issue's Expected outcome (a) — render
exactly like acceptance.

**Alternatives considered**: refusing platform outright (Expected outcome
(b)) — rejected as the primary contract because the issue author's
workaround (hand-adding the rows to 04-SKIN.md's acceptance table, then
gen → hand-delta → red → re-certify → run-skin) proves the acceptance-table
shape works end-to-end for platform scenarios; refusal remains the backstop
for kinds with no section at all (R2).

## R2 — Which kinds have no rendered home, and what should happen?

**Decision**: platform joins the acceptance outer-loop section in both lane
plans; `theme` (the one other kind that reaches the split row lists with no
rendered home) becomes a plan-time refusal; `contract` rows are OUT of scope
(open issue #1419 owns the contract-row path — its own silent-drop report).

**Findings**:

- `BehaviorKind` = {acceptance, unit, widget, theme, ffi, platform, contract}.
- Post-fix home sets: engine plan renders
  {acceptance, platform, widget, unit, ffi}; skin plan renders
  {acceptance, platform, widget, unit}. A BOTH row renders in both files, so
  its kind must have a home in both sets.
- `theme`: the split heuristic routes theme→SKIN (`split_command`), the
  renderers have no theme section → theme rows are silently dropped today by
  the same mechanism. No test fixture declares a theme scenario (verified:
  zero `Type: theme` fixtures under `test/`), so turning the drop into a
  refusal breaks nothing and implements FR-003's errors-are-an-API backstop
  for the whole class.
- `contract`: contract-kind behaviors ride a separate list in the planner
  (not `expressible`); rendering them into lane plans is #1419's open work.
  The guard MUST NOT consider contract rows.

**Rationale**: render-what-has-a-proven-shape, refuse-what-does-not — the
log/artifact disagreement becomes structurally impossible for every kind the
planner routes.

**Alternatives considered**: a dedicated "platform behaviors" section —
rejected; the reader/gen pipeline keys rows by section shape, and the
author's workaround pinned the acceptance-section shape as working. A new
section would need reader changes for zero behavioral gain.

## R3 — Where does the refusal guard live?

**Decision**: in `plan_command.dart`'s split refusal loop (the same pass
that fires the `lane == null` and noFlutter refusals), before any artifact
write.

**Findings**: the split path's contract is "the lane guards refuse BEFORE any
artifact — an incomplete split never leaves a half-written lane plan." The
refusal loop has the full provenance (behavior id, criterion, declared lane);
the guard needs only the behavior's kind and destination lane. The gate runs
before the emission block, so a refusal exits non-zero with zero files
written — matching SC-003.

**Rationale**: guarding at emission time would have to un-write artifacts;
guarding at the existing refusal pass reuses the exit-2 no-artifact contract.

**Alternatives considered**: enforcing inside the renderers (throw on
unrendered kind) — rejected; the renderer returns a String and cannot carry
the structured refusal verdict/exit class the CLI contract requires.

## R4 — Does the fix regress `zfa tdd split` / re-planning?

**Decision**: no; the rendering half is shared, the refusal half is
plan-only, and the split command's own kind heuristic is unchanged.

**Findings**: `zfa tdd split` uses the same `renderSkinPlan`/
`renderEnginePlan`; migrated features with platform scenarios regain their
rows on the next `plan`/`split` regeneration. The stale-split regeneration
path (#1309) reuses the same renderers, so migrated registries heal on
re-plan. Existing suites pin the acceptance/widget/unit/ffi shapes; the
platform rows only add rows to the existing acceptance section (same
columns), which the reader parses with the same positional contract.
