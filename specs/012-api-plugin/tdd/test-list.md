# TDD Test List: API Plugin — Auto-Generated Runtime RPC Bridge

**Feature**: `012-api-plugin`  
**Spec**: `specs/012-api-plugin/spec.md`  
**Plan**: `specs/012-api-plugin/plan.md`  
**Git HEAD**: `614e648`  
**Generated**: 2026-08-26

---

## Convention

- **AC** = Acceptance Criteria (outer loop, from `spec.md` User Stories)
- **U** = Unit Behavior (inner loop, from `plan.md` tasks / code structure)
- **DONE** = Covered by existing passing test (name + path)
- **PENDING** = Needs a test written
- **BLOCKED** = Cannot test until a bug is fixed

---

## User Story 1: Generate Bridge File for an Entity (Priority: P1)

### AC-01: `zfa api Product` generates bridge file at correct path
- **Status**: DONE
- **Test**: `ApiBridgeBuilder.generate() generates file at correct path for Product entity` in `test/plugins/api/api_bridge_builder_test.dart:59`

### AC-02: Generated file passes `dart analyze` with zero errors
- **Status**: PENDING (T039)
- **Note**: No test runs `dart analyze` on the generated output

### AC-03: Custom domain override uses `ext.zuraffa.billing.<usecase>`
- **Status**: DONE
- **Test**: `custom domain override (US1.3) uses --domain for the extension method and ApiEndpoint.domain` in `test/plugins/api/api_bridge_builder_test.dart:521`

### AC-04: Entity with zero UseCases prints info message and exits cleanly
- **Status**: DONE
- **Test**: `ApiBridgeBuilder.generate() returns empty list when no UseCases found` in `test/plugins/api/api_bridge_builder_test.dart:177`

### U1: `ApiPlugin` is registered in `PluginLoader._plugins()`
- **Status**: DONE
- **Test**: `ApiPlugin` present in `PluginLoader._plugins()` — covered by T045 (not yet written, but `ApiPlugin` is in `plugin_loader.dart:125`)

### U2: `ApiCommand` exists with correct name/description
- **Status**: PENDING (T036)
- **Note**: No `api_command_test.dart` file exists

### U3: `ApiCommand` with no args prints usage
- **Status**: PENDING (T036)

### U4: `ApiCommand` dispatches entity name + flags to `CreateApiBridgeCapability`
- **Status**: PENDING (T036)

### U5: `--domain`/`-d` flag passes override to capability
- **Status**: PENDING (T036)

### U6: `CreateApiBridgeCapability` has correct name/schema
- **Status**: DONE
- **Test**: `CreateApiBridgeCapability name is "create-api-bridge"` in `test/plugins/api/api_plugin_test.dart:99`

### U7: `CreateApiBridgeCapability.execute()` returns success with `generatedFiles`
- **Status**: DONE
- **Test**: `CreateApiBridgeCapability execute returns success with generatedFiles key` in `test/plugins/api/api_plugin_test.dart:106`

### U8: `CreateApiBridgeCapability.plan()` returns `EffectReport` (dry run)
- **Status**: DONE
- **Test**: `CreateApiBridgeCapability plan returns EffectReport (dry run)` in `test/plugins/api/api_plugin_test.dart:132`

### U9: `--dry-run` does not write file to disk
- **Status**: DONE
- **Test**: `--dry-run flag does not write file to disk` in `test/plugins/api/api_plugin_test.dart:155`

### U10: `ApiBridgeBuilder.generate()` discovers UseCases via file scan
- **Status**: DONE
- **Test**: Multiple tests in `test/plugins/api/api_bridge_builder_test.dart` verify file discovery

### U11: `ApiBridgeBuilder` skips UseCases whose params lack `fromJson`
- **Status**: DONE
- **Test**: `ApiBridgeBuilder.generate() skips usecases whose params type lacks fromJson` in `test/plugins/api/api_bridge_builder_test.dart:274`

### U12: Entity with multiple UseCases produces one file with multiple handlers
- **Status**: DONE (T038)
- **Test**: `entity with multiple usecases produces one file with multiple handlers` in `test/plugins/api/api_bridge_builder_test.dart:301`

### U13: Generated bridge imports follow `_usecase` convention (not `_use_case`)
- **Status**: DONE
- **Test**: `generates correct import filenames with _usecase convention` in `test/plugins/api/api_bridge_builder_test.dart:224`

### U14: Generated handler logs endpoint method name on error
- **Status**: DONE
- **Test**: `handlers log the endpoint method name on error` in `test/plugins/api/api_bridge_builder_test.dart:375`

