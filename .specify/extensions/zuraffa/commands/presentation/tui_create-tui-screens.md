---
name: "speckit.zuraffa.tui.create-tui-screens"
description: "Generate list/detail TUI screens for an entity, wired to its existing use cases (FR-011, SC-005). Pure-Dart — no Flutter."
category: "presentation"
---

# TUI Create-TUI-Screens: Generate list/detail TUI screens for an entity, wired to its existing use cases (FR-011, SC-005). Pure-Dart — no Flutter.

## Usage

```bash
zfa tui create-tui-screens
```

## When to Use

Generate list/detail TUI screens for an entity, wired to its existing use cases (FR-011, SC-005). Pure-Dart — no Flutter.

## Required Parameters

- **name**: Entity name (e.g. Product)
- **fields**: Entity fields
- **useCases**: Use cases available for binding (get, getList)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | Yes | - | Entity name (e.g. Product) |
| `--fields` | list | Yes | - | Entity fields |
| `--useCases` | list | Yes | - | Use cases available for binding (get, getList) |
| `--repositoryName` | string | No | - | Repository class name (defaults to <Entity>Repository) |

## Output

Use `--format=json` for machine-readable output. Supports `--dry-run` to preview without writing files.
