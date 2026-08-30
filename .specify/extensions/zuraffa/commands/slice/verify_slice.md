---
name: "speckit.zuraffa.slice.verify_slice"
description: "Check a slice's imports resolve (optionally run dart analyze) before handing it to an agent."
category: "slice"
---

# Slice Verify: Check a slice's imports resolve

## Usage

```bash
zfa slice verify <name> [--analyze]
```

## When to Use

Use this to confirm a cut slice is self-contained and runnable before delegating
it to an agent (or before `slice run`/`slice export`, which verify first). The
command fails fast on any import that escapes the slice sandbox or is missing.

## Required Parameters

- `<name>` — the slice name (matches the sandbox under `.zuraffa/slices/<name>/`).

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--analyze` | bool | No | False | Also run `dart analyze` on the sandbox and report errors. |

## Output

`OK: slice "<name>" is ready for an agent.` on success, or a list of unresolved
imports (file:line, the import path, and the reason). Exits non-zero when the
slice is not ready.
