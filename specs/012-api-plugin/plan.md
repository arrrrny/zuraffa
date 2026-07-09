# Implementation Plan: API Plugin — Auto-Generated Runtime RPC Bridge

**Branch**: `012-api-plugin` | **Date**: 2026-07-09 | **Spec**: [specs/012-api-plugin/spec.md](spec.md)

**Input**: Feature specification from `/specs/012-api-plugin/spec.md`

## Summary

Add a user-callable `api` plugin to the Zuraffa framework that generates a single bridge file per target entity, making each UseCase callable via Dart VM Service extensions (`ext.zuraffa.<domain>.<usecase>`). The plugin mirrors the `MockPlugin` structure: `FileGeneratorPlugin` + `CliAwarePlugin`, registered in `PluginLoader`, with its own `ApiCommand` and `CreateApiBridgeCapability`. A runtime `ZuraffaApiBridge` class owns the endpoint registry and `serializeResult` — generated bridge files call INTO this class via `ZuraffaApiBridge.registerEndpoint()`. Hard-gated to `!kReleaseMode`.

**Architectural clarity on the split**:

- `ZuraffaApiBridge.init()` registers only the three meta-extensions (`_list`, `_pollStream`, `_cancelStream`). It does **not** scan GetIt.
- Generated `register{Entity}ApiBridge()` functions call `ZuraffaApiBridge.registerEndpoint()` once per UseCase. This is how UseCases enter the registry.
- `serializeResult<T>` is implemented once in `ZuraffaApiBridge` and called by generated handlers. No duplication.

## Technical Context

**Language/Version**: Dart ^3.11.0, Flutter >=3.41.0

**Primary Dependencies**:

- `dart:developer` — `registerExtension`, `ServiceExtensionResponse`, `log`
- `dart:convert` — `jsonEncode`, `jsonDecode`
- `package:uuid` (existing or add) — generate `subscriptionId` for stream subscriptions
- Existing Zuraffa internals: `UseCase`, `StreamUseCase`, `Result`, `AppFailure`, `NoParams`, `ZuraffaPlugin`, `FileGeneratorPlugin`, `CliAwarePlugin`, `PluginContext`, `PluginLoader`, `StringUtils`, `FileUtils`, `GeneratorOptions`, `GeneratorConfig`

**Result API**: `Result<S, F>` is a sealed class with `fold(onSuccess, onFailure)` and `isSuccess`/`isFailure`. There is no `.when()` method. All `Result` handling uses `fold`.

**Storage**: File system — one generated Dart bridge file per entity, written to `lib/src/api/bridges/{entity_snake}_api_bridge.dart` in the target app's source tree.

**Testing**: `flutter_test` with `mocktail`. Tests in `test/plugins/api/` for the codegen layer, and `test/core/api_bridge_test.dart` for the runtime layer.

**Target Platform**: All platforms supported by Zuraffa. Uses `dart:developer` — no platform channels.

**Project Type**: Flutter library package (`zuraffa`) — both CLI plugin (codegen) and runtime library.

**Performance Goals**:

- `zfa api Product` completes under 5 seconds for an entity with 5–10 UseCases.
- Bridge registration at startup: under 100ms.
- Runtime extension dispatch: under 10ms per call for typical payloads.

**Constraints**:

- Zero breaking changes to existing `UseCase.call()`, `StreamUseCase.call()`, GetIt registrations, or DI plugin output.
- Zero overhead in release mode — the `kReleaseMode` early return is the only required guard.
- Generated code passes `dart analyze` with zero errors.

**Scale/Scope**:

- NEW: `lib/src/plugins/api/` — `api_plugin.dart`, `builders/api_bridge_builder.dart`, `capabilities/create_api_bridge_capability.dart`
- NEW: `lib/src/commands/api_command.dart` — CLI command
- NEW: `lib/src/core/api_endpoint.dart` — `ApiEndpoint` model
- NEW: `lib/src/core/api_bridge.dart` — `ZuraffaApiBridge` runtime class
- MODIFIED: `lib/src/cli/plugin_loader.dart` — register `ApiPlugin`
- MODIFIED: `lib/zuraffa.dart` — add `enableApiInProfile` flag and export new types
- NEW: `test/plugins/api/` — plugin and builder tests
- NEW: `test/core/api_bridge_test.dart` — runtime bridge tests
- NEW: `example/test/api_bridge_integration_test.dart` — US7 acceptance test (real UseCases + mock datasources, in-process)