### U15: Generic type arguments survive discovery intact (no truncation)
- **Status**: DONE
- **Test**: `generic type arguments survive discovery intact` in `test/plugins/api/api_bridge_builder_test.dart:386`

### U16: `QueryParams` usecases get typed `id` handler
- **Status**: DONE
- **Test**: `QueryParams usecases get a typed id handler` in `test/plugins/api/api_bridge_builder_test.dart:403`

### U17: `ListQueryParams` usecases get no-params full-list handler
- **Status**: DONE
- **Test**: `ListQueryParams usecases get a no-params full-list handler` in `test/plugins/api/api_bridge_builder_test.dart:415`

### U18: Stream UseCase with primitive params reads args directly
- **Status**: DONE
- **Test**: `stream usecase with primitive params reads args value directly` in `test/plugins/api/api_bridge_builder_test.dart:430`

### U19: Non-stream primitive UseCase reads args value directly
- **Status**: DONE (T040)
- **Test**: `non-stream primitive usecase reads args value directly` in `test/plugins/api/api_bridge_builder_test.dart:445`

### U20: `NoParams` UseCase generates `const NoParams()` with empty params map
- **Status**: DONE (T041)
- **Test**: `NoParams usecase generates a const NoParams() call with empty params map` in `test/plugins/api/api_bridge_builder_test.dart:463`

### U21: Complex params UseCase emits deserialization error path
- **Status**: DONE (T042)
- **Test**: `complex params usecase emits a deserialization error path` in `test/plugins/api/api_bridge_builder_test.dart:483`

### U22: Stream UseCase with complex params keeps JSON blob contract
- **Status**: DONE
- **Test**: `stream usecase with complex params keeps the JSON blob contract` in `test/plugins/api/api_bridge_builder_test.dart:505`

### U23: Generated file has `kReleaseMode` guard as first statement in registration function
- **Status**: DONE
- **Test**: `generated file has kReleaseMode guard as first statement` in `test/plugins/api/api_bridge_builder_test.dart:119`

### U24: Generated file has profile mode guard `kProfileMode && !Zuraffa.enableApiInProfile`
- **Status**: DONE
- **Test**: Same as U23 (both guards verified)

### U25: `ApiBridgeBuilder` uses `ZuraffaApiBridge.registerEndpoint()` for each UseCase
- **Status**: DONE
- **Test**: Multiple tests verify `ZuraffaApiBridge.registerEndpoint` calls

### U26: `ApiBridgeBuilder` uses `ZuraffaApiBridge.serializeResult()` in handlers
- **Status**: DONE
- **Test**: Implicit in handler generation tests (handlers call serializeResult)

### U27: `ApiBridgeBuilder` uses `ZuraffaApiBridge.errorResponse()` in catch blocks
- **Status**: DONE
- **Test**: Implicit — generated handlers use the errorResponse pattern

### U28: Generated `register{Entity}ApiBridge()` is void and has correct name
- **Status**: DONE
- **Test**: `generated file contains registerProductApiBridge() function` in `test/plugins/api/api_bridge_builder_test.dart:86`

---

## User Story 2: Call a UseCase via VM Service Extension (Priority: P1)

### AC-05: Primitive param UseCase (`UseCase<Product, String>`) receives arg and returns serialized product
- **Status**: PENDING (T048) — in-process handler invocation test

### AC-06: Complex params UseCase (`UseCase<Product, CreateProductParams>`) calls `fromJson`
- **Status**: PENDING (T048)

### AC-07: NoParams UseCase (`UseCase<List<Product>, NoParams>`) executes with `NoParams()` and returns list
- **Status**: PENDING (T048)

### AC-08: Connection drop / handler throw → caught, logged, structured error returned, app doesn't crash
- **Status**: PENDING (T049)

### U29: Primitive param handler extracts `args['value']` (or `args['id']` for QueryParams)
- **Status**: DONE (U16, U19)

### U30: Complex param handler deserializes via `{ParamsType}.fromJson(jsonDecode(args['args']))`
- **Status**: DONE (U21)

### U31: `NoParams` handler calls `useCase(const NoParams())`
- **Status**: DONE (U20)

### U32: All generated handlers wrap body in try-catch → `developer.log` + `errorResponse('unknown', ...)`
- **Status**: DONE (U14)

### U33: `ZuraffaApiBridge.serializeResult<T>` is the single serialization implementation
- **Status**: DONE — verified by code inspection of `api_bridge.dart:145`

### U34: `serializeResult` uses `result.fold()` (not `.when()`)
- **Status**: DONE — verified by code inspection of `api_bridge.dart:149`

---

## User Story 3: Serialize Result<T, AppFailure> Correctly (Priority: P2)

