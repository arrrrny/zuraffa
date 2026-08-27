# Tasks: API Plugin — Auto-Generated Runtime RPC Bridge

**Input**: Design documents from `/specs/012-api-plugin/`

**Prerequisites**: plan.md (required), spec.md (required), data-model.md, contracts/runtime-api.md

**Tests**: Unit tests are included per user story following existing Zuraffa plugin test patterns.

**Organization**: Tasks are grouped by phase. Within each phase, `[P]` marks tasks that touch different files and can run in parallel. Tasks without `[P]` MUST be sequential.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared write scope)
- **[Story]**: Which user story this task belongs to
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Branch and dependency verification — no code written.

- [x] T001 Verify the active branch is `012-api-plugin`. Confirm `zuraffa/pubspec.yaml` has `uuid` or a UUID-generation equivalent available (add if missing — needed by `ZuraffaApiBridge` for stream `subscriptionId`).

---

## Phase 2: Core Runtime Types (Blocking Prerequisites)

**Purpose**: The runtime types that ALL generated bridge files depend on. Nothing else can be built until this phase is complete.

**⚠️ CRITICAL**: T003, T004, T005 write to the same file (`api_bridge.dart`) — they are sequential, not parallel.

- [x] T002 [P] [US1] Create `ApiEndpoint` immutable data class with fields `method`, `domain`, `usecase`, `params` (`Map<String, String>`), `returns`, `isStream`, and a `toJson()` method that returns `Map<String, dynamic>`. Mark the class `const`-constructable. Write to `zuraffa/lib/src/core/api_endpoint.dart`.

- [x] T003 [Foundation] Create `ZuraffaApiBridge` class skeleton in `zuraffa/lib/src/core/api_bridge.dart` with:
  - `static bool _initialized = false`
  - `static final List<ApiEndpoint> _endpoints = []`
  - `static final Map<String, _StreamRecord> _streamSubscriptions = {}`
  - Private inner class `_StreamRecord` with fields `StreamSubscription subscription` and `dynamic latestValue`
  - Empty stubs for `init()`, `registerEndpoint()`, `serializeResult()`, `errorResponse()`, `_handleList()`, `_handlePollStream()`, `_handleCancelStream()`

- [x] T004 [Foundation — after T003] Implement `ZuraffaApiBridge.registerEndpoint({required ApiEndpoint endpoint, required Future<ServiceExtensionResponse> Function(String, Map<String, String>) handler})` in `zuraffa/lib/src/core/api_bridge.dart`:
  - Appends `endpoint` to `_endpoints`
  - Calls `developer.registerExtension(endpoint.method, handler)`

- [x] T005 [Foundation — after T004] Implement `ZuraffaApiBridge.init()` in `zuraffa/lib/src/core/api_bridge.dart`:
  - Guard: `if (kReleaseMode || _initialized) return;`
  - Guard: `if (kProfileMode && !Zuraffa.enableApiInProfile) return;`
  - Set `_initialized = true`
  - Register `ext.zuraffa._list` via `developer.registerExtension` → `_handleList`
  - Register `ext.zuraffa._pollStream` via `developer.registerExtension` → `_handlePollStream`
  - Register `ext.zuraffa._cancelStream` via `developer.registerExtension` → `_handleCancelStream`

- [x] T006 [Foundation — after T004] Implement `ZuraffaApiBridge.serializeResult<T>(Result<T, AppFailure> result, Map<String, dynamic> Function(T) toJson)` in `zuraffa/lib/src/core/api_bridge.dart`. Use `result.fold()` (the correct API — NOT `.when()`):

  ```dart
  return result.fold(
    (value) => ServiceExtensionResponse.result(
      jsonEncode({'status': 'success', 'data': toJson(value)}),
    ),
    (failure) => ServiceExtensionResponse.result(
      jsonEncode({'status': 'error', 'failure': failure.toJson()}),
    ),
  );
  ```

- [x] T007 [Foundation — after T004] Implement `ZuraffaApiBridge.errorResponse(String type, String message)` static helper that returns `ServiceExtensionResponse.result(jsonEncode({'status': 'error', 'failure': {'type': type, 'message': message}}))`. This is the bridge's single authoritative error serializer for catch blocks in generated handlers.

