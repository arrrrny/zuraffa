# Plugin Capability Contract: JsonMockCapability

## Capability Identity

- **ID**: `mock.json`
- **Plugin**: `MockPlugin`
- **Capability Name**: `json`
- **Description**: Generate mock data as JSON files with `fromJson`-based Dart helpers

## Input Schema

```json
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "description": "Entity name to generate JSON mock data for"
    },
    "domain": {
      "type": "string",
      "description": "Domain folder for grouping JSON files"
    },
    "force": {
      "type": "boolean",
      "description": "Force overwrite existing JSON files",
      "default": false
    },
    "dryRun": {
      "type": "boolean",
      "description": "Preview without writing files",
      "default": false
    },
    "verbose": {
      "type": "boolean",
      "description": "Enable verbose logging",
      "default": false
    }
  },
  "required": ["name"]
}
```

## Output Schema

```json
{
  "type": "object",
  "properties": {
    "files": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Paths of generated files"
    }
  }
}
```

## Capability Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `plan(Map)` | `Future<EffectReport>` | Dry-run plan showing affected files |
| `execute(Map)` | `Future<ExecutionResult>` | Execute generation and return results |

## Generated File Types

| Type | Action | Path Pattern |
|------|--------|-------------|
| `mock_json` | `created` | `data/mock_json/{domain}/{entity_snake}.mock.json` |
| `mock_json_meta` | `created` | `data/mock_json/{domain}/{entity_snake}.mock.json.meta` |
| `mock_json_helper` | `created` | `data/mock_json/{domain}/{entity_snake}_mock_json.dart` |

## Contract Guarantees

1. JSON files are valid RFC 8259 on first generation
2. Generated Dart helper uses `{Entity}.fromJson()` for all deserialization
3. Non-overwrite safety: existing user-edited JSON files are not overwritten without `--force`
4. Nested entity relationships trigger recursive JSON generation
5. Polymorphic entities include `_type` discriminator in JSON output
