---
name: "speckit.zuraffa.gym"
description: "Create a Gym"
category: "tooling"
---

# Gym Create: Create a Gym

## Usage

```bash
zfa gym create
```

## When to Use

Create a Gym

## Required Parameters

- **name**: Name of the gym target (entity or feature)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | Name of the gym target (entity or feature) |
| `--domain` | string | No | general | Domain folder for the gym target |
| `--dryRun` | bool | No | False | Run without writing files |
| `--force` | bool | No | False | Force overwrite existing files |
| `--verbose` | bool | No | False | Enable verbose logging |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
