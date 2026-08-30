---
name: "speckit.zuraffa.slice.cut_slice"
description: "Extract a runnable, self-contained slice of the project from one or more entry points."
category: "slice"
---

# Slice Cut: Extract a runnable, self-contained slice of the project

## Usage

```bash
zfa slice cut <name> --entry <page|path> [--depth view|presentation|feature|full] [--verify] [--verbose]
```

## When to Use

Use this to delegate work on one feature to an AI agent without handing over the
whole repository. The command traces the dependency graph from the entry point
(view, controller, presenter, usecases, entities, boundaries), mirrors the needed
files into an isolated sandbox under `.zuraffa/slices/<name>/`, generates mock DI
registrations for boundary interfaces, a runnable `main_slice.dart`, and a
`SLICE.md` agent instruction file (spec 043).

## Required Parameters

- `<name>` — the slice name (becomes the sandbox directory name).
- `--entry <point>` — entry point: a page name (e.g. `product`) or a file path;
  repeatable for multi-entry slices.

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--depth` | enum | No | `feature` | Extraction depth: `view`, `presentation`, `feature`, or `full`. |
| `--verify` | bool | No | False | Verify the slice after cutting; roll the sandbox back on failure. |
| `--verbose` | bool | No | False | Print per-file ownership and boundary diagnostics. |

## Output

A sandbox directory `.zuraffa/slices/<name>/` containing the mirrored files,
generated mocks and DI wiring, `main_slice.dart`, `SLICE.md`, and `slice.yaml`.
Exits non-zero (with usage text, never a stack trace) on invalid arguments or
when the entry point cannot be resolved.
