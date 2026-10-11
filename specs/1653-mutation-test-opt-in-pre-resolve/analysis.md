# Analysis Report: 1653-mutation-test-opt-in-pre-resolve

Cross-artifact consistency check (spec.md ↔ plan.md ↔ tasks.md ↔
tool-generated test-list.md), SDD phase 4.

## Findings and fixes applied

1. **TUPEC id drift** — the first `zfa tdd plan` run REFUSED the spec: FR
   ids were `FR-1..FR-8` (1-digit) while the coverage gate requires the
   TUPEC 3-digit form. Fixed in spec.md (`FR-001..FR-008`); the re-run
   planned clean. (fixed)
2. **Dangling traces** — the first plan run refused the routing of
   U6/U7/U8 (`RefactorCommand`, `CycleLogEntry`, `RefactorAction` named no
   declared contract row at that moment). Fixed by declaring the entities
   in the spec's Key Entities / Layer Contracts sections; the re-run
   routed U1–U8 and wrote all 17 behaviors (6 acceptance + 8 unit + 3
   contract). (fixed)
3. **Task id typo** — tasks.md carried a `T11` (2-digit) row between
   T010/T011; renumbered to T011. (fixed)
4. **Scope guard verified** — spec Locked decision 7 and plan Design
   decision list both exclude the verify lane's audit semantics and the
   `mutation_test` tool itself (the issue's hard constraint); no task
   touches `verify_command.dart` / `mutation_verifier.dart` /
   `mutation_auditor.dart`. Confirmed: tasks T005–T008 name only
   writer/init/patcher/refactor-receipt surfaces. (pass)
5. **Coverage mapping** — every SC has a proving behavior: SC-1 →
   A1/U1/U3; SC-2 → A3/U4; SC-3 → A4/U6/U7/U8; SC-4 → A1+plan decision 1
   (argued in verification, no Flutter SDK for an E2E re-probe — recorded
   in spec Assumptions); SC-5 → T009/T011. Every acceptance scenario A1–A6
   has a unit FR behind it (FR-001..FR-008) and a task (T003–T008).
   (pass)
6. **Byte-compat hazard accepted** — the patcher test suite's
   "adds all six / five" expectations pin the OLD unconditional default;
   the new default changes them. This is an HONEST re-pin (the tests must
   assert the new #1653 contract), tracked as task T009 with the drift
   called out, not a silent edit. (accepted, tracked)
7. **Lazy-verify alternative rejected consistently** — spec Locked
   decision 1 records WHY (the hard constraint protects the verify lane);
   plan decision 2 keeps the #1528 preflight on the default path. No
   artifact suggests the lazy path. (pass)

## Residual risks

- `zfa setup` also stops injecting `mutation_test` (the patcher default
  changed for both callers). Desired (same cold-cost class, SC-4) but
  worth calling out in the PR body — done.
- Fresh Flutter CI agents that relied on init-injected `mutation_test`
  for `zfa tdd verify` will now see the existing NOT_ASSESSED + fix line
  until they opt in (`zfa tdd init --mutation` or `dart pub add
  dev:mutation_test`). The degradation is pre-existing, honest, and
  documented.
