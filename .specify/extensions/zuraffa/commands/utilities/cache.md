---
name: "speckit.zuraffa.cache"
description: "Generate caching logic"
category: "utilities"
---

# Cache: Generate caching logic

## Usage

```bash
zfa cache
```

## When to Use

Generate caching logic

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
