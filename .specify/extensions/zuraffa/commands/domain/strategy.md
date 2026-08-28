---
name: "speckit.zuraffa.strategy"
description: "Generate FetchStrategy abstract base, concrete variants, and StrategySelector"
category: "domain"
---

# Strategy Create: Generate FetchStrategy abstract base, concrete variants, and StrategySelector

## Usage

```bash
zfa strategy create
```

## When to Use

Generate FetchStrategy abstract base, concrete variants, and StrategySelector

## Required Parameters

- **name**: PascalCase name for the strategy domain (e.g. UrlListing)
- **strategies**: Comma-separated variant names (e.g. scraper,ai). Each becomes a concrete class.

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | PascalCase name for the strategy domain (e.g. UrlListing) |
| `--strategies` | string | Yes | - | Comma-separated variant names (e.g. scraper,ai). Each becomes a concrete class. |
| `--params` | string | No | - | Input type for FetchStrategy<Input, Output> (e.g. UrlSpark) |
| `--returns` | string | No | - | Output type for FetchStrategy<Input, Output> (e.g. Listing) |
| `--domain` | string | No | - | Provider domain folder (e.g. listing). Defaults to name snake_case. |
| `--dryRun` | bool | No | False | Run without writing files |
| `--force` | bool | No | False | Force overwrite existing files |
| `--verbose` | bool | No | False | Enable verbose logging |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