- [x] T008 [P] [Foundation] Add `static bool enableApiInProfile = false` to the `Zuraffa` facade class in `zuraffa/lib/zuraffa.dart`.

- [x] T009 [P — after T002, T003] Export `ZuraffaApiBridge` and `ApiEndpoint` from `zuraffa/lib/zuraffa.dart`.

**Checkpoint**: `ZuraffaApiBridge` compiles. It has `init()`, `registerEndpoint()`, `serializeResult()`, `errorResponse()`, and the three meta-extension handlers. `Zuraffa.enableApiInProfile` exists. Run `dart analyze zuraffa/lib/src/core/api_bridge.dart` — zero errors.

---

## Phase 3: User Story 1 — CLI Plugin & Bridge Codegen (Priority: P1) 🎯 MVP

**Goal**: `zfa api Product` generates a valid, compilable bridge file.

**All four implementation tasks (T010–T013) write to different files — they can run in parallel.**

**Independent Test**: Run `zfa api Product` on a project with Product UseCases. Verify `lib/src/api/bridges/product_api_bridge.dart` exists and `dart analyze lib/src/api/bridges/` reports zero errors.

- [x] T010 [P] [US1] Create `ApiPlugin` in `zuraffa/lib/src/plugins/api/api_plugin.dart`:
  - Extends `FileGeneratorPlugin`, implements `CliAwarePlugin`
  - Constructor: `ApiPlugin({required String outputDir, GeneratorOptions options = const GeneratorOptions(), FileSystem? fileSystem})`
  - `id = 'api'`, `name = 'API Plugin'`, `version = '1.0.0'`
  - `capabilities` returns `[CreateApiBridgeCapability(this)]`
  - `createCommand()` returns `ApiCommand(this)`
  - `generate(GeneratorConfig config)` delegates to `ApiBridgeBuilder`

- [x] T011 [P] [US1] Create `ApiCommand` in `zuraffa/lib/src/commands/api_command.dart`:
  - Extends `PluginCommand` from `commands/base_plugin_command.dart` (NOT `commands/plugin_command.dart`)
  - `name = 'api'`, `description = 'Generate API bridge for a Zuraffa entity'`
  - `argParser.addOption('domain', help: 'Override domain name for the entity')`
  - `run()` reads `argResults!.rest.first` as the entity name, dispatches to `CreateApiBridgeCapability.execute()`, calls `logSummary(files)`

- [x] T012 [P] [US1] Create `CreateApiBridgeCapability` in `zuraffa/lib/src/plugins/api/capabilities/create_api_bridge_capability.dart`:
  - Implements `ZuraffaCapability`
  - `name = 'create-api-bridge'`, `description = 'Generate VM Service extension bridge for a Zuraffa entity'`
  - `inputSchema` requires `name: String`; optional `domain: String`, `dryRun: bool`, `force: bool`, `verbose: bool`
  - `plan()` calls `_generateFiles(args, dryRun: true)` and returns `EffectReport`
  - `execute()` calls `_generateFiles(args, dryRun: args['dryRun'] ?? false)` and returns `ExecutionResult` with `data: {'generatedFiles': files}`

- [x] T013 [P] [US1] Create `ApiBridgeBuilder` in `zuraffa/lib/src/plugins/api/builders/api_bridge_builder.dart`:
  - Constructor: `ApiBridgeBuilder({required String outputDir, GeneratorOptions options = const GeneratorOptions(), FileSystem? fileSystem})`
  - `generate(GeneratorConfig config)` method:
    1. Uses `EntityAnalyzer` (same utility as `MockBuilder`) to discover UseCases for the entity
    2. If zero UseCases found: prints error message, returns `[]`
    3. Generates the bridge Dart file content (see plan.md Generated File Contract)
    4. Writes to `lib/src/api/bridges/{entity_snake}_api_bridge.dart` via `FileUtils.writeFile()`
    5. Returns `[GeneratedFile(path: ..., action: 'created'|'skipped')]`

- [x] T014 [US1 — after T010–T013] Register `ApiPlugin` in `PluginLoader._plugins()` in `zuraffa/lib/src/cli/plugin_loader.dart`:
  - Add `import '../plugins/api/api_plugin.dart';`
  - Add `ApiPlugin(outputDir: outputDir, options: options),` to the list (after `MockPlugin`)

