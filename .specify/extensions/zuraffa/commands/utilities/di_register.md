---
name: "speckit.zuraffa.di.register"
description: "Register existing class in DI"
category: "utilities"
---

# Register: Register existing class in DI

## Usage

```bash
zfa di register
```

## When to Use

Register existing class in DI

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
