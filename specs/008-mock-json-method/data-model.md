# Data Model: Mock JSON Data Method

## Entities

### MockJsonHelper (Generated Dart File)
A generated Dart source file containing a class with static async methods that load and deserialize JSON mock data.

**Fields**:
- `entityName`: String — the PascalCase entity name (e.g., `Product`)
- `domain`: String — domain grouping for the entity (e.g., `catalog`)
- `jsonFilePath`: String — relative path to the JSON data file
- `methods`: List<HelperMethod> — typed accessor methods

**HelperMethod variants**:
| Method | Signature | Description |
|--------|-----------|-------------|
| `load{Entity}s()` | `Future<List<{Entity}>>` | Load all mock instances |
| `loadSample{Entity}()` | `Future<{Entity}>` | Load first instance |
| `loadSampleList()` | `Future<List<{Entity}>>` | Load all instances (alias) |
| `loadEmptyList()` | `Future<List<{Entity}>>` | Returns empty list (for testing) |

**Relationships**: One `MockJsonHelper` per entity, references entity's `fromJson`.

---

### MockJsonFile (Generated JSON File)
A JSON file containing an array of mock entity objects.

**Structure**:
```json
[
  {
    "field1": "value1",
    "field2": 42,
    "_type": "SubEntity"  // only for polymorphic hierarchies
  }
]
```

**Fields**:
- `filePath`: String — relative path (e.g., `data/mock_json/catalog/product.mock.json`)
- `entityName`: String — the PascalCase entity name
- `instances`: int — number of mock instances (default: 3)
- `discriminator`: String? — `_type` field value for polymorphic types

**Relationships**: One file per entity. Nested entities get their own JSON files.

---

### MockJsonGenerationMetadata (Hidden Metadata File)
A lightweight metadata file tracking generation state for non-overwrite safety.

**Fields**:
- `generatedHash`: String — hash of the generated JSON content when last written
- `generatedAt`: DateTime — timestamp of last generation
- `entityFields`: Map<String,String> — field signature at generation time (for mismatch detection)

**Relationship**: One `.mock.json.meta` companion file per `.mock.json` file.

---

### Folder Convention

```
{outputDir}/
└── data/
    ├── mock/                          # Existing Dart mock data
    │   └── {entity_snake}_mock_data.dart
    └── mock_json/                     # NEW: JSON mock data
        └── {domain}/                  # Domain grouping
            ├── {entity_snake}.mock.json       # JSON data file
            ├── {entity_snake}.mock.json.meta  # Generation metadata
            └── {entity_snake}_mock_json.dart  # Dart helper file
```

**Rules**:
- `{domain}` is derived from the entity's location under `lib/src/domain/entities/{domain}/` or from explicit `--domain` flag
- `{entity_snake}` uses `StringUtils.camelToSnake()` (existing convention)
- JSON files use `.mock.json` extension to clearly distinguish from application JSON assets
- Dart helper uses `_mock_json.dart` suffix to distinguish from `_mock_data.dart`
