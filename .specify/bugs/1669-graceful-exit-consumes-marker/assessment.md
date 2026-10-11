# Bug Assessment: non-adopting graceful exit after a crash consumes the interrupt marker while the crash mutation survives

- **Slug**: 1669-graceful-exit-consumes-marker
- **Created**: 2026-09-16
- **Source**: https://github.com/arrrrny/zuraffa/issues/1669
- **Verdict**: likely valid — reviewer-identified wedge in the crash-safe resume path (#1398/#1666 follow-up)
- **Severity**: unknown

## Report (verbatim or summarized)

A NON-adopting graceful exit after a crash consumes the crash record while the crash mutation survives:

1. Make killed mid-flight → subject mutated green + `make-interrupt.json` present.
2. Resume refuses for an UNRELATED reason (flaky target test → generation-error, preflight failure, or log loss → not-certified-red).
3. `_printSummary` (the every-exit-path funnel) clears the marker on EVERY graceful exit — including this refusal.
4. Next resume: subject still mutated, marker gone → byte-identical to the dishonest hand-edit class → #1036 `subject-drift` refusal dead-ends it.

That is the exact wedge #1398/#1666 exists to remove, now reachable one refusal later. plan.md's risk note covers "stale marker after a refusal" (marker present, nothing mutated) but not this compound (mutation survives AND marker consumed).

Link: https://github.com/arrrrny/zuraffa/issues/1669

## Symptom

After a crash-interrupted `zfa make` leaves the subject mutated, a subsequent resume that refuses for an unrelated reason (flaky test, preflight failure, not-certified-red) silently deletes `make-interrupt.json`; the next resume then hits the #1036 `subject-drift` refusal with no marker to recover from — a permanent wedge.

## Reproduction

1. Run `zfa make` and kill it mid-flight after the subject is mutated green (marker `make-interrupt.json` present).
2. Re-run resume and force an unrelated refusal (flaky target test → generation-error, preflight failure, or log loss → not-certified-red).
3. Observe `_printSummary` cleared the marker on that graceful exit.
4. Re-run resume again: subject still mutated, marker gone → #1036 `subject-drift` refusal dead-ends the run.

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

Known from the issue: `_printSummary` (every-exit-path summary funnel) clears the interrupt marker unconditionally; the certified hash lives with the evidence registry.

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

Working hypothesis from the issue: `_printSummary` clears the marker on EVERY graceful exit without knowing whether the on-disk subject still differs from the certified hash, so a non-adopting refusal exit consumes a marker whose crash mutation is still live on disk.

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

Suggested mitigation (from the review): on a non-adopting exit, keep (or re-write) the marker when the on-disk subject hash differs from the certified hash — consume the marker only when the drift is resolved or never existed. `_printSummary` needs the drift signal at clear time, plumbed without touching the make-skip logic, fingerprint comparison, or the #1036 recovery path.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Must not disturb: make-skip logic, fingerprint comparison, #1036 recovery path.
- Crash-safe flow has existing regression tests; behavior on adopting exits and honest clears must stay byte-identical.

## Open Questions

- [NEEDS CLARIFICATION: where exactly does `_printSummary` clear the marker, and which callers pass through refusal paths?]
- [NEEDS CLARIFICATION: what does the evidence registry expose for the certified hash, and can it be read at summary time without coupling?]
