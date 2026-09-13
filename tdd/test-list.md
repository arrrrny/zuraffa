# TDD test list — Bug 1588 phase-2 refactor batch + parked exempt

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| T-1588-exempt-1 | test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart | acceptance | a parked behavior's red test does not poison the gate — `--exempt-behaviors C1` lets the refactor proceed (exit 0), exclusion named honestly | SC-2, FR-1588-2 | GREEN |
| T-1588-exempt-2 | test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart | acceptance | without the flag the refusal stands — the absolute-green contract is preserved for a flag-less standalone refactor | FR-001 (048), FR-1588-2 | GREEN |
| T-1588-exempt-3 | test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart | unit | the exemption never masks a NON-exempt failure — a second red test outside the exempt set still refuses, failure named | FR-1588-2, U18 (safe failure) | GREEN |
| T-1588-exempt-4 | test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart | unit | an exempt id with no registered artifact is ignored (fail-open) and does not weaken the gate | FR-1588-2 | GREEN |
| T-1588-batch-1 | test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart | acceptance | the second `--pass-batch` invocation of an unchanged tree inherits the gate — zero suite runs, exit 0, ledger recorded, hit named | SC-1, SC-3, FR-1588-1 | GREEN |
| T-1588-batch-2 | test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart | unit | tree drift invalidates the ledger — the next `--pass-batch` invocation re-runs the full pipeline | FR-1588-1 (safe failure) | GREEN |
| T-1588-batch-3 | test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart | unit | a flag-less invocation never reads the ledger — the standalone contract keeps the full pipeline | FR-001 (048), FR-1588-1 | GREEN |
| T-1588-driver-1 | test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart | acceptance | the phase-2b refactor spawn carries `--pass-batch` and the parked ids as `--exempt-behaviors`; greens reach done, the park stays blocked | SC-1, SC-2, FR-1588-1/2 | GREEN |
| T-1588-driver-2 | test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart | acceptance | with no parked behaviors the spawn carries `--pass-batch` and NO `--exempt-behaviors`; per-behavior spawns preserved | FR-1588-1 | GREEN |

Red evidence: recorded before implementation — the RED run of the bug file
against the un-patched tree scored 1 passed / 8 failed (the 8 new-contract
assertions; the contract guard T-1588-exempt-2 is expected green both
ways). See `.specify/bugs/1588-phase2-refactor-batch-and-parked-exempt/test.md`.
