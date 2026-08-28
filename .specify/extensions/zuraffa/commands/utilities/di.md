---
name: "speckit.zuraffa.di"
description: "Generate dependency injection registrations"
category: "utilities"
---

# Di: Generate dependency injection registrations

## Usage

```bash
zfa di
```

## When to Use

Generate dependency injection registrations

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
