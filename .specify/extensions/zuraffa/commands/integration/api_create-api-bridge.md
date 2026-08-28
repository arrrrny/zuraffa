---
name: "speckit.zuraffa.api.create-api-bridge"
description: "Generate VM Service extension bridge for a Zuraffa entity"
category: "integration"
---

# API Create-API-Bridge: Generate VM Service extension bridge for a Zuraffa entity

## Usage

```bash
zfa api create-api-bridge
```

## When to Use

Generate VM Service extension bridge for a Zuraffa entity

## Required Parameters

- **name**: Entity name (PascalCase), e.g. Product

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | Entity name (PascalCase), e.g. Product |
| `--domain` | string | No | - | Override domain name segment in extension methods (defaults to snake_case of name) |
| `--dryRun` | bool | No | False | Preview without writing files |
| `--force` | bool | No | False | Overwrite existing files |
| `--verbose` | bool | No | False | Enable detailed logging |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
