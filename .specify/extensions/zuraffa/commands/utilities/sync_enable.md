---
name: "speckit.zuraffa.sync.enable"
description: "Enable offline-first sync for an entity"
category: "utilities"
---

# Sync Enable: Enable offline-first sync for an entity

## Usage

```bash
zfa sync enable
```

## When to Use

Enable offline-first sync for an entity

## Required Parameters

- **name**: Name of the entity (e.g. Product)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | Name of the entity (e.g. Product) |
| `--direction` | string | No | push | Sync direction (push or bidirectional) |
| `--batchSize` | int | No | 50 | Number of records per sync batch |
| `--maxRetries` | int | No | 5 | Maximum sync retry attempts before failing |
| `--dryRun` | bool | No | False | Run without writing files |
| `--force` | bool | No | False | Force overwrite existing files |
| `--verbose` | bool | No | False | Enable verbose logging |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
