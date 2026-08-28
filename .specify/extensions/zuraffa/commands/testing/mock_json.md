---
name: "speckit.zuraffa.mock.json"
description: "Generate JSON mock data with fromJson-based Dart helpers"
category: "testing"
---

# Mock JSON: Generate JSON mock data with fromJson-based Dart helpers

## Usage

```bash
zfa mock json
```

## When to Use

Generate JSON mock data with fromJson-based Dart helpers

## Required Parameters

- **name**: Entity name to generate JSON mock data for

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | Entity name to generate JSON mock data for |
| `--domain` | string | No | - | Domain folder for grouping JSON files |
| `--outputDir` | string | No | lib/src | Output directory for generated files |
| `--force` | bool | No | False | Force overwrite existing JSON files |
| `--dryRun` | bool | No | False | Preview without writing files |
| `--verbose` | bool | No | False | Enable verbose logging |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
