---
name: "speckit.zuraffa.datasource.private-method"
description: "Append private method to datasource"
category: "data"
---

# Private Method: Append private method to datasource

## Usage

```bash
zfa datasource private
```

## When to Use

Append private method to datasource

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
