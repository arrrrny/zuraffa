# TDD test list — Bug #1568 `tdd make` hand-step first-class run state

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1568-m1 | test/plugins/tdd/services/make_hand_step_1568_test.dart | unit | `MakeOutcome.handStep` exists with label `hand-step` and is NOT a make green-family outcome (never conflated with green/skipped/adopted) | FR-1568-1, MakeOutcome | GREEN (RED pre-fix) |
| A-1568-m2 | test/plugins/tdd/services/make_hand_step_1568_test.dart | unit | the classifier keys on the declared contract TYPE SHAPE, registry-independent: entity returns (`ScanSession`, `List<Task>`, `Map<String, Task>`, `Task?`) classify hand-step; scalars/void/`List<int>`/undeclared do not | FR-1568-1, UnitContractShape.isRenderableScalarType, SPEC 1489 seam class | GREEN (RED pre-fix) |
| A-1568-s1 | test/plugins/tdd/commands/make_command_hand_step_1568_test.dart | integration | a make whose generation completed but whose target test is still red, with an entity-shaped declared contract return, reports `outcome=hand-step` (never `generation-error`), exits 1, appends no green evidence | SC-1, AC-1 | GREEN (RED pre-fix) |
| A-1568-s2 | test/plugins/tdd/commands/make_command_hand_step_1568_test.dart | integration | the hand-step stop names the designed hand step (`<id>:hand`), the declared contract, and the re-run remedy | SC-2 | GREEN (RED pre-fix) |
| A-1568-g1 | test/plugins/tdd/commands/make_command_hand_step_1568_test.dart | integration | GUARD (SC-7): a SCALAR-return behavior with a post-generation red keeps the honest `generation-error` stop; an UNDECLARED behavior too | SC-7, regression guard | GREEN (RED pre-fix) |
| B-1568-r1 | test/plugins/tdd/models/run_state_hand_steps_1568_test.dart | unit | `RunState.markHandStep` adds immutably; `toJson` emits `hand_steps`; `fromJson` round-trips; a legacy snapshot WITHOUT the field loads with an empty set (AC-4 persistence basis) | SC-4, RunState | GREEN (RED pre-fix) |
| C-1568-d1 | test/plugins/tdd/commands/run_driver_hand_step_1568_test.dart | unit | `RunDriverCore.summaryLine` emits ` hand_steps=N` for non-empty ids, nothing for empty (the `skipped-widget=` precedent) | SC-5, AC-2 | GREEN (RED pre-fix) |
| C-1568-d2 | test/plugins/tdd/commands/run_driver_hand_step_1568_test.dart | integration | a make child reporting `outcome=hand-step` parks the behavior (state stays pending), persists the id in run-state.json, and the run CONTINUES to the next behavior — mechanical behaviors behind the hand-step are reachable | SC-3, SC-6, AC-1/AC-3 | GREEN (RED pre-fix) |
| C-1568-d3 | test/plugins/tdd/commands/run_driver_hand_step_1568_test.dart | integration | a KNOWN hand-step id in the loaded run state is NOT re-driven on resume: the driver prints the parked line and continues; the behavior keeps pending with its honest red | SC-4, AC-4 | GREEN (RED pre-fix) |
| C-1568-d4 | test/plugins/tdd/commands/run_driver_hand_step_1568_test.dart | integration | the end-of-run terminal block names the hand-step ids with the deliberate-implementation remedy | SC-5, AC-2 | GREEN (RED pre-fix) |

Signal paths (asserted by the suites above):

- make: `make: behavior=<id> outcome=hand-step feature=<f>` — the machine
  summary stays the LAST line (the StepRunner parse contract, FR-002).
- run: `[run] <id> make -> parked (planner-declared hand-step, issue #1568)`
  — the resume/phase-2 skip line.
- run: `run: feature=<f> result=... hand_steps=N` — the end-of-run summary
  token; the ids are named in the terminal block above it.
