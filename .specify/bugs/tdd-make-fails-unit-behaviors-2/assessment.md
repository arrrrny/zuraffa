# Bug Assessment: zfa tdd make still fails on unit behaviors (U5+) — re-report

- **Slug**: tdd-make-fails-unit-behaviors-2
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/723
- **Verdict**: likely valid, needs reproduction
- **Severity**: low
- **Related**: #718 (same root cause, earlier report)

## Report (verbatim or summarized)

`zfa tdd make` for unit behaviors (U5, U6, etc.) still fails with `outcome=generation-error` because the make step tries to run `zfa make <behaviorId>` (lowercased), treating the behavior ID as an entity name. Behavior IDs are NOT entity names. Confirmed on v6.1.0 fresh project.

```
[run] U5 gen -> ok
[run] U5 verify-red -> certified
[run] U5 make -> generation-error
zfa tdd run: step failed — behavior=U5 step=make outcome=generation-error
   zfa tdd make: behavior U5
   plan: 2 step(s)
   target test exit: 1
zfa tdd make: target test still fails after generation (exit 1).
```

## Symptom

Run loop reaches a unit behavior → `U5 make -> generation-error` → "target test still fails after generation (exit 1)". Run stops at the first unit behavior.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd run 001-app-bootstrap`
   → stops at `U5:make -> generation-error`

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart` — the make step that lowercases behavior IDs and shells out to `zfa make`
- `lib/src/plugins/tdd/commands/run_command.dart` — the run loop that calls make as a step
- Behavior-to-entity name mapping / generator routing logic

## Root Cause Hypothesis

The `zfa tdd make` step assumes every behavior is an entity behavior and dispatches to `zfa make <lowercased-id>`. For unit behaviors (U*), the right generator is the plain-function surface introduced by fix #657 / PR #660 (the `zfa func` style generator). The make step needs to dispatch based on the behavior's kind (acceptance A* vs unit U*), not just lowercase the ID.

## Proposed Remediation

In `zfa tdd make`, route unit behaviors (U*) to the new plain-function generator surface (from PR #660) instead of the entity generator. The dispatch should be based on the behavior's prefix/kind, not the lowercased ID.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/make_command.dart`

**Tests to add or update**:
- `zfa tdd make` for a unit behavior (U*) → routes to plain-function generator, not entity generator
- Run loop reaches U* behavior → `make` step succeeds (drift or green), run continues

## Risks & Considerations

- This is a re-report of #718 with updated reproduction details (v6.1.0). Fixing one likely fixes the other.
- The fix in #660 added a `drift` outcome for when the test is already passing; this bug is the dispatch side of the same problem (see also issue #693 for the run-side misclassification of `drift`).
- The three bugs (#718, #723, #693) may share a root cause: dispatching unit behaviors to the wrong generator, and the run driver not recognizing the new outcome.

## Open Questions

- [NEEDS CLARIFICATION: does `zfa tdd make` look up behavior metadata (prefix → kind) to decide the generator, or just lowercase the ID?]
- [NEEDS CLARIFICATION: is this bug the same as #693 (run driver misclassifies `drift`), or a different bug?]
- [NEEDS CLARIFICATION: do all unit behaviors fail the same way, or only U5+ (U1-U4 may be handled by the new #657 surface)?]