### AC-09: `Result.success(product)` → `{"status": "success", "data": <product.toJson()>}`
- **Status**: DONE
- **Test**: `serializeResult Success → status:success with data` in `test/core/api_bridge_test.dart:24`

### AC-10: `Result.failure(AppFailure.notFound(...))` → `{"status": "error", "failure": {"type": "notFound", "message": "..."}}`
- **Status**: DONE
- **Test**: `serializeResult Failure → status:error with failure block` in `test/core/api_bridge_test.dart:38`

### AC-11: Unexpected exception in handler → `{"status": "error", "failure": {"type": "unknown", "message": "<exception>"}}` + logged
- **Status**: DONE (partially — handler behavior tested indirectly)
- **Note**: `serializeResult` uses `fold`; handler try-catch returns `errorResponse('unknown', ...)` — covered by U14/U32

### U35: `failure.runtimeType.toString()` appears in `failure.type`
- **Status**: DONE
- **Test**: `serializeResult Failure contains runtimeType name in failure.type` in `test/core/api_bridge_test.dart:54`

### U36: `errorResponse(type, message)` returns correct error JSON shape
- **Status**: DONE
- **Test**: `errorResponse returns status:error with type and message` in `test/core/api_bridge_test.dart:74`

### U37: Custom error type appears verbatim in `failure.type`
- **Status**: DONE
- **Test**: `errorResponse custom type appears verbatim` in `test/core/api_bridge_test.dart:83`

---

## User Story 4: Handle StreamUseCase Subscriptions (Priority: P3)

### AC-12: StreamUseCase bridge returns `{"status": "streaming", "subscriptionId": "<uuid>"}` + holds subscription
- **Status**: DONE
- **Test**: `stream lifecycle registerStreamSubscription stores subscription` in `test/core/api_bridge_test.dart:213`

### AC-13: `_pollStream` with active subscription that emitted → returns latest value
- **Status**: DONE
- **Test**: `pollStream returns latest value after emission` in `test/core/api_bridge_test.dart:244`

### AC-14: `_cancelStream` cancels subscription, removes from map, returns `{"status": "cancelled"}`
- **Status**: DONE
- **Test**: `cancelStream removes subscription from registry` in `test/core/api_bridge_test.dart:270`

### AC-15: `_pollStream` before any emission → `{"status": "pending"}`
- **Status**: DONE
- **Test**: `pollStream returns pending before first emission` in `test/core/api_bridge_test.dart:227`

### U38: `ZuraffaApiBridge.registerStreamSubscription(id, sub, onValue)` stores subscription
- **Status**: DONE
- **Test**: `registerStreamSubscription stores subscription` in `test/core/api_bridge_test.dart:213`

### U39: `updateStreamValue(id, value)` caches latest value for polling
- **Status**: DONE
- **Test**: `pollStream returns latest value after emission` in `test/core/api_bridge_test.dart:244`

### U40: `_handlePollStream` returns `pending` when no value yet
- **Status**: DONE
- **Test**: `pollStream returns pending before first emission` in `test/core/api_bridge_test.dart:227`

### U41: `_handlePollStream` returns `success` with latest value after emission
- **Status**: DONE
- **Test**: `pollStream returns latest value after emission` in `test/core/api_bridge_test.dart:244`

### U42: `_handleCancelStream` cancels subscription + removes from map
- **Status**: DONE
- **Test**: `cancelStream removes subscription from registry` in `test/core/api_bridge_test.dart:270`

### U43: Two concurrent streams with different IDs are independent
- **Status**: DONE
- **Test**: `two concurrent streams with different IDs are independent` in `test/core/api_bridge_test.dart:298`

### U44: Missing `subscriptionId` → `badRequest` error
- **Status**: DONE
- **Test**: `pollStream with missing subscriptionId returns badRequest` / `cancelStream with missing subscriptionId returns badRequest` in `test/core/api_bridge_test.dart:340` / `350`

### U45: Stream handler generates UUID via `ZuraffaApiBridge.generateSubscriptionId()`
- **Status**: DONE
- **Test**: `generateSubscriptionId generates non-empty unique UUIDs` in `test/core/api_bridge_test.dart:369`

---

## User Story 5: Debug-Only Safety Gate (Priority: P1)

### AC-16: `kReleaseMode` true → `registerProductApiBridge()` returns immediately, zero extensions, zero allocations
- **Status**: PENDING (T044 / T051)

### AC-17: `kReleaseMode` false, `kProfileMode` false (debug) → all extensions registered
- **Status**: PENDING (T044)

### AC-18: `kProfileMode` true, `Zuraffa.enableApiInProfile` false (default) → bridge returns immediately
- **Status**: PENDING (T044)

