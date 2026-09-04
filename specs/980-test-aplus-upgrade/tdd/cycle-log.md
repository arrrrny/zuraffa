# TDD Cycle Log: Test Plugin A+ Upgrade (Spec 980)

**Feature**: `980-test-aplus-upgrade`
**Spec**: `specs/980-test-aplus-upgrade/spec.md`
**Branch**: `spec/980-test-aplus-upgrade`
**Date**: 2026-09-05

---

## Baseline

**Command**: `dart test test/plugins/test/` (after moving the three scattered files, before any implementation)
**Result**: `+13 -15 — Some tests failed` (13 passing = the moved legacy suites; 15 failing = the new spec-980 tests, failing-first as required)
**Analyzer**: `dart analyze lib test --no-fatal-warnings` — 0 errors / 0 warnings in scope on the untouched implementation (294 pre-existing infos; the full-repo `dart analyze` also shows 31 pre-existing errors inside `examples/todo_tdd/`, present on `master` too — not in CI scope `lib test`).
**Suite state pre-change**: `test/plugins/test/` did not exist; coverage lived in `test/plugins/test_builder_test.dart`, `test/commands/test_command_test.dart`, `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart`.

---

## Cycle 1 — RED (failing-first tests)

**Behavior**: all five orders of issue #980, expressed as the new suite under `test/plugins/test/`.

**Red evidence** (actual runs):

- `dart test test/plugins/test/` → `+13 -15`:
  - `test_self_certify_test.dart` — compile-RED (no `TestSelfCertifier` / `TestCertification` / `ScopedAnalysisResult` APIs) AND behavioral RED: `TestCommand.execute` on a non-compiling workspace returned `success: true` (expected `success: false` with `compile=fail` in errors).
  - `test_receipt_test.dart` — compile-RED (no `TestReceipt` / `TestReceiptStore` / `ProofFinding.kindStaleUsecase`); no `.zfa/receipts/test-<entity>.json` was ever written.
  - `test_plugin_dispatch_test.dart` — compile-RED (no injectable `certifier`, no `lastCertification`).
- `dart test test/plugins/test/openwiki_testing_doc_test.dart` → `+1 -9` (behavioral RED): openwiki/testing.md showed `package:mocktail/mocktail.dart` + `MockProductRepository`, no `ThrowingProductDataSource`, no `package:zuraffa/mock.dart`, no flavor-detection doc, no `.zfa/receipts/test-` doc.
- `dart test test/plugins/test/test_usecase_analyzer_parse_test.dart` → `+5 -2`: the five dependency/flavor **parity snapshots were GREEN against the regex implementation** (the refactor safety net — repo, service, orchestrator, mixed, all five flavors); RED on the two precision guards: "a local variable named like a repo is NOT a dependency" (the old regex matched local variables) and "test_plugin.dart contains no RegExp usage" (three regexes lived at `test_plugin.dart:318-346`).

---

## Cycle 2 — GREEN (implementation)

**Behavior**: certifier + receipts + dispatch suite + analyzer parsing + docs.

1. `lib/src/plugins/test/test_certifier.dart` (new): `TestCertification` (`{entity, tests, compile, errors[], schema:1}` + verdict line), `ScopedAnalyzer.parseMachineLines` (`dart analyze --format=machine`, ERROR-severity only), `ProcessScopedAnalyzer` (scoped per-file analyze — empirically verified `dart analyze f1 f2` only honors the last path), `TestSelfCertifier` (counts `test(...)` blocks; analyzer-that-cannot-run ⇒ `compile=fail`, never silent).
2. `lib/src/core/project/test_receipt.dart` (new): `test.v1` receipt model + `TestReceiptStore` writing `.zfa/receipts/test-<entity>.json`.
3. `lib/src/core/project/receipt_store.dart`: `loadAll` skips `test-*.json` (separate receipt kind).
4. `lib/src/core/proof/proof_checker.dart`: step 4 — test-receipt verification (`deleted` / `modified` / `stale_usecase` usecase-test-drift findings; counts fold into the report).
5. `lib/src/plugins/test/test_plugin.dart`: AST-based `_parseUseCaseFile` (+ `_resolveUseCaseType` via the exact `extends` superclass), self-certification + verdict print + per-method receipt write per dispatch branch, certifier passthrough on delegation.
6. `lib/src/commands/test_command.dart`: `--json` envelope + compile-failure ⇒ `success: false` + `exit(1)`.
7. `lib/src/plugins/test/capabilities/create_test_capability.dart`: capability success gated on the verdict (CLI `zfa test create` exits 1 via the existing #767 wiring).
8. `openwiki/testing.md`: real native-mock example (captured from an actual generation run), #354 flavor-detection table, verdict line + `--json` envelope, receipt + `zfa proof check` drift doc; `flutter test` → `dart test` (pure-Dart repo); directory tree updated.

**Green evidence**: `dart test test/plugins/test/` → `+58: All tests passed!` (57 in-process + 1 real-CLI subprocess test; the CLI test spawns the AOT-compiled `zfa` and asserts exit code 1 + verdict line + receipt written).

---

## Cycle 3 — REFACTOR

Not required (issue: "refactor (optional): none required"). The only post-green change was cosmetic: `_projectRelative` now normalizes absolute paths against the process CWD so CLI receipts store portable project-relative paths (both re-verified: suite green, real-CLI drift demo green).

---

## Cycle 4 — VERIFY (real runs)

- `dart analyze lib test --no-fatal-warnings` (CI scope): 0 errors, 0 warnings, 294 pre-existing infos, 0 issues in changed files.
- `dart test test/plugins/test/`: **58/58 pass** (`All tests passed!`).
- `dart test test/commands/`: **132/132 pass** (`All tests passed!`) — the chunked runner pre-existing quirk skips this folder (41 files > threshold 40, no subdirs with tests), so it was run explicitly.
- `tools/run_tests_chunked.sh` equivalent (resume-capable mirror, same chunk list): **75/75 chunks, 0 failed** (~2960 fast-tier tests across the logged chunks).
- `dart format .`: **0 changed** (1986 files) — zero formatting diffs.
- `bash tools/proof_smoke.sh`: **PROOF SMOKE PASSED** (all 4 gates).
- Real-CLI drift demo: `zfa test create --name FetchUser` → exit **1** + `test: entity=FetchUser tests=1 compile=fail --> fix: ...`; `echo "// drifted" >> <usecase>` then `zfa proof check` → exit **1** + `[stale_usecase] usecase/test drift: lib/src/... changed after test/domain/.../fetch_user_usecase_test.dart was generated for entity FetchUser ... regenerate with: zfa test create --name FetchUser`.
