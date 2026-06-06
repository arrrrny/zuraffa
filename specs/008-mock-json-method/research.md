# Research: Mock JSON Data Method

## 1. How does the existing mock plugin generate heuristic mock data?

**Decision**: Reuse `MockValueBuilder`'s value generation logic, but produce `Map<String, dynamic>` (JSON-serializable) data instead of `code_builder` `Expression` objects.

**Rationale**: The existing `MockValueBuilder` generates mock values for 3 instances per entity using field-type heuristics (String → `'fieldName 1'`, int → `1 * 10`, DateTime → `DateTime.now().subtract(...)`, etc.). For JSON output, the same mapping logic should produce native Dart values (`String`, `int`, `double`, `bool`, `List`, `Map`) that can be serialized via `jsonEncode()`. This avoids duplicating the heuristic logic and ensures consistency between the Dart-mock and JSON-mock output formats.

**Alternatives considered**:
- Write entirely new JSON-specific value generation → duplicates logic, harder to maintain parity
- Use `dart:mirrors` to instantiate entities and serialize → doesn't work with all codebases, requires runtime compilation steps

## 2. How should JSON files be structured for `fromJson` compatibility?

**Decision**: Generate JSON arrays of objects where each object has field names matching the entity's `fromJson` expected key format. Use Zorphy's default key convention (field name as-is, e.g., `{"id": "id 1", "name": "name 1"}`).

**Rationale**: Zorphy-generated `fromJson` methods expect JSON keys to match the Dart field names directly (not snake_case). The existing entity analysis already extracts field names and types. By producing JSON objects with PascalCase/camelCase keys matching the entity fields, `fromJson` can deserialize without any mapping layer.

**Alternatives considered**:
- Snake_case keys → would require mapping in fromJson, adds complexity
- Nested `data` wrapper → unnecessary indirection

## 3. What is the clean folder convention for mock JSON data?

**Decision**: Use `data/mock_json/{domain}/{entity_snake}.mock.json` for JSON data files and `data/mock_json/{domain}/{entity_snake}_mock_json.dart` for the Dart helper.

**Rationale**:
- `data/mock_json/` keeps JSON files completely separate from generated Dart mocks (`data/mock/`)
- `{domain}/` grouping prevents naming collisions (two entities named `Config` in different domains)
- `{entity_snake}.mock.json` follows existing snake_case naming conventions (`{entity_snake}_mock_data.dart`)
- The `mock_json` prefix in the directory name clearly communicates these are JSON-backed mocks

**Alternatives considered**:
- `data/mock/{entity_snake}_mock_data.json` → conflates JSON with Dart files, harder to manage separately
- `assets/mock_json/` → Flutter-specific convention, not universal for Dart CLI usage
- No domain grouping → naming collisions possible

## 4. How should the Dart helper file work?

**Decision**: Generate a Dart file with async static methods that read JSON from disk using `dart:convert` and entity `fromJson`:

```dart
class ProductMockJson {
  static Future<List<Product>> loadProducts() async {
    final jsonStr = await rootBundle.loadString('data/mock_json/catalog/product.mock.json');
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }
  
  static Future<Product> loadSampleProduct() async {
    final list = await loadProducts();
    return list.first;
  }
}
```

**Rationale**: The helper provides typed accessors, keeps JSON file path concerns in one place, and uses `Future` return types for async I/O. The `fromJson` factory is called for each JSON object. The file path is a string constant that can be trivially changed by the developer.

**Alternatives considered**:
- Synchronous API → doesn't work with asset loading in Flutter
- Separate JSON loading logic in each caller → violates DRY
- Code generation of the JSON file path into each consumer → harder to swap

## 5. How should the new capability integrate with the existing CLI?

**Decision**: Add a `json` subcommand to `MockCommand` (`zfa mock json <Entity>`) and a new `JsonMockCapability` class alongside `CreateMockCapability`. Add a `--json` flag to the existing `zfa mock` command.

**Rationale**: 
- Subcommand follows existing pattern: `zfa mock data` already exists as a subcommand
- New capability class keeps JSON mock logic separate from existing Dart mock capability
- `--json` flag on the main mock command offers convenience for single-invocation workflows

**Alternatives considered**:
- Separate top-level command `zfa mock-json` → pollutes command namespace
- Config flag only (`.zfa.json`) → inconvenient for quick prototyping

## 6. How should non-overwrite safety work for user-edited JSON files?

**Decision**: Use a generation hash stored in a companion `.generation` metadata file. On regeneration, compare the stored hash with the hash of the current generation output. If the JSON file content differs from what was last generated AND differs from the hash, treat it as user-edited and skip overwrite unless `--force` is used.

**Rationale**: Simple hash comparison avoids false positives from minor whitespace changes. The metadata file approach keeps the JSON files clean (no embedded comments). This follows the existing `force`/`skipRevertIfExisted` patterns in `FileUtils`.

**Alternatives considered**:
- Always overwrite → destroys user modifications
- Never overwrite → makes intentional regeneration cumbersome
- Embedded metadata header in JSON → pollutes JSON content

## 7. How should polymorphic/sealed entity hierarchies be handled in JSON?

**Decision**: Include a `_type` discriminator field in each JSON object for polymorphic entities. The generated helper code reads `_type`, looks up the correct subtype's `fromJson`, and delegates deserialization.

**Rationale**: The entity analyzer already detects polymorphic subtypes via Zorphy annotations and sealed class detection. Adding a discriminator field follows the standard pattern used in JSON serialization libraries (json_serializable, freezed).

**Alternatives considered**:
- Separate JSON files per subtype → harder to manage, breaks the "one file per entity" convention
- Union type wrapper → adds unnecessary nesting

## 8. How should DateTime and enum serialization work?

**Decision**:
- **DateTime**: Serialize as ISO 8601 string (Zorphy's default format). The `fromJson` method already expects this format.
- **Enums**: Serialize as their `.name` string value (e.g., `"active"` for `Status.active`). Zorphy-generated `fromJson` already handles enum name deserialization.

**Rationale**: These are the default Zorphy serialization formats, so no special handling is needed beyond emitting the correct JSON value types.

**Alternatives considered**:
- DateTime as timestamp → would break existing `fromJson` expectations
- Enums as ordinal indices → fragile, breaks if enum order changes
