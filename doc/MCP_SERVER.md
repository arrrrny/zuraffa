# Zuraffa MCP Server Reference

The Zuraffa MCP server exposes the same canonical v5 workflow that humans use.

That workflow is:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

The MCP server exists so AI agents can drive that exact pipeline with structured inputs instead of inventing architecture files by hand.

---

## Core MCP tools

### `zuraffa_make`

The canonical AI generation tool for v5.

Use this when an agent needs to generate or evolve the architecture skeleton around an entity or feature.

Typical responsibilities:

- generate CRUD/domain/data/presentation layers
- apply presets and plugin selections
- follow project defaults from `.zfa.json`
- participate in `.zfa/` memory persistence

### `zuraffa_entity_create`

Use this when an entity does not exist yet.

Target path contract:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

### `zuraffa_build`

Use this after entity/generation changes when build outputs must be finalized.

---

## Agent contract

When an AI agent is asked to implement a feature, it should:

1. inspect the project and existing entities
2. create any missing entity with `zuraffa_entity_create`
3. generate architecture with `zuraffa_make`
4. finalize generated outputs with `zuraffa_build`
5. only then fill in narrow implementation details by hand

This keeps Zuraffa responsible for the architecture skeleton and keeps human/agent edits focused on the parts generation does not own.

---

## `.zfa.json` and `.zfa/`

Agents should reason about project state using:

- **`.zfa.json`** for active project defaults
- **`.zfa/`** for plans, runs, blueprints, decisions, manifests, and context

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

---

## Guidance

- prefer `zuraffa_make`, not legacy generation surfaces
- prefer explicit project generation through Zuraffa over manual architecture scaffolding
- treat `zfa feature` as a wrapper, not the canonical workflow
- keep hand-authored work focused on implementation details after the skeleton exists
