---
name: "speckit.zuraffa.repository.method"
description: "Append method to existing repository"
category: "data"
---

# Method: Append method to existing repository

## Usage

```bash
zfa repository method
```

## When to Use

Append method to existing repository

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
