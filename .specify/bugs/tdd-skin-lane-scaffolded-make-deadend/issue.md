# Issue #1258 — tdd: SKIN lane dead-ends at make — scaffolded widget tests are refused with no supported authoring step

- **GitHub issue:** https://github.com/arrrrny/zuraffa/issues/1258
- **Severity:** high
- **State (at triage):** open
- **Version:** 6.1.0 (master)
- **Component:** `zfa tdd` → TDD plugin skin lane (`lib/src/plugins/tdd/**`)

## Describe the bug

The widget (SKIN) lane of the two-cycle TDD driver structurally dead-ends:
`zfa tdd gen --kind widget` emits a widget test whose scenario assertions are
placeholder finders carrying the `zfa:tdd: scaffolded` marker, and
`zfa tdd make` then **refuses to certify green on exactly that test**
(issue #912 defect 3) — demanding the author "replace the placeholder finders
with concrete scenario-derived finders, remove the marker, and re-run make".
But no `zfa` command performs that replacement, and `zfa tdd refactor`'s
contract is "never edit tests". The generated test is registry-owned, so
hand-editing it is an out-of-contract mutation with no receipt, no adopt path,
and `zfa tdd replay` divergence risk.

Observed in a real migration attempt: `zfa tdd run <feature>` ran the engine
lane to completion, then the skin lane stopped at `<id>:make` on every attempt
(journal: `skin lane stopped at A1:make`, `result=stopped`) and can never
proceed by commands alone.

There is also no derivable concrete finder for the emitted scenarios: the
scaffold derives assertions from the acceptance description (e.g. "the system
initiates Apple sign-in"), but "initiates" maps to no `find.text`/`find.byType`
target because the button labels/layout live in the (not-yet-written) view —
the scaffolded placeholder is the honest state, yet the pipeline treats it as a
refusal instead of a supported authoring step.

## To Reproduce

1. `specs/<feature>/spec.md` with a SKIN lane and a widget acceptance row
   (e.g. "When the user taps sign-in, the system initiates sign-in").
2. `zfa tdd plan` → `zfa tdd split` → `zfa tdd gen <id> --kind widget`
   (test gets the `zfa:tdd: scaffolded` marker).
3. `zfa tdd run-skin <feature>` (or `zfa tdd make <id>`).
4. make refuses: "test is SCAFFOLDED — its scenario assertions are placeholder
   finders … Replace the placeholder finders … and re-run make." Exit non-zero;
   run-skin records `stopped_at=<id>:make`.

## Expected behavior

The conveyor should have a first-class, receipted step that transitions a
scaffolded skin test from placeholder to concrete: e.g.
`zfa tdd make --author` / `zfa tdd view --bind <id>` that (a) accepts the skin
author's concrete finders + view (the hand-delta seam), (b) validates
red-before-green honestly, (c) registers the hand delta in the
registry/provenance ledger (like `zfa tdd realize --scaffold` does for
adapters), and (d) clears the scaffold marker so the driver resumes. Today the
only paths are (1) hand-edit a registry-owned generated test with no
provenance, or (2) the run stops forever.

## Actual behavior

`zfa tdd run-skin` exits stopped at the first skin behavior's make step;
re-invoking repeats the refusal verbatim (the journal accumulates identical
stopped entries). No command can advance past it.

## Suggested fix

- Give `make` (or a sibling command) a sanctioned skin-authoring mode that
  replaces scaffolded finders with author-supplied concrete finders,
  re-certifies red-before-green, writes a hand-delta receipt, and updates the
  registry hash.
- Alternatively, `gen` should accept a scenario-to-finder mapping (declared
  widget contract: button labels/targets) so the generated test is never
  scaffolded in the first place when the spec declares the surface.