- [x] T015 [US1 — after T013] Write unit tests for `ApiBridgeBuilder.generate()` in `zuraffa/test/plugins/api/api_bridge_builder_test.dart`:
  - Generates file at correct path: `lib/src/api/bridges/product_api_bridge.dart` [U10]
  - Generated content contains `registerProductApiBridge()` [U28]
  - Generated content contains `_handle{UseCase}` function for each UseCase [U25]
  - Generated content calls `ZuraffaApiBridge.registerEndpoint(...)` with correct `ApiEndpoint` [U25]
  - Returns empty list with no file written when entity has zero UseCases [AC-04, U11]
  - Respects `dryRun: true` (no file written but returns preview) [U9]

- [x] T016 [US1 — after T011, T012] Write unit tests for `ApiCommand` and `CreateApiBridgeCapability` in `zuraffa/test/plugins/api/api_plugin_test.dart`:
  - `zfa api Product` routes to `CreateApiBridgeCapability` [U4]
  - Missing entity name prints usage error [U3]
  - `--dry-run` flag passes through to capability [U9]
  - `--force` flag passes through to builder

**Checkpoint**: `zfa api Product` runs end-to-end, generates `lib/src/api/bridges/product_api_bridge.dart`, file compiles. Tests pass.

---

## Phase 4: User Stories 2, 3, 5 — Runtime Bridge Execution (Priority: P1/P2)

**Goal**: The generated bridge code actually calls UseCases and returns correct serialized responses.

**Independent Test**: Register a bridge in a test app. Connect to VM Service. Call `ext.zuraffa.product.getProduct({"id": "1"})`. Verify `{"status": "success", "data": {...}}`. Call with invalid ID, verify `{"status": "error", ...}`. Build in release mode, verify no extensions registered.

- [x] T017 [P] [US2] Update `ApiBridgeBuilder` to generate correct primitive-param handlers in `zuraffa/lib/src/plugins/api/builders/api_bridge_builder.dart`:
  - For `String`, `int`, `double`, `bool` param types: generate `final x = args['x'] ?? '';` (with appropriate type coercion) [U29]
  - The handler body calls `ZuraffaApiBridge.serializeResult(result, (p) => p.toJson())` [U33]
  - On exception: calls `ZuraffaApiBridge.errorResponse('unknown', e.toString())` and logs via `developer.log` [U32]

- [x] T018 [P] [US2] Update `ApiBridgeBuilder` to generate correct complex-param handlers in `zuraffa/lib/src/plugins/api/builders/api_bridge_builder.dart`:
  - For complex params types: generate `final params = {ParamsType}.fromJson(jsonDecode(args['args'] ?? '{}'));` [U30]
  - Wrap deserialization in its own try-catch that returns `ZuraffaApiBridge.errorResponse('deserialization', e.toString())` [U21, U42]

- [x] T019 [P] [US2] Update `ApiBridgeBuilder` to generate `NoParams` handlers in `zuraffa/lib/src/plugins/api/builders/api_bridge_builder.dart`:
  - For `NoParams` param type: generate `final useCase = GetIt.I<{UseCase}>(); final result = await useCase(NoParams());` [U31, U20]

- [x] T020 [US5 — after T017–T019] Verify the generated `registerProductApiBridge()` function in `ApiBridgeBuilder` has the correct two-line guard at the top:
  - `if (kReleaseMode) return;` [U47, AC-16]
  - `if (kProfileMode && !Zuraffa.enableApiInProfile) return;` [U48, AC-18]

- [x] T021 [US2, US3, US5 — after T017–T020] Write runtime bridge unit tests in `zuraffa/test/core/api_bridge_test.dart`:
  - `serializeResult` with `Result.success(x)` → correct JSON with `status: success` [AC-09, U35]
  - `serializeResult` with `Result.failure(failure)` → correct JSON with `status: error` [AC-10, U35]
  - `errorResponse('unknown', 'msg')` → correct error JSON [U36]
  - `registerEndpoint` adds to `_endpoints` list [U25]
  - In-process simulation: register a mock handler, call it, verify response [U33]
  - Safety gate: confirm `init()` with mocked `kReleaseMode = true` registers zero extensions [U49, AC-16]

**Checkpoint**: Full runtime bridge works. `Result` serialization is via `fold()`. `serializeResult` and `errorResponse` are the sole serialization entry points. Safety gates verified.

