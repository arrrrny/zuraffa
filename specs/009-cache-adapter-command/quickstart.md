# Quickstart: Cache Adapter Command

**Feature**: Cache Adapter Command
**Date**: 2026-06-12

## Overview

The `zfa cache adapter` command automatically generates Hive type adapters for entities and all their sub-entities. It updates the Hive registrar file with the necessary imports, `@GenerateAdapters` annotations, and `registerAdapter()` calls.

## Prerequisites

- Zuraffa v5 project with the cache plugin installed
- Entity created using `zfa entity create`
- Cache files generated using `zfa make EntityName --preset=crud --cache` or `zfa cache create EntityName`

## Usage

### Basic Usage

Register adapters for an entity and all its sub-entities:

```bash
zfa cache adapter Product
```

This will:
1. Scan `Product` and discover all sub-entities (referenced entity types in its fields)
2. Recursively discover sub-entities of sub-entities
3. Update `lib/src/cache/hive_registrar.dart` with:
   - Import statements for each entity
   - `AdapterSpec<Entity>()` entries in `@GenerateAdapters`
   - `registerAdapter()` calls in both `HiveRegistrar` and `IsolatedHiveRegistrar` extensions

After running, execute `zfa build` to generate the actual adapter source files.

### Generate and Build in One Step

```bash
zfa cache adapter Product --build
```

This runs `zfa build` automatically after updating the registrar.

### Registering Enum Types

The same command works for enums:

```bash
zfa cache adapter ParserType
```

### Preview Changes Without Writing

```bash
zfa cache adapter Product --dry-run
```

### Force Overwrite

```bash
zfa cache adapter Product --force
```

## Workflow Integration

### Standard Zuraffa v5 Workflow

```bash
# 1. Create the entity
zfa entity create -n Product --field name:String --field price:double

# 2. Generate architecture
zfa make Product --preset=crud --cache

# 3. Register Hive adapters
zfa cache adapter Product --build

# Or step-by-step:
zfa cache adapter Product
zfa build
```

### Adding a New Entity to an Existing Project

```bash
zfa entity create -n Review --field rating:int --field comment:String
zfa cache adapter Review --build
```

## What Happens Behind the Scenes

1. **Entity Analysis**: The command reads the entity file (e.g., `lib/src/domain/entities/product/product.dart`) and parses its fields
2. **Sub-entity Discovery**: For each field type, it checks if the type is another entity in the project. If yes, it adds that entity to the adapter list and recursively checks its fields
3. **Circular Reference Detection**: Entities already processed are skipped to prevent infinite loops
4. **Registrar Regeneration**: The `hive_registrar.dart` file is regenerated from scratch with all discovered entities, ensuring existing registrations are preserved
5. **Build (optional)**: If `--build` is provided, `zfa build` runs to generate the adapter implementations

## Troubleshooting

### "Entity not found"

```bash
❌ Error: Entity 'NonExistent' not found.
```

Make sure you created the entity first with `zfa entity create` and that the entity file exists at `lib/src/domain/entities/{entity_snake}/{entity_snake}.dart`.

### "No changes required"

The registrar already includes all discovered entities. This means the entity and its sub-entities were already registered.

### build_runner fails

If `--build` fails, the registrar file is still updated. Run `zfa build` separately and check for errors in the build output.
