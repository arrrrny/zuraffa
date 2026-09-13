# TDD test list — Bug #1551 acceptance compose no-green-units hard stop

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1551-1 | test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart | acceptance | an acceptance make whose compose step reports no-green-units grades unexpressible — never generation-error; stop names #1551 + phase 2; #1036 subject restore holds; no green evidence | FR-1551, make_command._composeOutputReportsNoGreenUnits | GREEN |
| A-1551-2 | test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart | unit | the final make summary line carries exactly outcome=unexpressible — the kv contract the run driver's StepRunner parses and the bug #625/#826 deferral arm consumes | FR-1551, MakeOutcome.unexpressible.label | GREEN |
| A-1551-3 | test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart | acceptance | the same make composes and certifies green once the unit IS green (the #1512 surface unbroken — compose then build executed, green evidence appended) | FR-1551, compose-when-green anchors | GREEN |
| A-1551-4 | test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart | unit | a direct `zfa tdd compose` keeps its honest no-green-units stop (exit 1, summary line, no subject rewrite) — the compose surface is unchanged | FR-1551, compose_command surface | GREEN |
| A-1551-a10 | test/plugins/tdd/make_command_test.dart | acceptance | A10 re-faithed: zero-anchor acceptance make grades unexpressible (deferral) with the REAL production compose transcript, never generation-error | FR-1551, MakeOutcome grading | GREEN |

## Changed source surface (hard constraint: grading only)

| file | change |
| ---- | ------ |
| lib/src/plugins/tdd/commands/make_command.dart | the pipeline-failure handler: a new arm grades the composition step's `no-green-units` child verdict `unexpressible` (+ `_isCompositionStepArgs`, `_composeOutputReportsNoGreenUnits` helpers). Byte-identical neighbors: compose_command.dart, composition_targets.dart, composition_planner.dart, generation_planner.dart, run_driver_core.dart, step_runner.dart |
| test/plugins/tdd/make_command_test.dart | A10 re-faithed to the production transcript + the corrected deferral contract (was ALREADY RED on pristine master) |
| test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart | NEW — the four pins above |