---

## Phase 5: User Story 6 — Discovery Endpoint (Priority: P2)

**Goal**: `ext.zuraffa._list` returns a complete JSON catalog of registered endpoints.

**Independent Test**: Register bridges for 2 entities, call `ext.zuraffa._list`. Verify the response is a JSON array with all endpoint entries, correct fields.

- [x] T022 [US6 — after Phase 2] Implement `ZuraffaApiBridge._handleList()` in `zuraffa/lib/src/core/api_bridge.dart`:
  - Returns `ServiceExtensionResponse.result(jsonEncode(_endpoints.map((e) => e.toJson()).toList()))` [U51]

- [x] T023 [US6 — after T022] Write unit tests for discovery in `zuraffa/test/core/api_bridge_test.dart`:
  - After registering 3 endpoints, `_handleList` returns JSON array with exactly 3 entries [AC-20, U52]
  - When no endpoints registered, returns `[]` [AC-22]
  - Each entry has all required fields: `method`, `domain`, `usecase`, `params`, `returns`, `isStream` [U53, AC-21]

**Checkpoint**: Discovery endpoint returns accurate catalog.

---

## Phase 6: User Story 4 — StreamUseCase Support (Priority: P3)

**Goal**: Stream UseCases can be started, polled, and cancelled via the bridge.

**Independent Test**: Call a `StreamUseCase` bridge extension, verify `{"status": "streaming", "subscriptionId": "..."}`. Call `_pollStream` with that ID, verify latest value returned. Call `_cancelStream`, verify subscription removed.

- [x] T024 [P] [US4] Implement `ZuraffaApiBridge._handlePollStream(String method, Map<String, String> args)` in `zuraffa/lib/src/core/api_bridge.dart`:
  - Reads `subscriptionId` from `args` [U38]
  - If not found in `_streamSubscriptions`: returns `errorResponse('notFound', 'No active subscription: $subscriptionId')` [U42, U44]
  - If found but no value emitted yet: returns `ServiceExtensionResponse.result(jsonEncode({'status': 'pending'}))` [U40, AC-15]
  - If found with a value: returns `ServiceExtensionResponse.result(jsonEncode({'status': 'success', 'data': latestValue}))` [U41, AC-13]

- [x] T025 [P] [US4] Implement `ZuraffaApiBridge._handleCancelStream(String method, Map<String, String> args)` in `zuraffa/lib/src/core/api_bridge.dart`:
  - Reads `subscriptionId` from `args` [U38]
  - Calls `_streamSubscriptions[subscriptionId]?.subscription.cancel()` [U42]
  - Removes from `_streamSubscriptions` [U42]
  - Returns `ServiceExtensionResponse.result(jsonEncode({'status': 'cancelled'}))` [AC-14, U42]

- [x] T026 [P] [US4] Update `ApiBridgeBuilder` to detect `StreamUseCase` return types in `zuraffa/lib/src/plugins/api/builders/api_bridge_builder.dart`:
  - When UseCase extends `StreamUseCase<T, P>`, generate a handler that:
    1. Calls `GetIt.I<{StreamUseCase}>().call(params)` [U38]
    2. Generates a UUID via `const Uuid().v4()` [U45]
    3. Subscribes with `.listen()`, caching each emitted value in `ZuraffaApiBridge`'s `_streamSubscriptions` map via a new `registerStreamSubscription(id, subscription, onValue)` method [U38, U39]
    4. Returns immediately with `{'status': 'streaming', 'subscriptionId': uuid}` [AC-12]
  - Add `ZuraffaApiBridge.registerStreamSubscription(String id, StreamSubscription sub, void Function(dynamic) onValue)` to the runtime class [U38]

- [x] T027 [US4 — after T024–T026] Write stream handling unit tests in `zuraffa/test/core/api_bridge_test.dart`:
  - Subscription is created and stored when stream handler is invoked [AC-12, U38]
  - `_pollStream` returns `{'status': 'pending'}` before first emission [AC-15, U40]
  - `_pollStream` returns latest value after emission [AC-13, U41]
  - `_cancelStream` cancels subscription and removes it from the map [AC-14, U42]
  - Two concurrent streams with different IDs are independent [U43]

