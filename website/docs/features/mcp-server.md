# MCP Server

Zuraffa exposes a built-in Model Context Protocol (MCP) server so AI agents can understand your architecture and drive the same canonical v5 workflow that humans use.

That workflow is:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

---

## What MCP gives you

With the MCP server enabled, an agent can:

- inspect the project structure
- plan generation work before executing it
- create entities and then generate architecture around them
- run diagnostics and follow the same v5 command contract as the docs

---

## Installation

```bash
dart pub global activate zuraffa
zuraffa_mcp_server
```

---

## Available tools

### `zuraffa_setup`

Onboarding helper: adds `zuraffa`, `zorphy_annotation`, and `dev:build_runner`
to the current project's `pubspec.yaml` via `dart pub add`. Use it when other
tools report that the zfa CLI cannot be found — the MCP server needs zuraffa
in the project (or a global activation) before it can execute commands.
Supports `dry_run` to preview the changes.

### `zuraffa_make`

This tool should follow the same v5 contract as the CLI docs:

- create entities with `zfa entity create` when needed
- generate architecture through `zfa make`
- treat `zfa feature scaffold` as wrapper syntax, not the primary public workflow
- finish with `zfa build` when generation changes require it

### `zuraffa_entity_create`

Use this for Zorphy entity creation under the fixed v5 entity path:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

---

## `.zfa.json` and `.zfa/` context for agents

Agents should reason about project state using:

- **`.zfa.json`** for active project defaults
- **`.zfa/`** for the canonical project-memory model of plans, runs, decisions, blueprints, manifests, and context

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

During the migration period, some internals may still reference older storage paths. Public-facing v5 prompts and docs should still describe `.zfa/` as the forward contract.

---

## Next steps

- [Getting Started](../guides/getting-started)
- [CLI Commands Reference](../cli/commands)
- [Migration Guide: v4 → v5](../guides/migration-v4-to-v5)
