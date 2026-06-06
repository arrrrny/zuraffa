# Quickstart: Mock JSON Data Method

## Overview

The JSON mock method generates standalone JSON data files for entities and Dart helper code that loads them at runtime via `fromJson`. This enables fast prototyping by swapping JSON content without regenerating or modifying any Dart code.

## Commands

### Generate JSON mock data for an entity

```bash
zfa mock json Product
```

This creates:
- `data/mock_json/catalog/product.mock.json` — 3 mock Product instances as JSON
- `data/mock_json/catalog/product_mock_json.dart` — async Dart helper with typed accessors
- `data/mock_json/catalog/product.mock.json.meta` — metadata for non-overwrite safety

### Generate JSON mock data with explicit domain

```bash
zfa mock json Product --domain=inventory
```

### Preview without writing files

```bash
zfa mock json Product --dry-run
```

### Force overwrite existing JSON files

```bash
zfa mock json Product --force
```

### Via the main mock command flag

```bash
zfa mock Product --json
```

## Using the Generated Helper

```dart
import 'data/mock_json/catalog/product_mock_json.dart';

// Load all products from JSON
final products = await ProductMockJson.loadProducts();

// Load first product
final sample = await ProductMockJson.loadSampleProduct();

// Load sample list
final list = await ProductMockJson.loadSampleList();
```

## Swapping Mock Data

1. Generate JSON mock data: `zfa mock json Product`
2. Edit `data/mock_json/catalog/product.mock.json` with different data
3. Re-run the app — the helper reads the modified JSON file
4. No code changes or regeneration needed

## Folder Convention

```
lib/src/data/mock_json/
└── {domain}/                         # e.g., catalog, checkout
    ├── {entity}.mock.json            # JSON data file
    ├── {entity}.mock.json.meta       # Internal metadata
    └── {entity}_mock_json.dart       # Dart helper
```

## Supported Field Types

| Type | JSON Format | Example |
|------|-------------|---------|
| String | JSON string | `"name 1"` |
| int | JSON number | `10` |
| double | JSON number | `10.5` |
| bool | JSON boolean | `true` |
| DateTime | ISO 8601 string | `"2026-01-01T12:00:00.000"` |
| Enum | String (`.name`) | `"active"` |
| List<T> | JSON array | `[...]` |
| Map<K,V> | JSON object | `{...}` |
| Nested Entity | Nested JSON object | `{"id": "1", ...}` |
| Polymorphic | Includes `_type` discriminator | `{"_type": "SubType", ...}` |

## Non-Overwrite Safety

- Generated JSON files include a `.meta` hash file
- On regeneration, the tool detects user-edited files and skips them
- Use `--force` to intentionally overwrite edited files
