# Data Model: API Plugin

**Date**: 2026-07-09 | **Feature**: 012-api-plugin

## Runtime Types

### ZuraffaApiBridge

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kReleaseMode, kProfileMode;
import 'package:zuraffa/src/core/api_endpoint.dart';
import 'package:zuraffa/src/core/failure.dart';
import 'package:zuraffa/src/core/result.dart';
import 'package:vm_service/vm_service.dart' show ServiceExtensionResponse;

class _StreamRecord {
  final StreamSubscription subscription;
  dynamic latestValue;

  _StreamRecord(this.subscription);
}

class ZuraffaApiBridge {
  static bool _initialized = false;
  static final List<ApiEndpoint> _endpoints = [];
  static final Map<String, _StreamRecord> _streamSubscriptions = {};

  /// Initialize the bridge meta-extensions (_list, _pollStream, _cancelStream).
  ///
  /// Must be called BEFORE any register{Entity}ApiBridge() calls.
  /// No-op in release mode or if already initialized.
  /// In profile mode, only activates if [Zuraffa.enableApiInProfile] is true.
  static void init();

  /// Register a UseCase as a VM Service extension.
  ///
  /// Called exclusively from generated register{Entity}ApiBridge() functions.
  /// Stores [endpoint] metadata in [_endpoints] and registers [handler]
  /// with dart:developer.
  static void registerEndpoint({
    required ApiEndpoint endpoint,
    required Future<ServiceExtensionResponse> Function(String, Map<String, String>) handler,
  });

  /// Register a StreamUseCase subscription.
  ///
  /// Called from generated stream handlers. Stores the subscription and
  /// provides a callback for caching the latest emitted value.
  static void registerStreamSubscription(
    String subscriptionId,
    StreamSubscription subscription,
    void Function(dynamic latestValue) onValue,
  );

  /// Serialize a Result<T, AppFailure> to a ServiceExtensionResponse.
  ///
  /// Uses result.fold() — the correct API for Zuraffa's sealed Result type.
  /// [toJson] is provided by the generated caller because only the generated
  /// code knows the concrete return type T at codegen time.
  ///
  /// This is the SINGLE authoritative serialization implementation.
  /// Generated handlers MUST call this method — never re-implement it locally.
  static ServiceExtensionResponse serializeResult<T>(
    Result<T, AppFailure> result,
    Map<String, dynamic> Function(T value) toJson,
  );

  /// Return a structured error response.
  ///
  /// Generated catch blocks call this — never construct the JSON inline.
  static ServiceExtensionResponse errorResponse(String type, String message);

  // --- Private meta-extension handlers ---

  static Future<ServiceExtensionResponse> _handleList(
    String method,
    Map<String, String> parameters,
  );

  static Future<ServiceExtensionResponse> _handlePollStream(
    String method,
    Map<String, String> parameters,
  );

  static Future<ServiceExtensionResponse> _handleCancelStream(
    String method,
    Map<String, String> parameters,
  );
}
```

**Why `toJson` is a parameter on `serializeResult`**:

The old design used `(data as dynamic).toJson()` which abandons Dart's type system. The generated code knows the concrete type `T` at codegen time. Passing `(p) => p.toJson()` keeps the type system intact, avoids reflection, and is verifiable at compile time.

**Why `_streamSubscriptions` uses `_StreamRecord` not `StreamSubscription`**:

The poll extension needs both the subscription (to cancel) and the latest emitted value (to return). A plain `Map<String, StreamSubscription>` can't hold the cached value. `_StreamRecord` holds both.

### ApiEndpoint

```dart
/// Immutable metadata for a single registered UseCase extension.
@immutable
class ApiEndpoint {
  final String method;        // e.g. "ext.zuraffa.product.getProduct"
  final String domain;        // e.g. "product"
  final String usecase;       // e.g. "getProduct"
  final Map<String, String> params;  // e.g. {"id": "String"}
  final String returns;       // e.g. "Product"
  final bool isStream;

  const ApiEndpoint({
    required this.method,
    required this.domain,
    required this.usecase,
    required this.params,
    required this.returns,
    required this.isStream,
  });

