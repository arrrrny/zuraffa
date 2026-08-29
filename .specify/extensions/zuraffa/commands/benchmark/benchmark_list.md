---
name: "speckit.zuraffa.benchmark.list"
description: "List the benchmark scenarios currently registered in the plugin registry."
category: "benchmark"
---

# Benchmark List: List the benchmark scenarios currently registered in the plugin registry.

## Usage

```bash
zfa benchmark list
zfa benchmark list --json
```

## When to Use

Use this when you need to discover which benchmark scenarios are available before
running or baselining them (FR-002). It reports each scenario's id, name, version,
description, and tags.

## Required Parameters

- None.

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--json` | bool | No | False | Emit machine-readable JSON instead of the human-readable table. |

## Output

A table of registered scenarios (or a JSON array with `--json`). Exits non-zero if
the registry cannot be loaded.
