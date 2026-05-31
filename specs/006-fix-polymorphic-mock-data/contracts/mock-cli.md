# CLI Interface Contract: `zfa mock data`

**Feature**: 006-fix-polymorphic-mock-data
**Type**: CLI command interface

## Command Signature

```bash
zfa mock data <EntityName> [options]
```

## Input

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| `<EntityName>` | Yes | String | PascalCase name of the entity (e.g., `CategoryConfig`) |
| `--force` | No | Flag | Overwrite existing mock data files |
| `--output` | No | Path | Output directory (default: `lib/src`) |
| `--verbose` | No | Flag | Verbose output with progress messages |

## Output Contract

### Success — Polymorphic Entity (Sealed Class)

When `<EntityName>` is a sealed class with concrete subtypes:

1. **stdout**: Progress messages for each subtype mock file generated
2. **Generated files**:
   - One mock data file per concrete subtype (e.g., `primary_category_mock_data.dart`)
   - Each file contains a `{Subtype}MockData` class with static `sample{Subtype}` and `{camelSubtype}s` list
   - The sealed base class does NOT receive a mock data file
3. **Exit code**: 0

### Success — Polymorphic Entity (@Zorphy)

When `<EntityName>` uses `@Zorphy(explicitSubTypes: [...])`:

1. **stdout**: Same as above
2. **Generated files**: Same structure as above
3. **Exit code**: 0
4. **Contract**: Behavior unchanged from before the fix

### Success — Non-Polymorphic Entity

When `<EntityName>` is a standard (non-sealed, non-Zorphy) class:

1. **stdout**: Single mock data file generated
2. **Generated file**: `{entity_snake}_mock_data.dart` with `{Entity}MockData` class
3. **Exit code**: 0

### Warning — Sealed Class with No Concrete Subtypes

When `<EntityName>` is a sealed class but all subtypes are abstract:

1. **stdout**: Warning message: "No concrete subtypes found for sealed class {EntityName}. Mock data generation skipped."
2. **Generated files**: None for this entity
3. **Exit code**: 0 (warning, not error)

### Error — Entity Not Found

When `<EntityName>` file does not exist and subtype detection fails:

1. **stderr**: Error message: "Entity file for '{EntityName}' not found"
2. **Exit code**: 1
3. **Timeout**: Must exit within 5 seconds

### Error — Unresolvable Nested Type

When a field references an entity type that cannot be analyzed:

1. **stderr**: Warning: "Could not resolve entity type '{TypeName}' referenced by field '{FieldName}'"
2. **Generation continues** for remaining entities
3. **Exit code**: 0 (partial generation with warnings)

## Invariants

1. Generated mock data MUST NOT contain direct instantiation of `sealed` or `abstract` classes
2. Generated mock data MUST produce valid, compilable Dart code
3. The `@Zorphy` annotation path MUST continue to work identically
4. The process MUST NOT hang — all paths must return within 10 seconds for ≤10 subtypes
5. Existing CLI flags (`--force`, `--output`) remain unchanged in behavior

## Backward Compatibility

- **Breaking**: None. This is a bug fix that adds sealed class support without changing existing behavior.
- **Behavior change**: Previously, running `zfa mock data CategoryConfig` on a sealed class would hang or produce invalid code. Now it correctly generates subtype mock data.
