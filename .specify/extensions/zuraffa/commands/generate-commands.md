---
name: "speckit.zuraffa.generate-commands"
description: "Regenerate all extension command files from zfa manifest"
category: "utilities"
---

# Generate Commands: Regenerate all extension command files from zfa manifest

## Usage

```bash
zfa generate-commands
```

## When to Use

Regenerate all extension command files from zfa manifest

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
