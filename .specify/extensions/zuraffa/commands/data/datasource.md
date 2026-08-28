---
name: "speckit.zuraffa.datasource"
description: "Generate data source for entity"
category: "data"
---

# Datasource: Generate data source for entity

## Usage

```bash
zfa datasource
```

## When to Use

Generate data source for entity

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
