# TDD Verification Report: 077-make-engine-preset

**Feature**: `zfa make engine <Entity>` — idempotent DI, engine receipt v2, engine check (issue #1109, parent #1013)
**Date**: 2026-09-06
**Branch**: `spec/1109-make-engine-preset`
**Verdict**: **PASS**

---

## Summary

The engine preset chain is complete per the issue contract: one-shot generation
(entity → usecase → service → provider → repository → datasource → mock
`--certify` → di → **test scaffold**), idempotent DI (unregister-first +
`resetDependencies()`), the v2 engine receipt at `specs/<feature>/tdd/`
(`engine.receipt.v2` with per-method `mock_certified` + `mock_class` + sorted
`source_files`), and `zfa engine check <Entity>` with three legs (static
analysis, receipt certification, import boundary).

Idempotent DI (unregister-first guards + `resetDependencies()` emission, issue
#1102) already landed on master via `RegistrationBuilder`; this spec adds the
**executable** behavioral proof (compile + run the generated wiring) and the
remaining v2 surface.

| Deliverable | Status |
|---|---|
| Receipt v2 writer (`specs/<feature>/tdd/engine.receipt.json`, atomic overwrite, `mock_class`, sorted `source_files`) | DONE |
| `mock_class` capture (parsed from the generated mock datasource) | DONE |
| `zfa engine check` static-analysis leg (scoped `dart analyze`, findings → failures with file + message) | DONE |
| `zfa engine check` receipt leg (missing receipt / `mock_certified: false` → non-zero naming the cause) | DONE |
| Test scaffold in the engine chain (preset gains `test`; pure-Dart `package:test` imports in Flutter hosts) | DONE |
| Trust-tier behavioral suites (usecase / service / repository / datasource / mock) | DONE |
| Executable DI idempotency suite (setup-twice, reset→setup, resolvable) | DONE |
| Sandbox end-to-end validation | DONE (pure-Dart lane; see Gaps) |

---

## Behavior Coverage Matrix

| ID | Behavior | Status | Evidence |
|---|---|---|---|
| **A1** | All layers generated per requested method, command exits 0 | **DONE** | `make_engine_command_test.dart` (slow e2e, PASSED); sandbox run exit 0 |
| **A2** | Engine tree's tests pass alongside the suite | **DONE** | Sandbox: `dart test test/domain/usecases/user/` → 4/4 pass, first run, after both regens |
| **A3** | Machine-readable receipt lists every method + certification + sources | **DONE** | `engine_receipt_v2_test.dart` (5 tests); e2e 5b block |
| **A4** | Re-run completes without "already registered" | **DONE** | Sandbox second run exit 0; `di_setup_execution_test.dart` |
| **A5** | Setup twice does not throw (unregister-first) | **DONE** | `di_setup_execution_test.dart` — `SETUP_DRIVER_OK`, no "already registered" |
| **A6** | reset→setup clears and re-establishes registrations | **DONE** | Same driver: `getIt<T>()` resolves both types after reset→setup |
| **A7** | Check exits 0 on healthy slice | **DONE** | Sandbox `zfa engine check User` exit 0 (analyze leg active, 18 files); e2e step 6 |
| **A8** | UI import → non-zero naming the file | **DONE** | `engine_check_v2_test.dart` A8; sandbox failure-path proof |
| **A9** | Uncertified receipt method → non-zero naming the method | **DONE** | `engine_check_v2_test.dart` A9 (`receiptUncertified`, names `delete`) |
| **A10** | Analyze-dirty slice → non-zero with analyzer message | **DONE** | `engine_check_v2_test.dart` A10 (file + message carried) |
| **A11** | Five suites ≥2 behavioral tests each, all pass | **DONE** | usecase/service/datasource compile suites added; repository + mock pre-existing; all green |
| **A12** | Generator break fails its suite naming the artifact | **DONE** | Compile-gate fixtures assert exit 0 with per-file output; structural tests name the missing artifact |
| **U1** | Single command generates the full slice incl. test scaffold | **DONE** | Preset registry engine entry + e2e 3b |
| **U2** | `--methods` restricts generation to requested methods | **DONE** | e2e (`--methods=get,update` slice); `usecase_compile_test.dart` (delete absent) |
| **U3** | `--cache`/`--sync`/`--datasource` flags | **DONE** | Pre-existing make plumbing (schema activation sync #346); engine markers verified in plan tests |
| **U4** | Zero Flutter imports enforced as built-in check | **DONE** | `EngineFindingCode.flutterImport` guard (checker step 4); sandbox failure-path proof |
| **U5** | Registrations unregister-first | **DONE** | `di_idempotent_test.dart` (structural) + `di_setup_execution_test.dart` (executable) |
| **U6** | `resetDependencies()` alongside `setupDependencies()` | **DONE** | `di_idempotent_test.dart` + executable driver |
| **U7** | Machine-readable receipt after generation | **DONE** | `engine.receipt.v2` writer |
| **U8** | Uncertified methods visible in the receipt | **DONE** | `engine_receipt_v2_test.dart` (false survives; written even on failure) |
| **U9** | Check command: analyze + receipt + import boundary, non-zero on any failure | **DONE** | `EngineCheckCommand` wires all three legs |
| **U10** | Actionable failures (file / method / finding) | **DONE** | Every failure carries `--> fix:` naming the offender |
| **U11** | ≥2 behavioral tests per artifact type | **DONE** | See A11 |
| **U12** | Chain re-runnable without corrupting the project | **DONE** | Sandbox double-run: receipt replaced (no dupes), tests still green |

---

## Test Suite Results (ACTUAL, this branch)

### Fast tier (`tools/run_tests_chunked.sh`, all 90 chunks)
- **3484 tests passed across 83 non-empty chunks; 0 failed chunks.**
  (7 chunks are empty/skip — all-slow or no tests.)
- New suites included in the run:
  - `test/engine/engine_receipt_v2_test.dart` — 6 tests (v2 writer, atomic
    overwrite, loader resolution, mock_class capture, feature fallback)
  - `test/engine/engine_check_v2_test.dart` — 7 tests (analyze leg with
    injected runner, receipt leg, skip-without-package-config)
  - `test/plugins/di/di_setup_execution_test.dart` — 2 tests (executable
    setup-twice/reset→setup; compile bar)
  - `test/plugins/usecase/usecase_compile_test.dart` — 2 tests
  - `test/plugins/service/service_compile_test.dart` — 2 tests
  - `test/plugins/datasource/datasource_compile_test.dart` — 2 tests

### Slow tier (targeted)
- `make_engine_command_test.dart`: **3 passed / 1 failed**.
  - ✅ "generates + checks + receipts in one shot" (incl. new 3b/5b assertions)
  - ✅ "fails on a dangling getIt reference"
  - ✅ "acceptance: generated tree analyzes clean (dart analyze)"
  - ❌ "mock create --certify certifies per-method and exits 0" —
    **pre-existing on master** (verified by stashing this branch and re-running:
    identical failure; the mock certify gate's analyze leg trips on the
    unbuilt zorphy entity parts in a workspace without `zfa build`).
    Unrelated to this change; not fixed here (one PR, one spec).

### Sandbox end-to-end (the issue's proof, adapted — see Gaps)
```
# pure-Dart sandbox (zuraffa path-wired, pub get, build_runner built):
zfa make engine User --methods=get,create   # exit 0; slice + tests + receipt v2
zfa engine check User                       # exit 0 — analyze leg ACTIVE over 18 files
dart test test/domain/usecases/user/        # 4/4 pass (first run and after re-run)
zfa make engine User --methods=get,create   # second run: exit 0, receipt replaced, no dupes

# failure paths (all exit 1, actionable):
#   delete mock data → "Uncertified mock ... get/create" + --> fix:
#   inject package:flutter import → names user_repository.dart + --> fix:
#   remove receipt → "run `zfa make engine User` first" + --> fix:
```

Flutter-host project (pubspec declares `flutter: sdk: flutter`): `make engine`
exit 0; generated engine tests import `package:test/test.dart` (zero
`flutter_test` in the engine test tree); engine check green (analyze leg
skips: no package config).

### Static gates
- `dart analyze lib test --no-fatal-warnings`: **0 errors, 0 warnings**
  (105 infos, all pre-existing style notes; none introduced by this branch —
  the two initial `unnecessary_import` infos were removed).
- `dart format lib test`: **0 remaining diffs** (`--set-exit-if-changed` exits 0).

---

## Gaps Identified (honest)

1. **Flutter-host `flutter test` lane not executed end-to-end.** The sandbox's
   `flutter pub get` fails on this machine: zuraffa's `analyzer ^14.3.0` +
   `test: any` dependencies cannot co-resolve with Flutter 3.47.2's
   `flutter_test` SDK pins (test_api 0.7.12 / matcher 0.12.20). Reproduced with
   the **hosted** zuraffa 6.1.0 as well — a pre-existing ecosystem conflict,
   not introduced by this branch. The pure-Dart lane (`dart test` on the same
   generated tests) is the issue's "equivalent exclude for non-engine tests"
   and passes; the flutter-impurity property is separately enforced (generated
   tests import `package:test`, the built-in guard rejects any flutter import).
2. **Pre-existing slow-tier failure** (`mock create --certify` e2e) — see
   above; fails on master identically.
3. `zfa engine check`'s analyze leg deliberately skips (no failure) when the
   project has no `.dart_tool/package_config.json` — an unbuilt workspace
   cannot resolve imports; that state is a build-pending condition, not an
   engine-slice defect. Documented in the command output
   ("static analysis skipped").
