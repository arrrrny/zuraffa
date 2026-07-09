# API Plugin — Contracts

## Plugin-Capability Contract

### `zfa api <EntityName>` — CLI Interface

```bash
zfa api <EntityName> [options]
```

**Options**:
| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--output` | String | `lib/src` | Output directory for generated bridge files |
| `--dry-run` | Flag | false | Preview generated files without writing |
| `--force` | Flag | false | Overwrite existing bridge files |
| `--verbose` | Flag | false | Enable detailed logging |
| `--domain` | String | — | Override the domain folder for the entity |
| `--revert` | Flag | false | Remove generated bridge files |

**Exit codes**: 0 = success, 1 = error

**Output**: Generated bridge file at `lib/src/api/bridges/{entity_snake}_api_bridge.dart`

**Errors**:
- Entity not found in project → "Entity '{name}' not found. Run `zfa entity create` first."
- No UseCases found for entity → "No UseCases found for '{name}'. Run `zfa make {name}` first."
- Bridge already exists (without `--force`) → "Bridge file already exists. Use --force to overwrite."

---

## Runtime API Contract

### `ZuraffaApiBridge` — Public API

```dart
/// Initializes the API bridge by scanning GetIt for UseCase registrations
/// and registering each one as a VM Service extension.
///
/// Must be called after all UseCases are registered in the DI container
/// (typically at the end of main(), after all setup() calls).
///
/// In release mode, this is a no-op.
/// In profile mode, only activates if [Zuraffa.enableApiInProfile] is true.
/// In debug mode, always activates.
void ZuraffaApiBridge.init();
```

### `Zuraffa` Facade — API Bridge Configuration

```dart
abstract class Zuraffa {
  /// When true, the API bridge is enabled in profile mode.
  /// Default: false (profile mode = no bridge).
  /// Debug mode always enables the bridge regardless of this flag.
  /// Release mode never enables the bridge regardless of this flag.
  static bool enableApiInProfile = false;
}
```

### Generated Bridge File Contract

Each generated bridge file exposes exactly one public function:

```dart
/// Call this in main() after DI setup, before runApp().
void register{EntityName}ApiBridge();
```

The developer calls it like:

```dart
void main() {
  // 1. DI setup
  configureDependencies();

  // 2. Enable profile mode if needed
  Zuraffa.enableApiInProfile = true;

  // 3. Register bridges
  registerProductApiBridge();
  registerCustomerApiBridge();

  // 4. Start the app
  runApp(MyApp());
}
```

### VM Service Extension Protocol

**Call**:
```json
{
  "jsonrpc": "2.0",
  "method": "ext.zuraffa.<domain>.<usecase>",
  "params": {
    "isolateId": "<isolate_id>",
    "args": {
      "<param1>": "<value1>",
      "<param2>": "<value2>"
    }
  },
  "id": "<request_id>"
}
```

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "success",
    "data": { ... }
  },
  "id": "<request_id>"
}
```

**Error Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "error",
    "failure": {
      "type": "notFound|validation|deserialization|unknown",
      "message": "Human-readable error description"
    }
  },
  "id": "<request_id>"
}
```

**Stream Response** (initial call):
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "streaming",
    "subscriptionId": "<uuid>"
  },
  "id": "<request_id>"
}
```

**Meta-extensions**:

| Extension | Params | Returns |
|-----------|--------|---------|
| `ext.zuraffa._list` | none | JSON array of `ApiEndpoint` objects |
| `ext.zuraffa._pollStream` | `subscriptionId` | Latest emitted value or null |
| `ext.zuraffa._cancelStream` | `subscriptionId` | `{"status": "cancelled"}` |

### Discovery Response

```json
[
  {
    "method": "ext.zuraffa.product.getProduct",
    "domain": "product",
    "usecase": "getProduct",
    "params": { "id": "String" },
    "returns": "Product",
    "isStream": false
  },
  {
    "method": "ext.zuraffa.product.getProductList",
    "domain": "product",
    "usecase": "getProductList",
    "params": { "query": "ProductQueryParams" },
    "returns": "List<Product>",
    "isStream": false
  }
]
```
