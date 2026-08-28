---
name: "speckit.zuraffa.cache.adapter"
description: "Register Hive adapters for an entity and its sub-entities"
category: "utilities"
---

# Cache Adapter: Register Hive adapters for an entity and its sub-entities

## Usage

```bash
zfa cache adapter
```

## When to Use

Register Hive adapters for an entity and its sub-entities

## Required Parameters

- **name**: Name of the entity or enum (e.g. Product, ParserType)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | Name of the entity or enum (e.g. Product, ParserType) |
| `--build` | bool | No | False | Run zfa build after updating registrar |
| `--dryRun` | bool | No | False | Preview changes without writing files |
| `--force` | bool | No | False | Force overwrite existing files |
| `--verbose` | bool | No | False | Enable detailed logging |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