**Checkpoint**: Stream UseCases fully supported via subscribe/poll/cancel lifecycle.

---

## Phase 7: Polish & Validation

**Purpose**: Analysis, tests, and end-to-end validation.

- [x] T028 [P] Run `zfa build` to regenerate framework-internal generated code.
- [x] T029 [P] Run `dart analyze zuraffa/lib/src/plugins/api/ zuraffa/lib/src/core/api_bridge.dart zuraffa/lib/src/core/api_endpoint.dart` — fix any issues.
- [x] T030 Run `flutter test test/plugins/api/ test/core/api_bridge_test.dart` — verify all pass.
- [x] T031 Run validation scenarios from `specs/012-api-plugin/quickstart.md`.

---

## Phase 8: User Story 7 — Integration / Acceptance Test (Priority: P1)

**Goal**: A `flutter_test` file in `example/test/` that calls real example-app UseCases through bridge handler functions in-process, parsing the serialized JSON responses and asserting correctness. This is the acceptance gate — it proves the full stack (real UseCase → real mock datasource → `Result.fold()` → `serializeResult`) works before any developer touches a VM Service client.

**No mocks at the UseCase or repository layer.** Mock datasources are real objects, constructed directly with `delay: Duration.zero` so tests run fast.

**No `developer.registerExtension` calls.** Handler functions are constructed inline in the test, mirroring exactly what codegen would produce, and called directly.

**Independent Test**: `flutter test example/test/api_bridge_integration_test.dart` — all groups pass.

- [x] T032 [US7] Set up the integration test file at `example/test/api_bridge_integration_test.dart`:
  - Import `dart:convert`, `dart:async`, `package:flutter_test/flutter_test.dart`, `package:zuraffa/zuraffa.dart`
  - Import the example app's entity, usecase, datasource, and repository types for `Product` and `Concert`
  - In a `setUpAll`, construct `ProductMockDataSource(delay: Duration.zero)`, `DataProductRepository`, `GetProductListUseCase`, and `CreateProductUseCase` directly — no GetIt, no Flutter binding
  - Define inline handler functions (`handleGetProductList`, `handleCreateProduct`, `handleGetProductListFailure`) that mirror the generated bridge pattern exactly:
    1. Call `useCase(params)`
    2. Return `ZuraffaApiBridge.serializeResult(result, (v) => ...toJson...)`
    3. Catch all exceptions and return `ZuraffaApiBridge.errorResponse('unknown', e.toString())`
  - Confirm `ZuraffaApiBridge` is imported and usable without a running app (it is — `serializeResult` and `errorResponse` are pure Dart, no platform dependency)

- [x] T033 [US7 — after T032] Write the **success path** group in `example/test/api_bridge_integration_test.dart`:

  ```dart
  group('success path — GetProductListUseCase', () {
    test('returns status:success with 3 products from mock datasource', () async {
      final response = await handleGetProductList(
        'ext.zuraffa.product.getProductList', {});
      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'success');
      final items = (body['data'] as List);
      expect(items.length, 3);
      expect(items.first['id'], 'id 1');
      expect(items.first['name'], 'name 1');
    });

    test('CreateProductUseCase — echoes the created product', () async {
      final product = Product(
        id: 'test-1', name: 'Integration Test Product',
        description: 'desc', price: 9.99,
        createdAt: DateTime(2026, 1, 1),
      );
      final response = await handleCreateProduct(
        'ext.zuraffa.product.createProduct',
        {'args': jsonEncode(product.toJson())},
      );
      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'success');
      expect(body['data']['id'], 'test-1');
      expect(body['data']['name'], 'Integration Test Product');
    });
  });
  ```

  Assert: `body['status'] == 'success'`, item count matches `ProductMockData.products.length`, `id` and `name` fields are correct.

