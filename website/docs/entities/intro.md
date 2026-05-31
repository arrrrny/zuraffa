# Entity Generation

Zuraffa v5 treats entities as the starting point for architecture generation.

The canonical flow is:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

---

## Why Zorphy entities?

- predictable structure for humans and AI agents
- immutable, typed entities under a fixed domain root
- clean separation between entity definitions and generated support code
- a single entity file can drive the rest of the architecture via `zfa make`

---

## Quick Start

### 1. Create an entity

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double \
  --field stock:int \
  --field description:String?
```

### 2. Generate architecture around it

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di
```

### 3. Finalize with `zfa build`

```bash
zfa build
```

---

## Entity location contract

Entity files belong at:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example:

```text
lib/src/domain/entities/product/product.dart
```

Do not hand-create entities in alternate locations when documenting v5 flows.

---

## The generated entity stack

```text
lib/src/domain/entities/product/
├── product.dart
├── product.zorphy.dart
└── product.g.dart
```

---

## AI workflow

Once the entity exists, the correct next instruction for an AI agent is:

> "Use `zfa make` to generate the CRUD architecture for this entity, then run `zfa build`."

That keeps prompts aligned with the v5 public contract.

---

## Next steps

- [Real-World Entity Examples](./examples)
- [Field Types Reference](./field-types)
- [CLI Commands Reference](../cli/commands)
