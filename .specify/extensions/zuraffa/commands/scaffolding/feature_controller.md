---
name: "speckit.zuraffa.feature.controller"
description: "Add controller to existing feature"
category: "scaffolding"
---

# Controller: Add controller to existing feature

## Usage

```bash
zfa feature controller
```

## When to Use

Add controller to existing feature

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
