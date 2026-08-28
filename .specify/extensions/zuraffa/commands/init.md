---
name: "speckit.zuraffa.init"
description: "Set up a fresh Flutter project for Zuraffa code generation"
category: "setup"
---

# Init: Set up a fresh Flutter project for Zuraffa code generation

## Usage

```bash
zfa init
```

## When to Use

Set up a fresh Flutter project for Zuraffa code generation

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
