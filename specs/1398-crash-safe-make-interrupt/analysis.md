# /speckit.analyze Report — 1398-crash-safe-make-interrupt

**Date**: 2026-09-16 · **Artifacts**: spec.md · plan.md · tasks.md · tdd/test-list.md

## Consistency matrix

| Spec anchor | Plan section | Task | Test-list row | Status |
| --- | --- | --- | --- | --- |
| FR-1 (write-ahead marker) | Marker service | T001, T002 | U1 | OK |
| FR-2 (consume on resume) | Marker service + make integration | T003, T004 | U2, A1 | OK |
| FR-3 (interrupt adoption) | Make integration + outcome vocabulary | T003, T004, T005 | A1 | OK |
| FR-4 (placeholder guard) | Make integration | T003, T004 | A3 | OK |
| FR-5 (marker hygiene) | Marker service + `_printSummary` funnel | T001, T002, T003, T004 | U3, U4, U5, A2 | OK |
| FR-6 (driver acceptance) | Step contract + bug-#986 arm | T006, T007 | U6, U7 | OK |
| FR-7 (no regression) | Hard constraints | T008 | R-guard (existing suites) | OK |
| SC-1..SC-7 | Success criteria mapping | T003..T007, T011 | A1, A2, A3, U1..U7 | OK |

## Findings and fixes applied during analysis

1. **Marker scope vs single-slot file** — spec FR-1 says "behavior-scoped"; the design stores one JSON object whose `behavior` field scopes it (the driver serializes makes per feature, so one slot suffices; `pendingFor` enforces the behavior match). Resolved: plan + test-list assert the behavior-mismatch → absent (fail closed) contract explicitly (U3).
2. **Adoption-arm ordering** — the interrupt arm must sit BEFORE the #1331 tombstone arm so both classes can adopt; the placeholder gate applies to BOTH. Resolved: plan states the ordering; A3 pins the placeholder refusal under a marker; T008 pins the tombstone arm unchanged.
3. **"Read-before-overwrite" discrimination** — a make must never adopt its own marker. Resolved: plan documents read-then-begin as the only discrimination; no pid-liveness (unsound under pid reuse). Spec Assumptions updated to match.
4. **Hard-constraint fence** — tasks T002/T004/T007 touch ONLY the marker service, the make already-green branch's new arm, the outcome vocabulary, and the driver token arm. The make-skip logic (#694), the fingerprint comparison (`_subjectDriftRefusal` internals), and the subject-drift recovery path (#1324 stale-artifacts arm) have NO scheduled edits. Verified against plan's Design section. OK.
5. **Traceability** — every task carries `[behavior: …]` tags; every behavior row traces to ≥1 AC/FR and ≥1 SC. No orphan tasks, no untraced behaviors.

## Verdict

PASS — no cross-artifact drift remains. Proceed to `/speckit.tdd.run` (red-green-refactor per tdd/test-list.md).
