# TDD Verification Report: Test Plugin A+ Upgrade

**Feature**: `980-test-aplus-upgrade`
**Spec**: `specs/980-test-aplus-upgrade/spec.md`
**Plan**: `specs/980-test-aplus-upgrade/plan.md`
**Branch**: `spec/980-test-aplus-upgrade`
**Date**: 2026-09-05
**Toolchain**: Dart SDK 3.13.3 (CI pins 3.13.2), pure-Dart package

---

## Verdict: PASS

All five acceptance criteria of issue #980 are **PROVED by actually-run tests** (every number below comes from a real run on this branch; commands and raw tails are recorded in `tdd/cycle-log.md`).

---

## Test Coverage Summary

| Suite | Command | Result |
|---|---|---|
| Dedicated test-plugin suite | `dart test test/plugins/test/` | **58 passed, 0 failed** |
| Commands (fast tier) | `dart test test/commands/` | **132 passed, 0 failed** |
| Fast tier, chunked (75 chunks) | `tools/run_tests_chunked.sh` mirror | **75/75 chunks, 0 failed** (~2960 tests) |
| Proof smoke (CI job) | `bash tools/proof_smoke.sh` | **PROOF SMOKE PASSED** |
| Regression tier (moved #354 file) | `dart test --preset=regression test/plugins/test/issue_354_...` | **6 passed, 0 failed** |
| Analyzer | `dart analyze lib test --no-fatal-warnings` | **0 errors / 0 warnings** in scope (294 pre-existing infos, unchanged vs master) |
| Formatter | `dart format .` | **0 changed** (1986 files) |

---

## Acceptance Criteria — PROVED vs not

| #980 acceptance criterion | Status | Proof (actually run) |
|---|---|---|
| Generating a deliberately non-compiling test fixture fails with the verdict line + non-zero exit — tested | **PROVED** | `test/plugins/test/test_self_certify_test.dart` "deliberately non-compiling fixture fails with verdict + fix line" (real `dart analyze` subprocess) and "A1/U6 — non-compiling generation fails the command" (`TestCommand` returns `success:false` with the verdict in errors — the `exit(1)` branch). **Real CLI proof**: `test/plugins/test/test_self_certify_cli_test.dart` spawns the AOT-compiled `zfa`, asserts **exitCode == 1**, the `test: entity=FetchUser ... compile=fail --> fix: ...` line on stdout, and the receipt written. Manual CLI run reproduced: `FRESH FAIL EXIT: 1`. |
| Receipt written; proof check flags drifted usecase/test pair — tested | **PROVED** | `test/plugins/test/test_receipt_test.dart`: receipt written with per-test `{name, method, acceptance_path, usecase, digests}` matching on-disk digests; drift ⇒ `ProofFinding.kindStaleUsecase` naming the pair, `report.ok == false`; unchanged pair ⇒ zero findings; deleted/tampered test files ⇒ `deleted`/`modified`. Real CLI: `zfa proof check` exit **1** with `[stale_usecase] usecase/test drift: lib/src/... changed after test/... was generated ... regenerate with: zfa test create --name FetchUser`. |
| Orchestrator + polymorphic dispatch paths covered by direct tests | **PROVED** | `test/plugins/test/test_plugin_dispatch_test.dart`: A8 orchestrator config ⇒ `process_checkout_usecase_test.dart` with `FakeValidateCartUseCase`/`FakeCreateOrderUseCase`; A9 polymorphic config ⇒ one file per variant (`payment_fast_usecase_test.dart`, `payment_slow_usecase_test.dart`) with `FakePaymentRepository`; plus entity/custom dispatch, invalid-method filtering, `generateTest:false` ⇒ `[]`, output-dir delegation, dry-run certification skip. |
| No regex usecase parsing remains; snapshot parity proven | **PROVED** | `test/plugins/test/test_usecase_analyzer_parse_test.dart`: five regex-era parity snapshots (repo / service / orchestrator / mixed / all five flavors) were **green before the swap (against the regex code) and stayed green after the analyzer rewrite** — behavior neutrality proven. Two precision guards now green: local variables never count as dependencies; `test_plugin.dart` contains no `RegExp(` (the three regexes at `test_plugin.dart:318-346` are gone — replaced by a `FileParser` AST walk, the same pattern as the method_append builders). |
| openwiki example matches reality | **PROVED** | `test/plugins/test/openwiki_testing_doc_test.dart` (10 assertions): `ThrowingProductDataSource`, `ProductMockDataSource`, `package:zuraffa/mock.dart`, real path convention `test/domain/usecases/product/get_product_usecase_test.dart`, **no** `package:mocktail/mocktail.dart` / `MockProductRepository`; #354 flavor detection documented (`package:test/test.dart` vs `flutter_test` via `sdk: flutter`); verdict-line + receipt documentation markers. The example was captured from an actual generation run (`tool/gen_openwiki_quote.dart` during development). |

**Not proved / out of scope**: `zfa make --test` (pipeline path) prints the verdict and writes the receipt but does not fail the overall `make` result — deliberately: the four existing slow-tier suites (#294, #508, #302, toggle-method) generate tests in dependency-free sandboxes where imports cannot resolve; gating `make` would break them and change their intent. The test-generation commands themselves (`zfa test <Entity>` and `zfa test create --name <Entity>`) both exit 1 on non-compiling output, which is the acceptance contract.

---

## Red → Green Evidence

- **RED** (failing-first, pre-implementation): `dart test test/plugins/test/` → `+13 -15`; `openwiki_testing_doc_test.dart` → `+1 -9`; parity baseline `+5 -2` (5 green regex-parity snapshots = the refactor net; 2 red precision guards). `TestCommand` returned `success: true` on a non-compiling workspace.
- **GREEN**: `dart test test/plugins/test/` → `+58: All tests passed!`

Full per-cycle detail: `specs/980-test-aplus-upgrade/tdd/cycle-log.md`.

---

## Files Changed

**New (lib)**: `lib/src/plugins/test/test_certifier.dart`, `lib/src/core/project/test_receipt.dart`
**Modified (lib)**: `test_plugin.dart` (AST parsing + self-certification + receipts + delegation passthrough), `test_command.dart` (`--json` + failure exit), `create_test_capability.dart` (success gate), `receipt_store.dart` (test-receipt kind skip), `proof_checker.dart` (stale_usecase drift findings)
**Tests**: 3 files moved under `test/plugins/test/` + 6 new suites (dispatch, self-certify, real-CLI exit proof, receipts/drift, analyzer parity, openwiki doc markers) — 58 fast-tier tests
**Docs**: `openwiki/testing.md` (real native-mock example, #354 flavor detection, verdict/receipt docs, `dart test`)
**Spec artifacts**: `specs/980-test-aplus-upgrade/` (spec, plan, tasks, tdd/test-list, tdd/cycle-log, this report)

## Constraints honored

- Generated test semantics unchanged: `TestBuilder` output bytes untouched (all builder tests green, no builder code modified).
- Failing-first: every new behavior landed red before green (cycle-log).
- Native mocks stay; no mocktail anywhere in generated output or docs.
