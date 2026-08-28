---
name: "speckit.zuraffa.repository"
description: "Generate repository interface and implementation"
category: "data"
---

# Repository: Generate repository interface and implementation

## Usage

```bash
zfa repository
```

## When to Use

Generate repository interface and implementation

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
