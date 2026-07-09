# Feature: Zuraffa VM Service API Plugin — Auto-Generated Runtime RPC Bridge

## Description

Add a `--with=vmapi` plugin to the Zuraffa framework that automatically registers every UseCase in the DI container as a Dart VM Service extension, making them callable via WebSocket JSON-RPC at runtime. This eliminates the need to manually write `developer.registerExtension` boilerplate for each use case — the framework introspects all registered UseCases and exposes them as `ext.zuraffa.<domain>.<usecase>` endpoints.

## Problem

Currently, testing a UseCase at runtime requires either:

1. Writing a full integration test with mocktail
2. Manually adding `developer.registerExtension` calls in `main.dart` for each use case you want to test
3. Navigating through the UI to trigger the flow that calls the use case

This is slow and repetitive. Developers need to validate business logic against live data (real backend, real scraping, real DI wiring) without building UI first, and without writing test scaffolding for each use case.

## Proposed Solution

A Zuraffa runtime plugin (`ZuraffaVmApiPlugin`) that:

1. **Auto-discovers** all UseCases registered in the GetIt service locator at startup
2. **Registers** each one as a VM Service extension using `developer.registerExtension`
3. **Serializes** incoming parameters (JSON → typed params objects)
4. **Executes** the UseCase via its `call()` method
5. **Returns** the result as JSON (including `Result<T, AppFailure>` union types)
6. **Handles streams** — UseCases returning `Stream<T>` send back a stream subscription ID, and the caller can poll or receive pushed results

### Naming Convention

```
ext.zuraffa.<domain>.<usecase_name>
```

Examples:

- `ext.zuraffa.barcode_listing.getBarcodeListing`
- `ext.zuraffa.listing.getGoogleShoppingListingList`
- `ext.zuraffa.customer.getCustomer`
- `ext.zuraffa.zik_zak.createZikZak`

### Invocation Protocol

Called via WebSocket JSON-RPC to the VM Service:

```json
{
  "jsonrpc": "2.0",
  "method": "ext.zuraffa.barcode_listing.getBarcodeListing",
  "params": {
    "isolateId": "<isolate_id>",
    "args": {
      "barcode": "8690000000253"
    }
  },
  "id": "1"
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "success",
    "data": { "...": "serialized BarcodeListing" }
  },
  "id": "1"
}
```

Error response:

```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "error",
    "failure": {
      "type": "notFound",
      "message": "No listing found for barcode 8690000000253"
    }
  },
  "id": "1"
}
```

## User Scenarios

### US1 — Auto-Register All UseCases (P1)

As a developer, when I enable the VmApi plugin, all UseCases registered in the DI container are automatically available as VM Service extensions without writing any manual registration code.

**Acceptance**: After `Zuraffa.enableVmApi()` is called (or `--with=vmapi` generates the init call), calling `getIsolate` on the VM Service shows extensions like `ext.zuraffa.barcode_listing.getBarcodeListing` for every registered use case.

### US2 — Call a UseCase with Parameters (P1)

As a developer, I can call any UseCase via WebSocket RPC, passing parameters as JSON, and receive the serialized result back.

**Acceptance**: Calling `ext.zuraffa.barcode_listing.getBarcodeListing` with `{"args": {"barcode": "8690000000253"}}` returns the serialized `BarcodeListing` JSON, exactly as if the UseCase was called from a Presenter.

### US3 — Handle Result<T, AppFailure> Types (P2)

As a developer, when a UseCase returns `Result<T, AppFailure>`, the extension returns success data on `Result.success` and structured failure info on `Result.failure`.

**Acceptance**: A UseCase that fails with `AppFailure.notFound(...)` returns `{"status": "error", "failure": {"type": "notFound", "message": "..."}}` instead of crashing the extension.

### US4 — Handle Stream-Based UseCases (P3)

As a developer, when a UseCase returns `Stream<T>`, the extension returns a subscription handle, and I can poll for the latest emitted value or receive all values.

**Acceptance**: Calling a stream UseCase returns `{"status": "streaming", "subscriptionId": "abc123"}`. A follow-up call to `ext.zuraffa._pollStream` with `{"subscriptionId": "abc123"}` returns the latest emitted value.

### US5 — Codegen Support via `--with=vmapi` (P2)

As a developer using `zfa make`, the `--with=vmapi` flag generates the DI registration and any necessary serialization helpers for the entity's UseCases.

**Acceptance**: Running `zfa make Product --with=vmapi` generates code that registers `GetProductUseCase`, `GetProductListUseCase`, `CreateProductUseCase`, etc. as VM Service extensions with proper parameter deserialization from the entity's Zorphy-generated `fromJson` methods.

### US6 — Debug-Only Safety Gate (P1)

As a framework maintainer, the VmApi plugin MUST NOT activate in release mode. It must throw or no-op when `kReleaseMode` is true.

**Acceptance**: In release builds, `Zuraffa.enableVmApi()` is a no-op and no extensions are registered.

### US7 — Discovery Endpoint (P2)

As a developer, I can call a meta-extension `ext.zuraffa._list` to get a JSON catalog of all registered UseCase extensions, their parameter schemas, and return types.

**Acceptance**: Calling `ext.zuraffa._list` returns a JSON array like:

```json
[
  {
    "method": "ext.zuraffa.barcode_listing.getBarcodeListing",
    "domain": "barcode_listing",
    "usecase": "getBarcodeListing",
    "params": { "barcode": "String" },
    "returns": "BarcodeListing",
    "isStream": false
  }
]
```

## Key Design Decisions

1. **Runtime introspection, not codegen-only**: The primary registration happens at runtime by scanning GetIt registrations. The `--with=vmapi` codegen flag adds serialization helpers (fromJson/toJson wiring) but the actual extension registration is runtime. This ensures dynamically registered UseCases are also covered.

2. **Parameter serialization via Zorphy**: Since all Zuraffa entities use `@Zorphy(generateJson: true)`, the generated `fromJson` and `toJson` methods handle parameter deserialization and result serialization automatically.

3. **UseCase param objects**: Zuraffa UseCases typically take either:
   - A primitive (String, int, etc.) → passed directly
   - A params object (e.g., `QueryParams<T>`, custom params class) → deserialized from JSON using the params class's `fromJson`
   - No params → called with empty args

4. **Stream handling**: For `Stream<Result<T, AppFailure>>` UseCases (common in Zuraffa for progressive data loading), the extension returns a subscription handle. The caller polls or the framework pushes via a separate extension.

5. **Security**: Hard-gated to `!kReleaseMode`. In profile mode, opt-in via a flag.

6. **No HTTP GET support**: VM Service extensions in modern Flutter (3.44+) only work reliably via WebSocket. The plugin documents this and provides a helper script.

## Scope Boundaries

- **In scope**: Auto-registration of UseCases, parameter serialization, result serialization, stream handling, discovery endpoint, codegen flag, debug safety gate
- **Out of scope**: UI interaction (tapping buttons, navigating), automated test execution, CI/CD integration, HTTP GET support
- **Framework**: This is a Zuraffa framework feature (`~/Developer/zuraffa/`), not a ZikZak app feature

## Inspiration

The manual implementation in ZikZak's `main.dart` proved the pattern works:

```dart
ServiceExtensionBridge.register('testVariations', (params) async {
  final listing = ListingMockData.sampleBarcodeListingWithVariations;
  showShadSheet(context: context, builder: ...);
  return {'status': 'ok'};
});
```

This feature automates and generalizes that pattern for every UseCase in any Zuraffa-based app.
