# Research: API Plugin

**Date**: 2026-07-09 | **Feature**: 012-api-plugin

## Research Tasks & Findings

### R1: Plugin Structure — Mirror MockPlugin

**Task**: Determine the structural pattern for the new API plugin.

**Decision**: Mirror the `MockPlugin` structure exactly:

1. `ApiPlugin` extends `FileGeneratorPlugin` implements `CliAwarePlugin`
2. `ApiCommand` extends `PluginCommand` from `commands/base_plugin_command.dart` — NOT `commands/plugin_command.dart` which is the unrelated `zfa plugin` management command
3. `CreateApiBridgeCapability` — implements `ZuraffaCapability`
4. `ApiBridgeBuilder` — handles the actual file generation

**Constructor signature** (from reading `MockPlugin` source):

```dart
ApiPlugin({required String outputDir, GeneratorOptions options = const GeneratorOptions(), FileSystem? fileSystem})
```

**Rationale**: The mock plugin pattern is the canonical reference for "standalone CLI plugin" in Zuraffa. It has a clear 4-component structure (plugin, command, capability, builder) and is already well-tested.

**Alternatives considered**:

- `--with=api` flag on `make` command — rejected. Dedicated plugins are canonical v5 approach.
- Subcommand of an existing plugin — rejected. SRP violation.

---

### R2: Runtime Bridge — How to Register VM Service Extensions

**Task**: Determine the runtime mechanism for registering UseCases as VM Service extensions.

**Decision**: Use `dart:developer`'s `registerExtension()` API directly from `ZuraffaApiBridge`:

```dart
import 'dart:developer' as developer;

static void registerEndpoint({
  required ApiEndpoint endpoint,
  required Future<ServiceExtensionResponse> Function(String, Map<String, String>) handler,
}) {
  _endpoints.add(endpoint);
  developer.registerExtension(endpoint.method, handler);
}
```

**Rationale**: Standard Dart VM Service extension API. Stable, well-documented, available in debug/profile modes. `ServiceExtensionResponse.result(json)` and `ServiceExtensionResponse.error(code, message)` provide the response envelope.

**Alternatives considered**:

- WebSocket server (shelf) — rejected. Additional dependencies, port management. VM Service is already available in debug/profile.
- MethodChannel — rejected. Platform-specific; UseCases are pure Dart.

---

### R3: The Registration Model — Who Calls What

**Task**: Clarify the relationship between `ZuraffaApiBridge.init()` and the generated `register{Entity}ApiBridge()` functions.

**Decision**: The model is delegation, not scanning.

- `ZuraffaApiBridge.init()` — registers only the three meta-extensions (`_list`, `_pollStream`, `_cancelStream`). It does NOT scan GetIt.
- Generated `register{Entity}ApiBridge()` — calls `ZuraffaApiBridge.registerEndpoint()` once per UseCase. This is the only way UseCases enter the bridge's registry.

**Why GetIt cannot be scanned**: GetIt has no public introspection API for listing all registrations by type or base class. You cannot enumerate `GetIt.instance` and extract UseCase subclasses at runtime. Any plan document that says "scans GetIt" is wrong.

**Correct call sequence in `main()`**:

```dart
void main() {
  configureDependencies();         // 1. Register all UseCases in GetIt
  ZuraffaApiBridge.init();         // 2. Register meta-extensions only
  registerProductApiBridge();      // 3. Register Product UseCase extensions
  registerCustomerApiBridge();     // 4. Register Customer UseCase extensions
  runApp(MyApp());
}
```

**Rationale**: Explicit registration by the developer is the correct model. It makes the set of bridged entities visible and auditable at the call site, not implicit via reflection.

---

### R4: Parameter Deserialization Strategy

**Task**: Determine how to deserialize VM Service extension args into UseCase parameter types.

**Decision**: Two-tier deserialization generated at codegen time:

1. **Primitive params** (`String`, `int`, `double`, `bool`): extract directly from `Map<String, String> args` by key name. The VM Service passes all params as strings — primitive coercion is trivial.

2. **Complex params objects** (Zorphy entity or params class): the full args are passed as a JSON-encoded string under the `args` key. The generated handler calls `jsonDecode(args['args'] ?? '{}')` and passes the resulting map to `{ParamsType}.fromJson(map)`.

3. **NoParams**: generate `useCase(NoParams())` — no deserialization needed.

```dart
// Generated for UseCase<Product, String>
final id = args['id'] ?? '';
final result = await useCase(id);

// Generated for UseCase<Product, CreateProductParams>
final json = jsonDecode(args['args'] ?? '{}') as Map<String, dynamic>;
final params = CreateProductParams.fromJson(json);
final result = await useCase(params);

// Generated for UseCase<List<Product>, NoParams>
final result = await useCase(NoParams());
```

Deserialization errors are caught in a separate inner try-catch and return `ZuraffaApiBridge.errorResponse('deserialization', ...)` — not lumped with `'unknown'` errors from UseCase execution.