## Constitution Check

1. **Library-First**: **PASS**. Self-contained codegen + runtime feature. Clear single purpose.
2. **Clean Architecture separation**: **PASS**. Bridge calls `UseCase.call()` only. It does not touch repositories, datasources, or presentation.
3. **Fail-Fast Contract**: **PASS**. Every extension handler is wrapped in try-catch. Errors produce structured responses — never app crashes.
4. **Debug-Only Safety**: **PASS**. `kReleaseMode` gate is the first statement in the generated `register{Entity}ApiBridge()` function. The `ZuraffaApiBridge.init()` also gates.
5. **Single Source of Truth**: **PASS**. `serializeResult<T>` lives in `ZuraffaApiBridge` only. Generated handlers call it — they do not re-implement it.

## Project Structure

### Documentation (this feature)

```text
specs/012-api-plugin/
├── plan.md              # This file
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── runtime-api.md
└── tasks.md
```

### Source Code

```text
lib/src/
├── plugins/
│   └── api/                                          # NEW
│       ├── api_plugin.dart                           # ApiPlugin
│       ├── builders/
│       │   └── api_bridge_builder.dart               # bridge file generator
│       └── capabilities/
│           └── create_api_bridge_capability.dart     # ZuraffaCapability
├── commands/
│   └── api_command.dart                              # CLI command (extends Command<void>)
├── core/
│   ├── api_endpoint.dart                             # ApiEndpoint model
│   └── api_bridge.dart                               # ZuraffaApiBridge runtime
├── cli/
│   └── plugin_loader.dart                            # MODIFIED: add ApiPlugin
└── zuraffa.dart                                      # MODIFIED: +enableApiInProfile, +exports

test/
├── plugins/api/
│   ├── api_plugin_test.dart
│   ├── api_bridge_builder_test.dart
│   └── api_command_test.dart
└── core/
    └── api_bridge_test.dart

example/test/
└── api_bridge_integration_test.dart          # US7: real UseCases, mock datasources, in-process
```

**Pattern decision**: Mirrors `MockPlugin` exactly:

- Plugin in `lib/src/plugins/api/` with `builders/` and `capabilities/` subdirectories
- Command extends `Command<void>` from `args` — same as `MockCommand`. It is NOT the `PluginCommand` in `commands/plugin_command.dart` (which is the unrelated `zfa plugin` management command). The correct base is `PluginCommand` from `commands/base_plugin_command.dart`.
- Registration in `PluginLoader._plugins()` alongside `MockPlugin`

**Runtime vs. generated split**:

- Framework ships: `ZuraffaApiBridge` (runtime) + `ApiPlugin` (codegen)
- Target app gets: `lib/src/api/bridges/{entity}_api_bridge.dart` (generated, calls framework runtime)

## Complexity Tracking

No constitution violations. This is a new feature, not a modification to existing behaviour. The plugin follows the identical structural pattern as `MockPlugin`.

## Integration Test Contract (User Story 7)

The acceptance test lives at `example/test/api_bridge_integration_test.dart`. It is a `flutter_test` file that exercises the full runtime stack without a running app or VM Service WebSocket.

**What it is NOT:**

