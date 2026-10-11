# Analysis — Spec 1331 (cross-artifact consistency report)

Run after tasks.md, before tdd.plan. Checks and results:

## Coverage matrix (spec SC-n ↔ tasks ↔ tdd behaviors)

| SC | Deliverable | Tasks | Behaviors |
|----|-------------|-------|-----------|
| SC-1 | reset deletes all owned files | T1, T2 | B1, B2 |
| SC-2 | reset validates its outcome (warnings by name, count = actual) | T3 | B3, B4 |
| SC-3 | foreign files never deleted | T2 | B5 |
| SC-4 | make adopts the re-drive class (`adopted`) | T4, T5, T6 | B6, B7 |
| SC-5 | refusal classes preserved outside the re-drive class | T6 | B8 |
| SC-6 | run completes; doctor prescription matches reality | T7, T8, T9 | B9, B10 |
| SC-7 | no regressions in touched contracts | T10 | existing suites |

No orphan success criteria, no orphan tasks.

## Naming consistency

- Verdict detail keys `path_drift` / `foreign_owned_looking` /
  `deleted_files`: identical in spec.md (SC-2), plan.md (fix design),
  tasks.md (T3), and the test-list behaviors B3/B4. Consistent.
- Outcome token `adopted`: identical in spec.md (SC-4), plan.md,
  tasks.md (T4/T6/T7/T8), test-list (B6/B7/B9/B10). Consistent.

## Scope-fence deviation review (justified)

The issue's hard constraint names three fix surfaces
(`reset_command.dart`, the make/verify-red re-drive handling, doctor's
prescription). The `adopted` outcome required by acceptance criterion 3
cannot exist without its plumbing:

- `models/generation_plan.dart` — the `MakeOutcome.adopted` value (the
  outcome itself).
- `services/journal.dart` — a READ-ONLY probe
  (`JournalReader.lastResetTombstone`) reusing the #1264 tombstone the
  reset already writes; no write-path change.
- `services/step_runner.dart` / `commands/run_driver_core.dart` — the
  loop must ACCEPT `adopted` as a terminal make success or the re-drive
  still stops (the exact dead-end this spec removes).

These are the make re-drive handling, not the core engine cycle, the
gen/make/compose/view pipeline, the refactor pass, or the verify gate
semantics — all untouched. Deviation accepted.

## Drift fixes applied

None required — the artifacts were drafted against the traced root
causes and stayed aligned. The one ambiguity found (whether
"verify-red re-drive handling" implied touching `verify_red_command.dart`)
was resolved against the spec's scope fence: verify-red semantics are
UNCHANGED; the unexpected-green skip transition already re-drives
correctly once make stops refusing the re-drive class.