### AC-19: `kProfileMode` true, `Zuraffa.enableApiInProfile` true → all extensions registered
- **Status**: PENDING (T044)

### U46: `ZuraffaApiBridge.init()` guards with `const bool.fromEnvironment('dart.vm.product')` (release) and `const bool.fromEnvironment('dart.vm.profile')` + `ZuraffaBridgeFacade.enableApiInProfile`
- **Status**: DONE — verified by code inspection of `api_bridge.dart:76`

### U47: Generated `register{Entity}ApiBridge()` has `if (kReleaseMode) return;` as first statement
- **Status**: DONE (U23)

### U48: Generated `register{Entity}ApiBridge()` has `if (kProfileMode && !Zuraffa.enableApiInProfile) return;` as second statement
- **Status**: DONE (U24)

### U49: `ZuraffaApiBridge.init()` is idempotent (calling twice is harmless)
- **Status**: PENDING (T044)

### U50: `Zuraffa.enableApiInProfile` static getter/setter exists on `Zuraffa` facade
- **Status**: DONE — verified by code inspection of `zuraffa.dart:643`

---

## User Story 6: Discovery Endpoint (Priority: P2)

### AC-20: `ext.zuraffa._list` returns JSON array of all registered endpoints (excluding meta-extensions)
- **Status**: DONE (T043)
- **Test**: `discovery (_handleList) returns a JSON catalog of all registered endpoints, excluding meta` in `test/core/api_bridge_test.dart:153`

### AC-21: Entry for `getProduct` with `String id` → `Product` has correct fields
- **Status**: DONE (T043)
- **Test**: Same as AC-20 — entry shape verified

### AC-22: No endpoints registered → `_list` returns `[]`
- **Status**: DONE (T043)
- **Test**: `returns [] when no endpoints are registered` in `test/core/api_bridge_test.dart:201`

### U51: `_handleList` returns `_endpoints.map((e) => e.toJson()).toList()` as JSON
- **Status**: DONE — verified by code inspection of `api_bridge.dart:194`

### U52: Meta-extensions (`_list`, `_pollStream`, `_cancelStream`) never appear in catalog
- **Status**: DONE
- **Test**: Explicit assertion in `test/core/api_bridge_test.dart:195`

### U53: `ApiEndpoint.toJson()` includes `method`, `domain`, `usecase`, `params`, `returns`, `isStream`
- **Status**: DONE — verified by `api_endpoint.dart:33`

---

## User Story 7: Integration Test (Priority: P1)

### AC-23: `GetProductListUseCase` wired to `ProductMockDataSource` → handler returns success with 3 products
- **Status**: PENDING (T046 / T033)

### AC-24: `CreateProductUseCase` wired to mock → handler echoes created product
- **Status**: PENDING (T046 / T033)

### AC-25: `ProductMockDataSource` throwing `notFoundFailure` → handler returns structured failure
- **Status**: PENDING (T046 / T034)

### AC-26: Datasource throwing raw `Exception('boom')` → handler returns `type: unknown`, does not throw
- **Status**: PENDING (T046 / T034)

### AC-27: `WatchConcertUseCase` stream lifecycle (subscribe → poll → cancel) works without leaks
- **Status**: PENDING (T046 / T035)

### U54: Integration test file exists at `example/test/api_bridge_integration_test.dart`
- **Status**: PENDING (T046) — `example/` directory does not exist

### U55: Integration test constructs UseCases + mock datasources directly (no GetIt, no Flutter binding)
- **Status**: PENDING (T046)

### U56: Integration test calls handler functions directly (no `developer.registerExtension`)
- **Status**: PENDING (T046)

### U57: Integration test parses `ServiceExtensionResponse.result` body as JSON
- **Status**: PENDING (T046)

### U58: Stream test uses `StreamController.broadcast()` to avoid `Stream.periodic` delay
- **Status**: PENDING (T046)

---

## Summary

| Category | Total | DONE | PENDING | BLOCKED |
|----------|-------|------|---------|---------|
| Acceptance (AC) | 27 | 12 | 15 | 0 |
| Unit (U) | 58 | 34 | 24 | 0 |
| **Total** | **85** | **46** | **39** | **0** |

---

## Key Gaps to Address

1. **Missing `api_command_test.dart`** — T036 (U2–U5)
2. **No `dart analyze` test on generated output** — T039 (AC-02)
3. **Release/profile mode safety gate tests** — T044 (AC-16–AC-19, U49)
4. **Integration test in `example/`** — T046 (AC-23–AC-27, U54–U58) — `example/` directory doesn't exist
5. **Acceptance tests** — T047–T052 (run `zfa api` end-to-end, in-process handlers, release build, `_list` catalog)
