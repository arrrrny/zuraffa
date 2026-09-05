# Tasks: 978 — service A+ upgrade

- [x] T001 [RED] Write `test/plugins/service/service_plugin_skip_verdict_test.dart`: legacy config path never yields silent empty success (skip reason + `--> fix:` printed; empty result; CLI exit 1). (behavior A1) — RED: `Which: printed nothing` (2 tests)
- [x] T002 [RED] Write `test/plugins/service/service_schema_grammar_parity_test.dart`: configSchema maps params/returns/type/init; `--init` synthesized on the create subcommand; mini treaty both directions. (behavior A2) — RED: 4 tests (schema drift)
- [x] T003 [RED] Write `test/plugins/service/make_service_triad_test.dart`: `zfa make <Entity> --service` end-to-end (service interface + DI wiring + provider, receipts). (behavior A3) — RED: hollow `abstract class ProductService {}`
- [x] T004 [RED] Write `test/plugins/service/service_method_append_test.dart`: method append preserves hand-written members, appends correctly, action `updated`. (behavior A4) — landed green: coverage gap (no test existed), behavior was correct
- [x] T005 [RED] Write `test/plugins/service/service_create_json_verdict_test.dart`: `--json` verdict envelope `{schema:1, ok, file, methods[], type}`; `--> fix:` on error paths. (behavior A5) — RED: `Actual: <null>` (3 tests)
- [x] T006 [GREEN] service_plugin.dart: remove dead guard, structured skip verdict + `--> fix:`; configSchema parity; generateWithContext entity-methods default + init.
- [x] T007 [GREEN] create_service_capability.dart: `init` in inputSchema (+type enum, params/returns defaults); verdict in ExecutionResult.data.
- [x] T008 [GREEN] capability_command.dart: verdict hook (machine mode) + `--> fix:` on missing-required error path.
- [x] T009 [GREEN] ~~service_command.dart first-party create subcommand~~ — dropped: the generic CapabilityCommand machinery (flag synthesis from the updated inputSchema + the verdict hook) covers everything; no new command class needed (plan.md updated).
- [x] T010 [VERIFY] `dart analyze` (0 new findings; 31 pre-existing master errors unchanged), `tools/run_tests_chunked.sh` (74/74 chunks green, 2919 tests, 0 failures), `dart format .` (0 remaining diffs), `git diff --stat` clean.
- [x] T011 [VERIFY] `specs/978-service-aplus-upgrade/tdd/verification.md` written from real runs: red→green evidence, 4/4 mutant spot-check kills, AC matrix, honest limitations.
