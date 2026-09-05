---
name: "speckit.zuraffa.di"
description: "Generate and verify dependency injection registrations"
category: "utilities"
---

# Di: Generate and verify dependency injection registrations

## Usage

```bash
zfa di create <Name>       # entity/usecase registrations (auto-wires methods)
zfa di register <ClassName> # register an existing class (domain auto-detected)
zfa di verify              # gate: dangling getIt<T>() bindings fail with a fix hint
```

The positional grammar `zfa di <Name>` was removed (#856) — only the
subcommand grammar above is live.

## When to Use

- Generate DI registrations for an entity or usecase (`create`)
- Wire an already-written class into the DI index (`register`)
- Verify every generated registration resolves against classes on disk
  (`verify`) — the #284/#410 dangling-binding failure, made a gate

## Required Parameters

- **create**: name of the target (e.g. Product) — positional or `--name`
- **register**: name of the class (e.g. CategoryProvider) — positional or `--target`
- **verify**: none (scans `lib/src/di/**`)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--domain` | string | No | - | Domain name for the usecase/entity |
| `--service` | string | No | - | Service name for custom usecases |
| `--repo` | string | No | - | Repository name for custom usecases |
| `--methods` | list | No | get,update | Entity methods to wire |
| `--usecases` | list | No | - | Usecases to orchestrate |
| `--no-entity` | bool | No | False | Custom (non-entity) usecase |
| `--use-mock` | bool | No | False | Mock implementations for datasources |
| `--force` | bool | No | False | Force overwrite existing files |
| `--dry-run` | bool | No | False | Preview without writing files |
| `--verbose` | bool | No | False | Enable verbose logging |
| `--revert` | bool | No | False | Revert generated files |

## Output

Supports `--dry-run` to preview without writing files. `create` and
`register` append a `proof.v1` receipt under `.zfa/receipts/` (spec 0974)
so `zfa proof check` covers standalone runs; `verify` exits 1 with a
`--> fix:` hint when a binding is dangling.
