---
name: "speckit.zuraffa.gql.generate"
description: "Generate internal GQL query/mutation strings"
category: "graphql"
---

# Gql Generate: Generate internal GQL query/mutation strings

## Usage

```bash
zfa gql generate
```

## When to Use

Generate internal GQL query/mutation strings

## Required Parameters

- **name**: Name of the entity (e.g. Product)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | Name of the entity (e.g. Product) |
| `--type` | string | No | query | GraphQL operation type (query, mutation) |
| `--returns` | string | No | - | GraphQL return fields |
| `--dry-run` | bool | No | False | Run without writing files |
| `--force` | bool | No | False | Force overwrite existing files |
| `--verbose` | bool | No | False | Enable verbose logging |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
