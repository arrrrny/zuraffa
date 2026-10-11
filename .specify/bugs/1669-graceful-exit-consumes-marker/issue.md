# Bug Issue: non-adopting graceful exit after a crash consumes the interrupt marker while the crash mutation survives (re-creates the #1036 wedge)

- **Slug**: 1669-graceful-exit-consumes-marker
- **Fetched**: 2026-09-16
- **Issue**: 1669
- **URL**: https://github.com/arrrrny/zuraffa/issues/1669
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

## Context

Follow-up from the automated review of #1666 (crash-safe make, issue #1398) — the reviewer's 🟡 #3, filed per the reviewer's own disposition ("deserves a follow-up issue even if the fix ships separately").

## The wedge

A NON-adopting graceful exit after a crash consumes the crash record while the crash mutation survives:

1. Make killed mid-flight → subject mutated green + `make-interrupt.json` present.
2. Resume refuses for an UNRELATED reason (flaky target test → generation-error, preflight failure, or log loss → not-certified-red).
3. `_printSummary` (the every-exit-path funnel) clears the marker on EVERY graceful exit — including this refusal.
4. Next resume: subject still mutated, marker gone → byte-identical to the dishonest hand-edit class → #1036 `subject-drift` refusal dead-ends it.

That is the exact wedge #1398/#1666 exists to remove, now reachable one refusal later. plan.md's risk note covers "stale marker after a refusal" (marker present, nothing mutated) but not this compound (mutation survives AND marker consumed).

## Suggested mitigation (from the review)

On a non-adopting exit, keep (or re-write) the marker when the on-disk subject hash differs from the certified hash — consume the marker only when the drift is resolved or never existed. The summary funnel (`_printSummary`) would need the drift signal at clear time.

## Constraints

`_printSummary` currently receives only behavior/outcome/feature; the certified hash lives with the evidence registry — plumbing the drift signal to the funnel without touching the make-skip logic, fingerprint comparison, or the #1036 recovery path is the design work this issue tracks.

## Comments

None.
