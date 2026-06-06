# CLI Interface Contract: Mock JSON Command

## Command Structure

```
zfa mock json <EntityName> [options]
```

## Subcommand

| Field | Value |
|-------|-------|
| Name | `json` |
| Parent | `zfa mock` |
| Description | Generate JSON mock data and fromJson-based Dart helpers |

## Arguments

| Argument | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `EntityName` | positional | Yes | — | PascalCase entity name |

## Options

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--domain` | String | No | auto-detected | Domain folder for grouping JSON files |
| `--force` / `-f` | Boolean | No | `false` | Overwrite existing JSON files |
| `--dry-run` | Boolean | No | `false` | Preview generation without writing |
| `--verbose` / `-v` | Boolean | No | `false` | Enable detailed output |

## Alternative: Flag on Main Mock Command

```
zfa mock <EntityName> --json [--domain <domain>]
```

The `--json` flag on the main `zfa mock` command generates JSON mock data instead of (or in addition to) standard Dart mock data.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success — all files generated |
| 1 | Error — entity not found, JSON invalid, or other failure |
| 2 | Skipped — existing files found, use --force to overwrite |

## Output Format (stdout)

```
✅ JSON mock data generated for: Product
  📄 data/mock_json/catalog/product.mock.json (3 instances)
  📄 data/mock_json/catalog/product_mock_json.dart (helper)
  📄 data/mock_json/catalog/product.mock.json.meta (metadata)

Nested entities:
  📄 data/mock_json/catalog/order_item.mock.json (3 instances)
  📄 data/mock_json/catalog/order_item_mock_json.dart (helper)
```

## Error Output Format (stderr)

```
❌ Entity 'NotAnEntity' not found under lib/src/domain/entities/
❌ Force flag required: data/mock_json/catalog/product.mock.json already exists
❌ JSON generation failed for 'OrderItem': unknown field type 'CustomType'
```
