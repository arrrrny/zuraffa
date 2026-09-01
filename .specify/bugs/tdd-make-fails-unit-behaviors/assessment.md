# Bug Assessment: zfa tdd make still fails on unit behaviors (U5+)

- **Slug**: tdd-make-fails-unit-behaviors
- **Created**: 2026-09-01T17:23:21Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/718
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

`zfa tdd run` hard-stops at the first unit behavior (U5, U6, …) with `outcome=generation-error` because the make step is dispatching to `zfa make <behaviorId>` (e.g. `zfa make u5`), which interprets the lowercased behavior ID as an entity name and fails the entity-generation path. Behavior IDs are not entity names; the make step needs to handle non-entity (plain-function / unit) behaviors, especially the ones introduced by fix #657 (PR #660).

See: https://github.com/arrrrny/zuraffa/issues/718

## Symptom

`zfa tdd run <spec>` exits 1 at `U5:make -> generation-error` with:
```
zfa tdd make: target test still fails after generation (exit 1).
```
The make step tries to drive entity generation for a unit behavior ID, which is the wrong generator. The run loop stops; U5+ never get processed.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd run 001-app-bootstrap` → exit 1 at U5:make

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

Likely candidates:
- `lib/src/cli/commands/tdd/make_command.dart` (the make step that lowercases behavior IDs and shells out to `zfa make`)
- The run loop in `lib/src/cli/commands/tdd/run_command.dart` (which calls make as a step)
- The behavior-to-entity name mapping / generator routing logic in `zfa make`

## Root Cause Hypothesis

The `zfa tdd make` step assumes every behavior is an entity behavior and dispatches to `zfa make <lowercased-id>`. For unit behaviors (U5+), the right generator is the plain-function surface introduced by fix #657 / PR #660 (the `zfa func` style generator). The make step needs to dispatch based on the behavior's kind (acceptance A* vs unit U*), not just lowercase the ID.

The reporter notes: A1-A5 were deferred as `unexpressible` (so not in this run loop's path), but U5 is a unit behavior that hits the entity path. The 657 fix added a separate plain-function surface that U5 should use, but `zfa tdd make` doesn't route to it.

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

Expected change: in `zfa tdd make`, route unit behaviors (U*) to the new plain-function generator surface (from PR #660) instead of the entity generator. The dispatch should be based on the behavior's prefix/kind, not the lowercased ID. The run driver should then see a `drift` (already green) or `green` outcome instead of `generation-error`.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- The fix in #660 added a `drift` outcome for when the test is already passing; this bug is the dispatch side of the same problem (see also issue #693 for the run-side misclassification of `drift`).
- The two bugs (#718 and #693) are likely the same root cause seen from two angles: dispatching unit behaviors to the wrong generator, and the run driver not recognizing the new outcome. Fixing one may fix the other; confirm in the assessment.

## Open Questions

- [NEEDS CLARIFICATION: does `zfa tdd make` look up behavior metadata (prefix → kind) to decide the generator, or just lowercase the ID?]
- [NEEDS CLARIFICATION: is this bug the same as #693 (run driver misclassifies `drift`), or a different bug? Both #693 and #718 are filed by the same reporter on 2026-09-01 against v6.1.0; check whether fixing #718 also makes #693's `drift` outcome visible.]
- [NEEDS CLARIFICATION: do all unit behaviors fail the same way, or only U5+ (U1-U4 may be handled by the new #657 surface)?]
