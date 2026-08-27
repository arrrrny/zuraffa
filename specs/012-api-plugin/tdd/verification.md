# TDD Verification Report: API Plugin — Auto-Generated Runtime RPC Bridge

**Feature**: `012-api-plugin`  
**Spec**: `specs/012-api-plugin/spec.md`  
**Plan**: `specs/012-api-plugin/plan.md`  
**Git HEAD**: `614e648`  
**Date**: 2026-08-26

---

## Verdict: PASS_WITH_GAPS

The API plugin implementation is **functionally complete** for its core use cases (codegen, runtime bridge, discovery, streams). However, several **acceptance-level tests are missing** that would fully verify the integration.

---

## Test Coverage Summary

| Category | Total | DONE | PENDING | BLOCKED |
|----------|-------|------|---------|---------|
| Acceptance (AC) | 27 | 12 | 15 | 0 |
| Unit (U) | 58 | 38 | 20 | 0 |
| **Total** | **85** | **50** | **35** | **0** |

---

## Passing Tests (Core Functionality Verified)

### Codegen Layer (`test/plugins/api/`)
- ✅ Bridge file generated at correct path
- ✅ `register{Entity}ApiBridge()` function with correct name
- ✅ Handler functions for each UseCase
- ✅ `ZuraffaApiBridge.registerEndpoint()` calls with correct `ApiEndpoint`
- ✅ Empty result when zero UseCases found
- ✅ `dryRun` mode works (preview without writing)
- ✅ Import convention `_usecase` (not `_use_case`)
- ✅ Custom `--domain` override works
- ✅ Multiple UseCases → one file with N handlers
- ✅ Release/profile mode guards emitted correctly (using `const bool.fromEnvironment`)
- ✅ Primitive param handlers read `args['value']` directly
- ✅ `NoParams` handlers use `const NoParams()`
- ✅ Complex param handlers deserialize via `fromJson` with error path
- ✅ Stream handlers with primitive/complex params
- ✅ Generic type arguments survive intact (no truncation)

### Runtime Layer (`test/core/api_bridge_test.dart`)
- ✅ `serializeResult` success → `{"status": "success", "data": ...}`
- ✅ `serializeResult` failure → `{"status": "error", "failure": {"type": ..., "message": ...}}`
- ✅ `failure.runtimeType.toString()` in `failure.type`
- ✅ `errorResponse()` returns correct error shape
- ✅ `registerEndpoint` adds to `_endpoints` list
- ✅ Discovery `_handleList` returns JSON catalog (excludes meta-extensions)
- ✅ Empty registry → `[]`
- ✅ Stream subscription stored via `registerStreamSubscription`
- ✅ `_pollStream` returns `pending` before first emission
- ✅ `_pollStream` returns latest value after emission
- ✅ `_cancelStream` cancels + removes subscription
- ✅ Two concurrent streams independent
- ✅ Missing `subscriptionId` → `badRequest`
- ✅ `generateSubscriptionId` produces unique UUIDs

### Analysis
- ✅ `dart analyze lib/src/plugins/api/ lib/src/core/api_bridge.dart lib/src/core/api_endpoint.dart` — zero issues

---

## Gaps (Missing Acceptance Tests)

| ID | Gap | Impact | Tasks |
|----|-----|--------|-------|
| T036 | No `api_command_test.dart` — CLI command behavior untested | Medium | U2–U5 |
| T039 | No `dart analyze` test on generated output in temp project | High | AC-02 |
| T044 | No runtime test for release/profile mode safety gates | High | AC-16–AC-19, U49 |
| T045 | No test asserting `ApiPlugin` in `PluginLoader._plugins()` | Low | U26 |
| T046 | **No `example/` app exists** — integration test missing entirely | Critical | AC-23–AC-27, A7 |
| T047 | No end-to-end `zfa api Product` acceptance test | High | A1 |
| T048 | No in-process handler invocation test for all param types | High | A2 |
| T049 | No unexpected exception handling acceptance test | Medium | A3 |
| T050 | No stream lifecycle acceptance test | Medium | A4 |
| T051 | No release-mode build acceptance test | High | A5 |
| T052 | No `_list` catalog accuracy acceptance test | Medium | A6 |

---

## Root Cause Analysis

The implementation tasks (Phases 1–6 in `tasks.md`) were marked complete, but **Phase 8 (Integration/Acceptance Test)** was never actually implemented:

1. **`example/` directory doesn't exist** — the integration test file `example/test/api_bridge_integration_test.dart` was never created
2. **Acceptance tests (T047–T052)** depend on the integration test and end-to-end execution
3. **Safety gate tests (T044)** require mocking `dart.vm.product` / `dart.vm.profile` environment constants, which is non-trivial in Dart test environment

---

## Recommendations

### Immediate (to reach PASS)
1. **Create `example/` app** with Product/Concert entities, UseCases, mock datasources
2. **Write `example/test/api_bridge_integration_test.dart`** per `tasks.md` T032–T035
3. **Add `api_command_test.dart`** for CLI command behavior (T036)
4. **Add release/profile mode test** using `runZoned` or separate test process (T044)

### Before Release
5. **Add `dart analyze` integration test** (T039) — write generated file to temp project with zuraffa dependency, run analyze
6. **Run all acceptance tests** (T047–T052) as part of CI

---

## Known Pre-Existing Issues (Unrelated)

The full test suite (`dart test test`) has 2 pre-existing failures unrelated to the API plugin:
1. `test/plugins/mcp/mcp_sse_server_test.dart` — 30s timeout (flaky auth test)
2. `test/commands/make_command_test.dart` — cache plugin `dirName` getter error + timeout

These do not affect the API plugin verification.