---
name: "speckit.zuraffa.provider.inject"
description: "Inject dependency into provider"
category: "domain"
---

# Inject: Inject dependency into provider

## Usage

```bash
zfa provider inject
```

## When to Use

Inject dependency into provider

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
