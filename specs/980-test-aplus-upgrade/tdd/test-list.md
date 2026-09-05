# Test List: 980-test-aplus-upgrade

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md` (issue #980).

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | Generating a deliberately non-compiling test fixture fails with the verdict line (`test: entity=<X> tests=<N> compile=fail --> fix: <first error>`) and a non-zero exit. | AC-US1-1 / FR-001 | DONE |
| A2 | A compiling generation certifies `compile=pass` and succeeds. | AC-US1-2 / FR-001 | DONE |
| A3 | The direct test command grammar supports `--json` and prints `{entity, tests, compile, errors[], schema:1}` as a parseable object. | AC-US1-3 / FR-002 | DONE |
| A4 | A successful generation writes `.zfa/receipts/test-<entity>.json` mapping every generated test to its usecase method + covered acceptance path. | AC-US2-1 / FR-003 | DONE |
| A5 | `zfa proof check` flags a drifted usecase/test pair (usecase changed after the receipt) with a finding naming the pair. | AC-US2-2 / FR-004 | DONE |
| A6 | `zfa proof check` stays green for an unchanged test receipt. | AC-US2-3 / FR-004 | DONE |
| A7 | The three scattered test files live under `test/plugins/test/` (moved, not duplicated). | AC-US3-1 / FR-005 | DONE |
| A8 | A direct `TestPlugin.generate` orchestrator config produces the orchestrator test file. | AC-US3-2 / FR-005 | DONE |
| A9 | A direct `TestPlugin.generate` polymorphic config produces one file per variant. | AC-US3-3 / FR-005 | DONE |
| A10 | `buildConfigFromUseCase` resolves deps/flavor identically to the regex behavior on every fixture (snapshot parity). | AC-US4-1 / FR-006 | DONE |
| A11 | No regex usecase parsing remains in the test plugin. | AC-US4-2 / FR-006 | DONE |
| A12 | openwiki/testing.md shows native-mock output (no mocktail) and documents #354 flavor detection. | AC-US5-1, US5-2 / FR-007 | DONE |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `TestCertification.toJson()` emits exactly `{entity, tests, compile, errors[], schema:1}` with `schema` the integer 1. | FR-002 | DONE |
| U2 | The verdict line formats `test: entity=<X> tests=<N> compile=pass` (pass) / `test: entity=<X> tests=<N> compile=fail --> fix: <first error>` (fail). | FR-001 | DONE |
| U3 | The scoped analyzer parses `dart analyze --format=machine` ERROR lines into `{file, line, message}` records and ignores non-ERROR lines. | FR-001 | DONE |
| U4 | The certifier counts generated `test(...)` blocks across files for `tests=<N>`. | FR-001 | DONE |
| U5 | Certification is skipped for dry-run generation (no files on disk, no false verdict). | FR-001 | DONE |
| U6 | `TestCommand.execute` returns `success=false` with the verdict in errors when compile fails (the branch that exits 1). | FR-001 | DONE |
| U7 | `CreateTestCapability.execute` returns `success=false` and carries the certification in `data` when compile fails. | FR-001 | DONE |
| U8 | `TestReceiptStore` round-trips a receipt (write → load) with per-test entries `{name, file, method, acceptance_path, usecase, digests}`. | FR-003 | DONE |
| U9 | Entity receipts record one entry per generated test (success + failure paths) per method, bound to that method's usecase file digest. | FR-003 | DONE |
| U10 | `ReceiptStore.loadAll` skips `test-*.json` basenames (separate kind) — test receipts do not corrupt the proof.v1 scan. | FR-004 | DONE |
| U11 | `ProofChecker` emits `deleted` for a missing receipted test file and `modified` for a tampered one. | FR-004 | DONE |
| U12 | `ProofChecker` emits `stale_usecase` when the usecase digest differs from the receipt record, naming the usecase/test pair. | FR-004 | DONE |
| U13 | `_parseUseCaseFile` (via `buildConfigFromUseCase`) extracts repo/service/usecase deps from `final XxxRepository _x;` style fields. | FR-006 | DONE |
| U14 | Flavor resolution maps `UseCase`/`StreamUseCase`/`SyncUseCase`/`BackgroundUseCase`/`OsBackgroundTaskUseCase` extends clauses to usecase/sync/stream/background/os_background. | FR-006 | DONE |
| U15 | Orchestrator detection: composed usecase fields with no repo/service fields ⇒ isOrchestrator. | FR-006 | DONE |
| U16 | `TestPlugin.generate` returns `[]` when `generateTest` is false and delegates to a reconfigured plugin when the config output dir differs. | FR-005 | DONE |
| U17 | openwiki/testing.md contains `Throwing{Entity}DataSource`-style native mock markers and `package:zuraffa/mock.dart`, and no `package:mocktail/mocktail.dart`. | FR-007 | DONE |
| U18 | openwiki/testing.md documents flavor detection: `flutter: sdk: flutter` in pubspec ⇒ `flutter_test`, else `package:test/test.dart`. | FR-007 | DONE |