- [x] T034 [US7 — after T032] Write the **failure path** group in `example/test/api_bridge_integration_test.dart`:
  - Construct a handler that uses a datasource variant that throws (e.g., calling `update` with a non-existent ID via `ProductMockDataSource` which calls `notFoundFailure`, or a thin wrapper that `throw Exception('boom')`):

  ```dart
  group('failure path', () {
    test('notFoundFailure — returns status:error with failure block', () async {
      // Handler wired to a datasource that throws notFoundFailure for any lookup
      final response = await handleGetProductThatFails(
        'ext.zuraffa.product.getProduct', {'id': 'nonexistent'});
      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'error');
      expect(body['failure'], isA<Map>());
      expect(body['failure']['message'], isNotEmpty);
    });

    test('unexpected exception — returns status:error, type:unknown, does not throw', () async {
      // Handler backed by a datasource that throws a raw Exception
      final response = await handleGetProductUnexpectedException(
        'ext.zuraffa.product.getProduct', {});
      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'error');
      expect(body['failure']['type'], 'unknown');
      expect(body['failure']['message'], contains('boom'));
    });
  });
  ```

  Key invariant: neither test throws — all exceptions are absorbed by the handler's outer try-catch and surfaced as structured JSON. This is SC-005 verified in code.

- [x] T035 [US7 — after T032] Write the **stream lifecycle** group in `example/test/api_bridge_integration_test.dart`:
  - Use a `StreamController<Concert>.broadcast()` to avoid the 2-second `Stream.periodic` delay in `ConcertMockDataSource.watch()`
  - Wire a lightweight `WatchConcertUseCase` variant backed by this controller
  - Call the stream handler inline — parse the initial response, assert `status == 'streaming'` and `subscriptionId` is a non-empty string
  - Push one `Concert` event to the controller
  - Call `ZuraffaApiBridge._handlePollStream` with the `subscriptionId` — assert `status == 'success'` and `data` contains the concert's `id`
  - Call `ZuraffaApiBridge._handleCancelStream` with the `subscriptionId` — assert `status == 'cancelled'`
  - Assert `ZuraffaApiBridge` internal `_streamSubscriptions` no longer contains the `subscriptionId` (verify via the `_handlePollStream` returning `notFound` for that ID after cancel)

  ```dart
  group('stream lifecycle — WatchConcertUseCase', () {
    test('subscribe → poll → cancel lifecycle completes without leaks', () async {
      final controller = StreamController<Concert>.broadcast();
      // ... inline use case wired to controller.stream

      // 1. Start
      final startResponse = await handleWatchConcert(
        'ext.zuraffa.concert.watchConcert',
        {'args': jsonEncode(QueryParams<Concert>().toJson())},
      );
      final startBody = jsonDecode(startResponse.result!) as Map<String, dynamic>;
      expect(startBody['status'], 'streaming');
      final subId = startBody['subscriptionId'] as String;
      expect(subId, isNotEmpty);

      // 2. Emit a value
      controller.add(ConcertMockData.sampleConcert);
      await Future.microtask(() {});  // allow listener to process

      // 3. Poll
      final pollResponse = await ZuraffaApiBridge.handlePollStream(
        'ext.zuraffa._pollStream', {'subscriptionId': subId});
      final pollBody = jsonDecode(pollResponse.result!) as Map<String, dynamic>;
      expect(pollBody['status'], 'success');
      expect(pollBody['data']['id'], 'id 1');

      // 4. Cancel
      final cancelResponse = await ZuraffaApiBridge.handleCancelStream(
        'ext.zuraffa._cancelStream', {'subscriptionId': subId});
      final cancelBody = jsonDecode(cancelResponse.result!) as Map<String, dynamic>;
      expect(cancelBody['status'], 'cancelled');

      // 5. Verify no leak: subsequent poll returns notFound
      final postCancelPoll = await ZuraffaApiBridge.handlePollStream(
        'ext.zuraffa._pollStream', {'subscriptionId': subId});
      final postBody = jsonDecode(postCancelPoll.result!) as Map<String, dynamic>;
      expect(postBody['status'], 'error');

      await controller.close();
    });
  });
  ```

  The test closes the `StreamController` at the end. Zero subscriptions remain — no resource leaks.

