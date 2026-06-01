---
name: zuraffa-cli
description: Use when generating or evolving architecture code in Zuraffa v5 projects. The canonical workflow is `zfa entity create` -> `zfa make` -> `zfa build`. Treat `zfa feature` as a wrapper over the feature preset and never use the removed legacy one-shot generator.
---

# Zuraffa CLI (v5) Skill

## Use this skill when

- creating or updating Zorphy entities
- generating CRUD architecture around an entity
- adding data, VPC, DI, test, cache, mock, route, gql, or graphql layers
- generating a custom use case or orchestrator
- guiding another agent or user through the current v5 workflow

## The canonical workflow

Always prefer this sequence:

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double

zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di \
  --test

zfa build
```

## Golden rules

1. **Use `zfa make` as the primary generator.**
2. **Use `zfa entity create` for entities.** Never hand-create them.
3. **Use `zfa build` after generation.** Do not teach `build_runner` directly as the normal workflow.
4. **Treat `zfa feature scaffold` as a wrapper**, not the canonical command.
5. **Assume the domain root is fixed to `lib/src/domain`.**
6. **Assume entities are Zorphy-first on public v5 surfaces.**

## Fixed paths and assumptions

Entity files belong at:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example:

```text
lib/src/domain/entities/product/product.dart
```

## Recommended `make` patterns

### CRUD slice

```bash
zfa make Product --preset=crud --methods=get,getList,create,update,delete
```

### CRUD + UI + tests

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --test
```

### Add DI, cache, and mocks

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList \
  --cache \
  --di \
  --mock \
  --use-mock
```

### Custom use case

```bash
zfa make SearchProducts usecase \
  --domain=search \
  --params=SearchQuery \
  --returns=List<Product>
```

### Inspect the plan before writing files

```bash
zfa make Product --preset=crud --with=vpc --plan --format=json
```

## `feature` wrapper rule

If you see or receive `zfa feature scaffold`, interpret it as wrapper syntax for the feature preset.

Equivalent intent:

```bash
zfa make Product --preset=feature --plan
```

```bash
zfa feature scaffold Product --plan
```

Use the `make` form in docs, examples, and AI prompts unless wrapper syntax is explicitly requested.

## Manual UI zones

Use Zuraffa for generated architecture ownership:

- entities
- repositories
- datasources
- usecases
- presenter/controller/state scaffolding
- DI/test/mock/cache/route/graphql support

Handcraft only the manual UI and composition areas that are intentionally outside generator ownership.

## `.zfa.json` and `.zfa/`

Use these mental models when reasoning about project state:

- **`.zfa.json`** = active defaults for this project
- **`.zfa/`** = canonical v5 project memory for plans, runs, decisions, blueprints, manifests, and context

Canonical memory layout:

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

During migration, some internals may still reference older paths. Public-facing guidance should still describe `.zfa/` as the forward contract.

## Short migration message to give users

> In Zuraffa v5, create the entity first, generate architecture with `zfa make`, and finish with `zfa build`. `zfa feature` is only a wrapper over the feature preset.
