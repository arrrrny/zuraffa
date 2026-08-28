---
name: "speckit.zuraffa.datasource.inject"
description: "Inject dependency into datasource"
category: "data"
---

# Inject: Inject dependency into datasource

## Usage

```bash
zfa datasource inject
```

## When to Use

Inject dependency into datasource

## Required Parameters

- **name**: Name of the target (e.g. Product)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | No | - | Name of the target (e.g. Product) |
| `--force` | bool | No | False | Force overwrite existing files |
| `--dry-run` | bool | No | False | Preview without writing files |
| `--verbose` | bool | No | False | Enable verbose logging |

## Output

Supports `--dry-run` to preview without writing files.
