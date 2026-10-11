# Assessment — issue #1258 (tdd skin lane scaffolded make dead-end)

## Triage

**Confirmed, root-caused from the pipeline contract, no live reproduction
required to locate the defect.** This is not a runtime crash — it is a
structural dead-end in the SKIN lane conveyor: the pipeline emits an honest
scaffolded state and then refuses to ever consume it. No command transitions
the artifact from scaffolded to concrete, so the lane can only stop.

## Root cause (exact)

1. `zfa tdd gen --kind widget` emits a widget test whose scenario assertions
   are placeholder finders carrying the `zfa:tdd: scaffolded` marker. The
   scaffold derives assertions from the acceptance description (e.g. "the
   system initiates Apple sign-in"), but "initiates" maps to no
   `find.text`/`find.byType` target because the button labels/layout live in
   the not-yet-written view. The scaffolded placeholder is therefore the
   honest state at that point in the conveyor.
2. `zfa tdd make` then refuses to certify green on exactly that test,
   demanding the author "replace the placeholder finders with concrete
   scenario-derived finders, remove the marker, and re-run make".
3. But **no `zfa` command performs that replacement**: `zfa tdd refactor`'s
   contract is "never edit tests", and the generated test is registry-owned —
   hand-editing it is an out-of-contract mutation with no receipt, no adopt
   path, and `zfa tdd replay` divergence risk.

Net effect: the SKIN lane stops at `<id>:make` on every attempt and can never
proceed by commands alone. The conveyor treats a supported authoring state as
a terminal refusal.

## Remediation (chosen)

Add a **sanctioned skin-authoring mode** to `make` (`zfa tdd make --author`)
that transitions a scaffolded skin test from placeholder to concrete through
the pipeline, with a receipt:

- (a) accepts the skin author's concrete finders + view (the hand-delta seam);
- (b) validates red-before-green honestly (re-certifies the now-concrete test
  against the not-yet-written view);
- (c) registers the hand delta in the registry/provenance ledger (same spirit
  as `zfa tdd realize --scaffold` for adapters);
- (d) clears the `zfa:tdd: scaffolded` marker and updates the registry hash so
  the driver resumes.

## Alternative (considered, not required for this fix)

`gen` accepting a scenario-to-finder mapping (declared widget contract: button
labels/targets) so the generated test is never scaffolded when the spec
declares the surface. Valuable, but it does not repair the existing dead-end
for tests already scaffolded without a declared surface; the authoring mode is
the minimal fix that unblocks the lane in all cases.

## Hard constraints honored

- Fix ONLY through the generation pipeline; never hand-edit source the
  pipeline owns.
- One PR per bug.
- All changes covered by tests (red → green evidence recorded).