**Checkpoint**: `flutter test example/test/api_bridge_integration_test.dart` runs green. All five scenarios (success list, success create, notFound failure, unknown exception, stream lifecycle) pass. No `UseCase` or `Repository` is mocked — only datasources are test-controlled. This proves SC-002 and SC-005 mechanically.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies.
- **Phase 2 (Foundational)**: Depends on Phase 1. BLOCKS all other phases.
- **Phase 3 (US1 codegen)**: Depends on Phase 2.
- **Phase 4 (US2+US3+US5 runtime)**: Depends on Phase 2 + Phase 3.
- **Phase 5 (US6 discovery)**: Depends on Phase 2 only (T022 is a method on `ZuraffaApiBridge`).
- **Phase 6 (US4 streams)**: Depends on Phase 2 + Phase 3. Can start after Phase 3.
- **Phase 7 (Polish)**: Depends on all phases complete.
- **Phase 8 (US7 integration test)**: Depends on Phase 2 (needs `ZuraffaApiBridge.serializeResult` and `errorResponse`) and Phase 6 (needs stream lifecycle handlers). Can start after Phase 6 completes. T032→T033, T032→T034, T032→T035 (T032 is the setup task; T033–T035 can run in parallel after T032).

### Within Phase 2 (sequential — same file)

T003 → T004 → T005 → T006 → T007. T002, T008, T009 are parallel to each other and to T003–T007 (different files).

### Within Phase 3 (parallel where marked)

T010, T011, T012, T013 are parallel (different files). T014 after T013. T015 after T013. T016 after T011 and T012.

### Within Phase 4 (parallel where marked)

T017, T018, T019 are parallel (same file but different generation branches — coordinate carefully or make sequential). T020 after T017–T019. T021 after T020.

### Within Phase 6 (parallel where marked)

T024, T025, T026 are parallel (T024/T025 are in `api_bridge.dart`, T026 is in `api_bridge_builder.dart`). Note: T024 and T025 write to the same file — make them sequential.

---

## Parallel Execution Summary

```
Phase 2:  T002 ────────────────────────────────────── (parallel, api_endpoint.dart)
          T008 ────────────────────────────────────── (parallel, zuraffa.dart)
          T009 ────────────────────────────────────── (parallel, zuraffa.dart — after T002, T003)
          T003 → T004 → T005 → T006 → T007 ─────────── (sequential, api_bridge.dart)

Phase 3:  T010 ─── (api_plugin.dart)
          T011 ─── (api_command.dart)    } All parallel
          T012 ─── (create_api_bridge_capability.dart)
          T013 ─── (api_bridge_builder.dart)
          T014 ─── after T013 (plugin_loader.dart)

Phase 5:  T022 ─── (api_bridge.dart — after Phase 2)
          T023 ─── after T022 (tests)

Phase 6:  T024 → T025 ─── (api_bridge.dart, sequential)
          T026 ─────────── (api_bridge_builder.dart, parallel to T024/T025)
          T027 ─── after T024–T026 (tests)

Phase 8:  T032 ─── (test file setup — after Phase 6)
          T033 ─── (success path tests)     } All parallel after T032
          T034 ─── (failure path tests)     }
          T035 ─── (stream lifecycle tests)  }
```

---

## Implementation Notes

- **`[P]` means different write scopes** — do not mark parallel if two tasks modify the same file.
- All changes are in `zuraffa/` (framework) — no app-level changes needed for the plugin implementation itself.
- The generated bridge code always goes into the **target app** project, not the framework.
- `ApiPlugin` follows `MockPlugin` structure — use `MockPlugin`, `MockCommand`, and `CreateMockCapability` as canonical references.
- **Never use `.when()` on `Result`** — the method does not exist. Always use `.fold(onSuccess, onFailure)`.
- **Never use `(data as dynamic).toJson()`** — pass `toJson` as a function parameter to `serializeResult`.
- `developer.log()` not `print()` for bridge diagnostics.
- **Phase 8 test file is in `example/test/`** — not in `zuraffa/test/`. The example app owns the concrete entity types. The framework test suite tests the runtime in isolation.
- **Phase 8 does not call `developer.registerExtension`** — that is the VM Service layer. The integration test calls handler functions directly, passing `Map<String, String>` args and parsing `ServiceExtensionResponse.result`.
- **Phase 8 uses `delay: Duration.zero`** for mock datasources — avoids 100ms delays in every test assertion. The delay is a constructor parameter on all generated mock datasources.
- **Phase 8 stream test uses `Stream.value()`** — avoids the 2-second `Stream.periodic` in `ConcertMockDataSource.watch()`. The test datasource returns `Stream.value(sampleConcert)` which emits after the subscription is established, avoiding timing races with `StreamController.broadcast()`. Two `await Future.microtask(() {})` waits allow the async* generator to propagate the value before polling.
- **`ZuraffaApiBridge._handlePollStream` and `_handleCancelStream` are private** — T035 must either make them package-visible (e.g., `@visibleForTesting`) or test them through a thin public accessor. Decide at implementation time; document the decision in the PR.

