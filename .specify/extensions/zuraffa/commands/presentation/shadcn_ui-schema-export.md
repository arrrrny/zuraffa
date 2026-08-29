---
name: "speckit.zuraffa.shadcn.ui.schema.export"
description: "Export the shadcn plugin UI component vocabulary as a versioned, diff-stable JSON Schema (components, props, enums, children constraints, structural rules, style tokens, action-ID grammar)."
category: "presentation"
---

# Shadcn UI-Schema-Export: Export the shadcn plugin UI component vocabulary as a versioned, diff-stable JSON Schema (components, props, enums, children constraints, structural rules, style tokens, action-ID grammar).

## Usage

```bash
zfa shadcn ui.schema.export
```

## When to Use

Export the full UI component vocabulary as a machine-readable JSON Schema so agents, CI pipelines, and prompt authors can discover which components, props, tokens, and structural constraints are available. The export is versioned (`schemaVersion`), diff-stable across consecutive runs, and consumable as-is as the agent `ui.render` tool input schema (spec 024 SC-004).

## Required Parameters

- **projectRoot**: Project root to load composites from (defaults to the current directory)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--project-root` | string | No | current directory | Project root for composite loading |
| `--schema-version` | string | No | plugin version | Version stamp for the export |

## Examples

```bash
# Export the vocabulary including project composites
zfa shadcn ui.schema.export --project-root=.

# CI pin check — fails when the version drifts
zfa ui schema --expect-version=1.0.0
```

## Output

A JSON object printed to stdout (or written via `--out`):

- `schemaVersion` — semver vocabulary version
- `components` — per-component definitions (props, enums, children constraints)
- `structuralRules` — `maxDepth` / `maxNodes` tree caps
- `styleTokens` — the canonical style token enum
- `actionIdGrammar` — the action-ID pattern + description
- `nestingRules` — per-parent allowed child types

## Notes

- Project composites scaffolded via `zfa make <Name> --ui` appear alongside built-in components.
- Validate payloads against the same vocabulary with `zfa ui validate <file>`.
- The export is registered as an MCP-discoverable capability (`ui.schema.export`) on the shadcn plugin.