  Map<String, dynamic> toJson() => {
    'method': method,
    'domain': domain,
    'usecase': usecase,
    'params': params,
    'returns': returns,
    'isStream': isStream,
  };
}
```

## Codegen Types (Plugin Layer)

### ApiPlugin

```dart
class ApiPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final FileSystem fileSystem;

  ApiPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

  @override
  String get id => 'api';

  @override
  String get name => 'API Plugin';

  @override
  String get version => '1.0.0';

  @override
  List<ZuraffaCapability> get capabilities => [CreateApiBridgeCapability(this)];

  @override
  Command createCommand() => ApiCommand(this);

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context);

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config);
}
```

### Generated Bridge File Structure

**Path**: `lib/src/api/bridges/{entity_snake}_api_bridge.dart`

```dart
// GENERATED BY `zfa api {EntityName}` — DO NOT EDIT BY HAND

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kReleaseMode, kProfileMode;
import 'package:get_it/get_it.dart';
import 'package:zuraffa/zuraffa.dart';
// ... usecase imports

/// Registers all {EntityName} UseCase extensions with ZuraffaApiBridge.
///
/// Prerequisites: call ZuraffaApiBridge.init() first, then configureDependencies(),
/// then call this function before runApp().
void register{EntityName}ApiBridge() {
  if (kReleaseMode) return;
  if (kProfileMode && !Zuraffa.enableApiInProfile) return;

  ZuraffaApiBridge.registerEndpoint(
    endpoint: const ApiEndpoint(
      method: 'ext.zuraffa.{domain}.{usecaseName}',
      domain: '{domain}',
      usecase: '{usecaseName}',
      params: {'{paramName}': '{paramType}'},
      returns: '{returnType}',
      isStream: false,
    ),
    handler: _handle{UseCaseName},
  );
  // ... one call per UseCase
}

// --- Handlers ---

/// Handler for {UseCaseName} — single primitive param example
Future<ServiceExtensionResponse> _handle{UseCaseName}(
  String method,
  Map<String, String> args,
) async {
  try {
    final id = args['id'] ?? '';
    final useCase = GetIt.I<{UseCaseName}>();
    final result = await useCase(id);
    return ZuraffaApiBridge.serializeResult(result, (p) => p.toJson());
  } catch (e, st) {
    developer.log(
      'Bridge error: $method',
      error: e,
      stackTrace: st,
      name: 'ZuraffaApiBridge',
    );
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}

/// Handler for {UseCaseName} — complex params object example
Future<ServiceExtensionResponse> _handle{UseCaseName}(
  String method,
  Map<String, String> args,
) async {
  try {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(args['args'] ?? '{}') as Map<String, dynamic>;
    } catch (e) {
      return ZuraffaApiBridge.errorResponse('deserialization', e.toString());
    }
    final params = {ParamsType}.fromJson(json);
    final useCase = GetIt.I<{UseCaseName}>();
    final result = await useCase(params);
    return ZuraffaApiBridge.serializeResult(result, (p) => p.toJson());
  } catch (e, st) {
    developer.log(
      'Bridge error: $method',
      error: e,
      stackTrace: st,
      name: 'ZuraffaApiBridge',
    );
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}
```

**Key invariants enforced in generated code**:

1. `kReleaseMode` guard is always the first statement in `register{Entity}ApiBridge()`.
2. `serializeResult(result, toJson)` — never `(data as dynamic).toJson()`.
3. `result.fold(...)` inside `serializeResult` — never `.when()` (does not exist on Zuraffa's `Result`).
4. `developer.log()` not `print()` for bridge diagnostics.
5. Deserialization errors are caught separately and return `'deserialization'` type — not lumped with `'unknown'`.

### Zuraffa Facade Changes

```dart
// lib/zuraffa.dart

abstract class Zuraffa {
  /// Enable the API bridge in profile mode.
  ///
  /// Debug mode always has the bridge enabled (when ZuraffaApiBridge.init() is called).
  /// Release mode never has the bridge enabled — this flag is irrelevant in release.
  /// Profile mode is opt-in: set this to true before calling init() and register*().
  static bool enableApiInProfile = false;

  // ... existing fields and methods
}
```
