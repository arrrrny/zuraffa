# CLI Interface Contract: Cache Adapter Command

**Feature**: Cache Adapter Command
**Date**: 2026-06-12

## Command Signature

```bash
zfa cache adapter <EntityName> [options]
```

### Positional Arguments

| Argument | Required | Type | Description |
|----------|----------|------|-------------|
| `EntityName` | Yes | `String` | Name of the entity or enum to generate adapters for (e.g., `Product`, `ParserType`) |

### Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--build` | `bool` | `false` | Run `zfa build` (build_runner) after updating the registrar |
| `--dry-run` | `bool` | `false` | Preview changes without writing files |
| `--force`, `-f` | `bool` | `false` | Overwrite existing files |
| `--verbose`, `-v` | `bool` | `false` | Enable detailed logging |
| `--output`, `-o` | `String` | `lib/src` | Output directory (fixed to `lib/src` in v5) |
| `--revert` | `bool` | `false` | Revert generated changes (delete adapter registrations) |

## Behaviour

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success — adapters registered and (if `--build`) build completed |
| `1` | Error — entity not found, file system error, etc. |

### Output Messages

**Success (no --build)**:
```
✅ Success! Created/Modified:
  ✨ lib/src/cache/hive_registrar.dart
⏭ Run 'zfa build' to generate adapter source files
```

**Success (with --build)**:
```
✅ Success! Adapters registered for:
  - Product
  - Category
  - Variant
✅ Build completed successfully
```

**Entity not found**:
```
❌ Error: Entity 'NonExistent' not found.
Available entities:
  - Product
  - Category
  - ParserType
  - ...
```

**No sub-entities found**:
```
✅ Success! Created/Modified:
  ✨ lib/src/cache/hive_registrar.dart
Adapter registered for: Product (no sub-entities needed)
```

**Duplicate run**:
```
✅ Success! (No changes required)
```

## Integration with Other Commands

### `zfa cache create`
- `zfa cache create EntityName` generates cache init files and initial registrar
- `zfa cache adapter EntityName` adds the entity to the existing registrar with sub-entity discovery
- These commands work independently but are complementary

### `zfa build`
- `zfa cache adapter EntityName --build` automatically runs `zfa build`
- Without `--build`, the user runs `zfa build` separately to trigger hive_generator

### `zfa entity create`
- Entities should be created with `zfa entity create` before using the adapter command
- The adapter command reads the entity file to discover field types and sub-entities

## Error Scenarios

| Scenario | Behaviour |
|----------|-----------|
| Entity name is empty | Error: "Missing required arguments: name" |
| Entity file not found | Error with list of available entities |
| File permission denied | Error with file path and suggested fix |
| Circular entity reference | Graceful handling — already-processed entities are skipped |
| Registrar file does not exist yet | Create registrar file with proper structure |
| build_runner fails (when --build) | Error with build_runner output + "registrar was updated" guidance |
