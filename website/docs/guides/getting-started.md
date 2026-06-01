# Getting Started

This guide walks through the canonical Zuraffa v5 flow:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

---

## Installation

Add Zuraffa to your project and install the CLI:

```yaml
dev_dependencies:
  zuraffa: ^5.0.0
  zorphy_annotation: ^1.7.0
  build_runner: ^2.4.0
```

```bash
dart pub global activate zuraffa
```

Optional but recommended:

```bash
zfa config init
```

That creates `.zfa.json` for project defaults.

---

## Quick Start

### 1. Create an entity

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double \
  --field description:String?
```

### 2. Generate the feature architecture

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

## What was generated?

The command above typically produces:

- **Domain**: repository contract + use cases
- **Data**: datasource + repository implementation
- **Presentation**: view/presenter/controller/state
- **Infrastructure**: DI and test files

---

## `make` first, `feature` second

`zfa feature scaffold` still exists, but the v5 docs treat it as a wrapper over `zfa make --preset=feature` rather than the primary workflow.

Prefer `make` in docs, automation, and AI prompts.

---

## `.zfa.json` and `.zfa/`

Use these as the project-memory surfaces:

- **`.zfa.json`**: active defaults such as plugin defaults and entity-first behavior
- **`.zfa/`**: canonical v5 memory for plans, runs, decisions, blueprints, manifests, and context

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

## Next steps

- [CLI Commands Reference](../cli/commands)
- [Entity Generation](../entities/intro)
- [Migration Guide: v4 → v5](./migration-v4-to-v5)
- [MCP Server](../features/mcp-server)
