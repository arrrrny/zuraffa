---
name: "speckit.zuraffa.slice.merge_slice"
description: "Merge agent changes from a slice back into the project (shared-file writes need confirmation)."
category: "slice"
---

# Slice Merge: Merge agent changes from a slice back into the project

## Usage

```bash
zfa slice merge <name> [--yes] [--verbose]
```

## When to Use

Use this after an agent has edited a slice (cut with `zfa slice cut`). It copies
the agent's changes back into the project, creating new files, overwriting owned
files, and deleting files the agent removed — then reports conflicts and any
shared-file writes that need confirmation.

## Required Parameters

- `<name>` — the slice name (matches the sandbox under `.zuraffa/slices/<name>/`).

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--yes` | bool | No | False | Confirm shared-file overwrites/deletes without prompting. |
| `--verbose` | bool | No | False | Print per-file merge decisions. |

## Output

A merge report: list of `merged`, `created`, and `deleted` files, plus any
`conflict` or `shared change not confirmed` entries. A modified shared file warns
and blocks until confirmed (or `--yes`). Exits non-zero on incomplete merge.