**Rationale**: Zorphy entities always generate `fromJson`/`toJson`. Generated code handles both cases explicitly — no reflection, fully type-checked at analyze time.

---

### R5: Result Serialization — Result<T, AppFailure>

**Task**: Determine how to serialize `Result<T, AppFailure>` to JSON correctly.

**Decision**: `ZuraffaApiBridge.serializeResult<T>(Result<T, AppFailure> result, Map<String, dynamic> Function(T) toJson)` uses `result.fold()`:

```dart
static ServiceExtensionResponse serializeResult<T>(
  Result<T, AppFailure> result,
  Map<String, dynamic> Function(T value) toJson,
) {
  return result.fold(
    (value) => ServiceExtensionResponse.result(
      jsonEncode({'status': 'success', 'data': toJson(value)}),
    ),
    (failure) => ServiceExtensionResponse.result(
      jsonEncode({'status': 'error', 'failure': failure.toJson()}),
    ),
  );
}
```

**CRITICAL**: Zuraffa's `Result<S, F>` sealed class has `fold(onSuccess, onFailure)`. It does NOT have `.when()`. Any generated code using `.when()` will fail to compile.

**Why `toJson` is a parameter**: The alternative `(data as dynamic).toJson()` silently defeats the type system. Passing `(p) => p.toJson()` as a function keeps Dart's type checker in the loop. The generated handler knows the concrete type — it passes the correct function.

**This lives in `ZuraffaApiBridge` only**: Generated handlers call `ZuraffaApiBridge.serializeResult(result, (p) => p.toJson())`. They do NOT implement serialization locally. One implementation, one place to fix.

---

### R6: Stream UseCase Handling

**Task**: Determine how to bridge `StreamUseCase<T, P>`.

**Decision**: Subscription-handle pattern with `_StreamRecord`:

1. On initial call: subscribe to the stream, generate a UUID, store `_StreamRecord(subscription)` in `ZuraffaApiBridge._streamSubscriptions`, return `{"status": "streaming", "subscriptionId": uuid}`.
2. Each emitted value: update `record.latestValue`.
3. `ext.zuraffa._pollStream`: return `record.latestValue` or `{"status": "pending"}` if no value yet.
4. `ext.zuraffa._cancelStream`: cancel subscription, remove from map, return `{"status": "cancelled"}`.

**Why `_StreamRecord` not `StreamSubscription`**: The poll extension needs the latest value. A plain `Map<String, StreamSubscription>` cannot hold it. `_StreamRecord` holds both subscription and cached value in a single slot.

**Rationale**: VM Service extensions are request-response. Streams don't map natively. The subscription-handle pattern is the simplest correct approach within protocol constraints.

---

### R7: Debug-Only Safety Gate

**Task**: Ensure the bridge never activates in release mode.

**Decision**: Two independent guards — one in the runtime `init()`, one generated into each bridge file:

**In `ZuraffaApiBridge.init()`**:

```dart
if (kReleaseMode || _initialized) return;
if (kProfileMode && !Zuraffa.enableApiInProfile) return;
```

**In every generated `register{Entity}ApiBridge()`**:

```dart
if (kReleaseMode) return;
if (kProfileMode && !Zuraffa.enableApiInProfile) return;
```

Both guards are needed: `init()` may be called without generated bridges (or vice versa if developer forgets to call init). Each generated bridge is self-contained.

**Tree-shaking**: `kReleaseMode` is a compile-time constant. The Dart compiler eliminates the entire function body after the `if (kReleaseMode) return;` guard in release builds. Zero overhead, zero reachable code paths.

---

### R8: Generated File Location

**Task**: Where should the generated bridge code files be written?

**Decision**: Write to `lib/src/api/bridges/{entity_snake}_api_bridge.dart`.

This is the ONLY location. All documents must agree on this path. The quickstart previously had an inconsistent example (`lib/src/.../product/product_api_bridge.dart`) — that was wrong. The canonical path is `lib/src/api/bridges/`.

**Rationale**: Consistent with other generated files in target apps. Groups all bridge files in a predictable, single-purpose directory. Easy to gitignore if needed.

---

### R9: `PluginCommand` Naming Confusion

**Task**: Identify the correct base class for `ApiCommand`.

**Finding**: There are two files in the codebase with similar names:

- `commands/plugin_command.dart` — `class PluginCommand` — this is the `zfa plugin list/enable/disable` management command. **Not the base for ApiCommand.**
- `commands/base_plugin_command.dart` — `abstract class PluginCommand extends Command<void>` — this IS the correct base for all generated-code commands. `MockCommand` extends this.

**Decision**: `ApiCommand extends PluginCommand` where `PluginCommand` is imported from `commands/base_plugin_command.dart`. All spec/plan/task documents must cite `base_plugin_command.dart`.