---

## Phase 9: TDD Coverage Gaps (added by /speckit.tdd.plan @ 614e648)

**Purpose**: The feature was implemented and its original test tasks (T015–T016, T021, T023, T027, T032–T035) are marked `[x]`, but the test list at `tdd/test-list.md` shows real gaps: `ApiCommand` has **no** test file, discovery `_handleList` catalog shape is untested, and several codegen branches (multi-UseCase, `--domain`, deserialization error, `NoParams`, `dart analyze` of generated file) and the runtime release-gate + `PluginLoader` registration are untested. The `example/` integration test (T032–T035) is marked done but `example/` does not exist. These tasks close those gaps. Each carries the behavior id(s) from `tdd/test-list.md` so `/speckit.tdd.run` can tick it.

**Note**: the suite baseline is RED (pre-existing MCP SSE timeout, unrelated). Clear it before starting the loop.

- [ ] T036 [US1] Create `zuraffa/test/plugins/api/api_command_test.dart`: no-args prints usage and returns; `zfa api Product` dispatches entity name + flags to `CreateApiBridgeCapability`; `--domain`/`-d` passes the override through. [U28,U29,U30]
- [x] T037 [US1] Add builder test: `--domain billing` produces `ext.zuraffa.billing.<usecase>` method names and `domain: 'billing'` in the `ApiEndpoint`. [U12]
- [x] T038 [US1] Add builder test: entity with 2+ UseCases generates one file with N handlers and N `registerEndpoint` calls (covers `SC-001` "one file per entity"). [U14]
- [ ] T039 [US1, SC-006] Add builder test that writes the generated file into a temp project that depends on `package:zuraffa` and assert it passes `dart analyze` with zero errors. [U15]
- [x] T040 [US2] Add builder test: a non-stream primitive-param UseCase (`UseCase<Product,String>`) generates a handler that reads `args['id']` directly (not a JSON blob). [U4]
- [x] T041 [US2] Add builder test: a `NoParams` UseCase generates `useCase(NoParams())` with `params: {}`. [U6]
- [x] T042 [US2, FR-012] Add builder test: the generated complex-params handler returns a body with `{'type':'deserialization'}` when `args['args']` is not valid JSON. [U13]
- [x] T043 [US6] Add runtime test for `ZuraffaApiBridge._handleList`: exact entry count, each entry matches `ApiEndpoint.toJson()` shape, meta-extensions (`_list`/`_pollStream`/`_cancelStream`) excluded, empty registry → `[]`. [U20,U33]
- [ ] T044 [US5, SC-003] Add runtime test for `ZuraffaApiBridge.init()`: no-op when `dart.vm.product` is true (release), opt-in when `dart.vm.profile` true and `Zuraffa.enableApiInProfile` true, idempotent, and registers exactly the three meta-extensions. [U23]
- [x] T045 [US1, FR-013] Add test asserting `ApiPlugin` is present in `PluginLoader._plugins()`. [U26]
- [ ] T046 [US7] Create the `example/` app and `example/test/api_bridge_integration_test.dart` (success, create, failure, unknown-exception, stream lifecycle) — the acceptance gate. Currently claimed done (T032–T035) but `example/` is absent. [A7]
- [ ] T047 [US1] Acceptance: run `zfa api Product` end-to-end on a temp project and assert the generated file + `dart analyze` clean. [A1]
- [ ] T048 [US2] Acceptance: in-process handler invocation for primitive, complex (`fromJson`), and `NoParams` params returns correct serialized success/failure. [A2]
- [ ] T049 [US3] Acceptance: a handler whose UseCase throws an unexpected exception returns `{'status':'error','failure':{'type':'unknown',...}}` and does not re-throw. [A3]
- [ ] T050 [US4] Acceptance: stream subscribe → poll → cancel through the bridge leaves zero active subscriptions. [A4]
- [ ] T051 [US5] Acceptance: a release-mode build registers zero extensions and allocates no bridge state. [A5]
- [ ] T052 [US6] Acceptance: `ext.zuraffa._list` returns an accurate catalog of all registered endpoints. [A6]
