---
name: "speckit.zuraffa.benchmark.run"
description: "Execute the registered benchmark scenarios and apply their metric thresholds (FR-004)."
category: "benchmark"
---

# Benchmark Run: Execute the registered benchmark scenarios and apply their metric thresholds (FR-004).

## Usage

```bash
zfa benchmark run
zfa benchmark run --scenario MYID --tags a,b --json
zfa benchmark run --isolate --concurrency 4 --store benchmarks/baselines
```

## When to Use

Use this as the quality gate that runs every registered scenario, collects metrics
via the plugin runner, and fails the run when any threshold is violated (FR-004,
FR-007). Pair it with `zfa benchmark baseline` to compare against a saved baseline.

## Required Parameters

- None.

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--scenario` | string (repeatable) | No | - | Run only the named scenario(s). |
| `--tags` | string | No | - | Run only scenarios carrying any of the comma-separated tags. |
| `--dry-run` | bool | No | False | Validate configuration without executing scenarios. |
| `--config` | string | No | - | Global config JSON merged into every scenario. |
| `--json` | bool | No | False | Emit machine-readable JSON instead of the human-readable report. |
| `--timeout` | int (ms) | No | - | Per-scenario timeout in milliseconds. |
| `--isolate` | bool | No | False | Run each scenario in its own isolate (FR-007). |
| `--concurrency` | int | No | 1 | Worker-pool size for the suite run. |
| `--store` | string | No | benchmarks/baselines | Baseline store directory for reports. |

## Output

A suite report listing each scenario's status and metrics, plus the overall verdict.
Exit code is 0 when all thresholds pass, 1 on regression/failure, and 64 on usage
errors.
