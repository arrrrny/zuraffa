---
name: "speckit.zuraffa.provider.private-method"
description: "Append private method to provider"
category: "domain"
---

# Private Method: Append private method to provider

## Usage

```bash
zfa provider private
```

## When to Use

Append private method to provider

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
