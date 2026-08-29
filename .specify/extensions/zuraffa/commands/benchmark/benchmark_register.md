---
name: "speckit.zuraffa.benchmark.register"
description: "Register benchmark scenarios from the project's scenario providers into the plugin registry."
category: "benchmark"
---

# Benchmark Register: Register benchmark scenarios from the project's scenario providers into the plugin registry.

## Usage

```bash
zfa benchmark register
```

## When to Use

Use this to discover and register all benchmark scenarios declared by scenario
providers before a `zfa benchmark run` (FR-004). Registration is implicit in `run`
and `list`, but this capability makes the registration step explicit for agents and
tooling.

## Required Parameters

- None.

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--store` | string | No | benchmarks/baselines | Baseline store directory used to resolve registered scenarios. |

## Output

Reports the number of scenarios registered. Exits non-zero if discovery or
registration fails.
