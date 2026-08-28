---
name: "speckit.zuraffa.graphql"
description: "Create GraphQL"
category: "graphql"
---

# Graphql Create: Create GraphQL

## Usage

```bash
zfa graphql create
```

## When to Use

Create GraphQL

## Required Parameters

- **name**: Name of the entity (e.g. Product)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | Name of the entity (e.g. Product) |
| `--type` | string | No | query | GraphQL operation type (query, mutation) |
| `--returns` | string | No | - | Return type |
| `--inputType` | string | No | - | Input type name |
| `--inputName` | string | No | - | Input variable name |
| `--opName` | string | No | - | Operation name |
| `--dryRun` | bool | No | False | Run without writing files |
| `--force` | bool | No | False | Force overwrite existing files |
| `--verbose` | bool | No | False | Enable verbose logging |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
