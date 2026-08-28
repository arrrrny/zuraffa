---
name: "speckit.zuraffa.mock.inject"
description: "Inject dependency into mock"
category: "testing"
---

# Inject: Inject dependency into mock

## Usage

```bash
zfa mock inject
```

## When to Use

Inject dependency into mock

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