- It does NOT call `developer.registerExtension` (that's the VM layer; not unit-testable).
- It does NOT mock UseCases or repositories. Mock datasources are real objects — the same ones DI wires in production.
- It does NOT require a running Flutter app or a VM Service port.

**What it IS:**

- It constructs `UseCase` instances directly with `ProductMockDataSource` / `ConcertMockDataSource`.
- It calls the handler functions (`_handleGetProductList`, `_handleCreateProduct`, etc.) directly in-process with synthesized `Map<String, String>` args.
- It parses `ServiceExtensionResponse.result` bodies as JSON and asserts on the decoded map.
- This is exactly what the VM Service does when a developer calls the extension over WebSocket — it just skips the WebSocket envelope.

**Why this split is correct**: `zuraffa/test/core/api_bridge_test.dart` tests `ZuraffaApiBridge` in isolation with stub inputs. The integration test tests the real data path — real UseCase calling real mock datasource, real `Result.fold()`, real `serializeResult`. These are two different levels of confidence. Both are required.

**DI wiring in the test** (no GetIt, no Flutter binding needed):

```dart
// Direct construction — no GetIt, no Flutter binding
final datasource = ProductMockDataSource(delay: Duration.zero);
final repository = DataProductRepository(datasource);
final getProductListUseCase = GetProductListUseCase(repository);
```

**Handler construction** (mirrors what codegen produces, minus `developer.registerExtension`):

```dart
Future<ServiceExtensionResponse> handleGetProductList(
  String method,
  Map<String, String> args,
) async {
  try {
    final useCase = getProductListUseCase;  // injected in test scope
    final result = await useCase(const ListQueryParams<Product>());
    return ZuraffaApiBridge.serializeResult(result, (list) =>
      {'items': list.map((p) => p.toJson()).toList()}
    );
  } catch (e, st) {
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}
```

**Assertion pattern**:

```dart
final response = await handleGetProductList('ext.zuraffa.product.getProductList', {});
final body = jsonDecode(response.result!) as Map<String, dynamic>;
expect(body['status'], 'success');
final items = body['data']['items'] as List;
expect(items.length, 3);
expect(items.first['id'], 'id 1');
```

**Stream test pattern** (uses `StreamController` to avoid 2-second `Stream.periodic` delay):

```dart
// Test datasource backed by a controller for immediate emission
final controller = StreamController<Concert>.broadcast();
// ... wire WatchConcertUseCase to this controller
// Call stream handler → get subscriptionId
// Push event to controller
// Call _handlePollStream → verify data
// Call _handleCancelStream → verify subscription removed
```

## Generated File Contract

The generated bridge file for entity `Product` looks like:

```dart
// GENERATED BY `zfa api Product` — DO NOT EDIT BY HAND

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kReleaseMode, kProfileMode;
import 'package:zuraffa/zuraffa.dart';
import 'package:my_app/src/domain/usecases/product/get_product_usecase.dart';
// ... other usecase imports

/// Registers all Product UseCase extensions with ZuraffaApiBridge.
/// Call this in main() after configureDependencies() and ZuraffaApiBridge.init().
void registerProductApiBridge() {
  if (kReleaseMode) return;
  if (kProfileMode && !Zuraffa.enableApiInProfile) return;

  ZuraffaApiBridge.registerEndpoint(
    endpoint: const ApiEndpoint(
      method: 'ext.zuraffa.product.getProduct',
      domain: 'product',
      usecase: 'getProduct',
      params: {'id': 'String'},
      returns: 'Product',
      isStream: false,
    ),
    handler: _handleGetProduct,
  );
  // ... one registerEndpoint call per UseCase
}

Future<ServiceExtensionResponse> _handleGetProduct(
  String method,
  Map<String, String> args,
) async {
  try {
    final id = args['id'] ?? '';
    final useCase = GetIt.I<GetProductUseCase>();
    final result = await useCase(id);
    return ZuraffaApiBridge.serializeResult(result, (p) => p.toJson());
  } catch (e, st) {
    developer.log('ext.zuraffa.product.getProduct error: $e', error: e, stackTrace: st);
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}
```

Key points:

- `serializeResult` and `errorResponse` live in `ZuraffaApiBridge` — generated code calls them.
- `result.fold(onSuccess, onFailure)` is the serialization API — `.when()` does not exist.
- `developer.log` (not `print`) for diagnostics.
- The success path passes a `toJson` function as a parameter — avoids `(data as dynamic).toJson()`.
