---
name: "speckit.zuraffa.mock"
description: "Generate mock data and mock datasource"
category: "testing"
---

# Mock: Generate mock data and mock datasource

## Usage

```bash
zfa mock
```

## When to Use

Generate mock data and mock datasource

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
