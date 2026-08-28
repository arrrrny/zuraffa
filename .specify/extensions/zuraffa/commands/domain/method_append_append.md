---
name: "speckit.zuraffa.method-append"
description: "Append method to repository or service"
category: "domain"
---

# Method Append: Append method to repository or service

## Usage

```bash
zfa method-append
```

## When to Use

Append method to repository or service

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
