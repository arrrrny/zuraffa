# Tasks: Test Plugin A+ Upgrade (Spec 980)

**Branch**: `spec/980-test-aplus-upgrade` | **Date**: 2026-09-05 | **Spec**: `specs/980-test-aplus-upgrade/spec.md`

## TDD Task List (red → green per task)

- [x] T1 RED: move the three scattered files under `test/plugins/test/` (test_builder_test.dart, test_command_test.dart, issue_354_test_plugin_flutter_vs_dart_imports_test.dart) — moving only, tags preserved.
- [x] T2 RED: `test/plugins/test/test_self_certify_test.dart` — verdict line + `--json` envelope + non-compiling fixture ⇒ success=false/exit path (RED today: no certification exists).
- [x] T3 RED: `test/plugins/test/test_receipt_test.dart` — `.zfa/receipts/test-<entity>.json` written with per-method mapping; `zfa proof check` (ProofChecker) flags drifted usecase/test pair; green when unchanged (RED today: no test receipts, no drift findings).
- [x] T4 RED: `test/plugins/test/test_plugin_dispatch_test.dart` — direct `TestPlugin.generate` entity/orchestrator/polymorphic/custom/dispatch-delegation coverage.
- [x] T5 RED (parity baseline first): `test/plugins/test/test_usecase_analyzer_parse_test.dart` — snapshot parity of `buildConfigFromUseCase` on fixtures; then swap regex→analyzer keeping it green.
- [x] T6 RED: `test/plugins/test/openwiki_testing_doc_test.dart` — native-mock markers, no mocktail, #354 flavor detection documented (RED today: mocktail example).
- [x] T7 GREEN: `lib/src/plugins/test/test_certifier.dart` (TestCertification + scoped dart analyze runner, injectable for tests).
- [x] T8 GREEN: `lib/src/core/project/test_receipt.dart` (test.v1 model + store) + `ReceiptStore.loadAll` prefix skip + `ProofChecker` stale_usecase/deleted/modified findings for test receipts.
- [x] T9 GREEN: `TestPlugin.generate` self-certification + receipt write + verdict line; `TestCommand` `--json` + failure exit; `CreateTestCapability` success gate.
- [x] T10 GREEN: `_parseUseCaseFile` analyzer rewrite (no regexes remain).
- [x] T11 GREEN: openwiki/testing.md generated-test section rewrite (real native-mock output + flavor detection).
- [x] T12 VERIFY: `dart analyze` + `dart test test/plugins/test/` + `dart format .` (zero diff) + `tools/run_tests_chunked.sh` for the fast tier.
- [x] T13 `/speckit.tdd.verify` → `specs/980-test-aplus-upgrade/tdd/verification.md` with REAL results.
- [x] T14 PR: push branch, open PR to master, `Closes #980`.

## Acceptance Mapping

| Acceptance criterion (issue #980) | Proving task(s) |
|---|---|
| Non-compiling fixture → verdict line + non-zero exit, tested | T2 (+ real CLI exit proof) |
| Receipt written; proof check flags drifted pair, tested | T3 |
| Orchestrator + polymorphic dispatch covered by direct tests | T4 |
| No regex usecase parsing remains; snapshot parity proven | T5/T10 |
| openwiki example matches reality | T6/T11 |
