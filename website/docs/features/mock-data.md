# Mock Data

Mock generation is part of the v5 `make` workflow.

---

## Generation

### 1. Basic mocks

```bash
zfa make Product --preset=crud --methods=get,getList --mock
```

### 2. Auto-wired mocks with DI

```bash
zfa make Product --preset=crud --methods=get,getList --mock --di --use-mock
```

---

## JSON Mock Data (v5.1.0)

Generate standalone JSON mock files with `fromJson`-based Dart helpers. Swap JSON content for fast prototyping without code changes.

### Generate JSON mocks

```bash
zfa mock json Product
```

Or via the main mock command:

```bash
zfa mock Product --json
```

### Folder convention

```
lib/src/data/mock_json/{domain}/
├── {entity_snake}.mock.json       # 3 mock instances as formatted JSON
├── {entity_snake}.mock.json.meta  # Generation metadata (hash, field signature)
└── {entity_snake}_mock_json.dart  # fromJson-based Dart helper
```

### Using the generated helper

```dart
import 'data/mock_json/catalog/product_mock_json.dart';

final products = await ProductMockJson.loadProducts();
final sample = await ProductMockJson.loadSampleProduct();
```

### Swapping mock data

1. Generate JSON mock data: `zfa mock json Product`
2. Edit `data/mock_json/catalog/product.mock.json` with custom data
3. Re-run the app — changes are picked up immediately
4. No code regeneration needed

JSON files are not overwritten by default on regeneration — use `--force` to intentionally replace user-edited files.

---

## What gets generated?

When mock generation is enabled, Zuraffa can add:

- static mock data (Dart or JSON)
- mock datasources
- DI wiring for mock-first development flows

---

## Next steps

- [Dependency Injection](./dependency-injection)
- [Testing Strategy](./testing)
- [CLI Commands Reference](../cli/commands)
