# 🦒 Welcome to Zuraffa

**The AI-first Clean Architecture framework for Flutter.**

Zuraffa v5 teaches one canonical generation workflow:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

`zfa make` is the primary generator. `zfa feature scaffold` still exists, but only as a wrapper over the feature preset.

---

## Why Zuraffa?

- **AI-native structure** that is easy for humans and agents to navigate.
- **Clean Architecture defaults** across domain, data, presentation, and DI.
- **Zorphy-first entities** with a fixed domain layout.
- **Deterministic planning** via presets, aliases, and normalized execution plans.
- **Project memory surfaces** through `.zfa.json` defaults and the canonical `.zfa/` model.

### Pipeline-first rule for agents

When an agent is asked to build a feature, it should go through the Zuraffa pipeline:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

That pipeline establishes the architecture skeleton first. Only then should the agent fill in narrow implementation details like datasource logic, styling, shell composition, or other hand-authored business behavior.

---

## Quick Start

### 1. Define an entity

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double
```

### 2. Generate architecture with `make`

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di \
  --test
```

### 3. Build generated code

```bash
zfa build
```

---

## Fixed v5 assumptions

Zuraffa v5 assumes:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example:

```text
lib/src/domain/entities/product/product.dart
```

It also assumes a fixed domain root of `lib/src/domain` and Zorphy-based entities on public v5 surfaces.

---

## `.zfa.json` and `.zfa/`

- **`.zfa.json`** stores project defaults.
- **`.zfa/`** is the canonical v5 project-memory model for plans, runs, decisions, blueprints, manifests, and agent context.

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

During the migration period, some internals may still reference older storage paths. Public-facing v5 docs should still point to `.zfa/` as the forward contract.

---

## Where to go next

- [Getting Started](./guides/getting-started)
- [CLI Commands Reference](./cli/commands)
- [Entity Generation](./entities/intro)
- [Migration Guide: v4 → v5](./guides/migration-v4-to-v5)
- [MCP Server](./features/mcp-server)
- [Adaptive Layouts](./features/adaptive-layouts)
