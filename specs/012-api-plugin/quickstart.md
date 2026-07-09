# Quickstart: API Plugin Validation

**Date**: 2026-07-09 | **Feature**: 012-api-plugin

## Prerequisites

- Zuraffa project with at least one entity created via `zfa entity create`
- At least one UseCase generated for that entity via `zfa make <Entity> --preset=crud`
- DI configured via `zfa make <Entity> --di`

## Validation Scenarios

### Scenario 1: Plugin Generation

```bash
# Generate API bridge for the entity
zfa api Product

# Expected output:
# ✅ Generation complete:
#   ✨ lib/src/api/bridges/product_api_bridge.dart
```

### Scenario 2: Analysis Check

```bash
# Verify generated code compiles
dart analyze lib/src/api/bridges/

# Expected: No errors (warnings OK)
```

### Scenario 3: Bridge Registration (in target app)

```dart
// In main.dart of the target Zuraffa app:
import 'package:my_app/src/api/bridges/product_api_bridge.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  // 1. DI setup
  configureDependencies();

  // 2. Initialize the bridge runtime (registers _list, _pollStream, _cancelStream)
  ZuraffaApiBridge.init();

  // 3. Enable in profile mode (optional)
  // Zuraffa.enableApiInProfile = true;  // uncomment to enable in profile mode

  // 4. Register entity bridges
  registerProductApiBridge();

  runApp(MyApp());
}

// Expected: App starts without errors in debug mode.
// In release mode, both ZuraffaApiBridge.init() and registerProductApiBridge() are no-ops.
```

### Scenario 4: Discovery Endpoint

```bash
# After running app in debug mode, connect VM Service client:
# Call: ext.zuraffa._list
# Expected: JSON array with all registered endpoints, e.g.:
# [
#   {
#     "method": "ext.zuraffa.product.getProduct",
#     "domain": "product",
#     "usecase": "getProduct",
#     "params": {"id": "String"},
#     "returns": "Product",
#     "isStream": false
#   }
# ]
```

### Scenario 5: UseCase Invocation

```bash
# Via VM Service WebSocket:
# Call: ext.zuraffa.product.getProduct with params {"id": "1"}
# Expected: {"status": "success", "data": { ... product JSON ... }}

# Call with invalid ID:
# Expected: {"status": "error", "failure": {"type": "notFound", "message": "..."}}
```

### Scenario 6: Release Mode Safety Check

```bash
# Build in release mode
flutter build apk --release   # or ios / macos

# Verify: no ext.zuraffa.* extensions appear in VM Service
# (The VM Service itself is typically unavailable in release builds)
```

## Expected Outcomes

| Scenario          | Expected Result                                                                |
| ----------------- | ------------------------------------------------------------------------------ |
| 1. Codegen        | Bridge file at `lib/src/api/bridges/product_api_bridge.dart`                   |
| 2. Analysis       | Zero errors from `dart analyze`                                                |
| 3. Registration   | `ZuraffaApiBridge.init()` then `registerProductApiBridge()` — no-op in release |
| 4. Discovery      | `_list` returns complete endpoint catalog                                      |
| 5. Invocation     | Correct success and error responses                                            |
| 6. Release safety | No extensions registered, zero overhead                                        |
