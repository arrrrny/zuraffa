---
name: "speckit.zuraffa.sqlite"
description: "Create a SQLite data source adapter"
category: "data"
---

# Sqlite Create: Create a SQLite data source adapter

## Usage

```bash
zfa sqlite create
```

## When to Use

Create a SQLite data source adapter

## Required Parameters

- **name**: Name of the entity (e.g. Task)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | Name of the entity (e.g. Task) |
| `--methods` | list | No | - | DataSource methods to implement (get, getList, list, create, update, toggle, delete, watch, watchList, initialize) |
| `--dryRun` | bool | No | False | Run without writing files |
| `--force` | bool | No | False | Force overwrite existing files |
| `--verbose` | bool | No | False | Enable verbose logging |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
