# ZFA CLI Guide

Zuraffa v5 has one canonical generation workflow:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

This guide focuses on the current public surface. `zfa make` is the primary generator, while `zfa feature` is a wrapper over the normalized feature preset.

---

## Installation

```bash
flutter pub add zuraffa
dart pub global activate zuraffa
zfa --help
```

If you want project defaults, initialize config once:

```bash
zfa config init
```

That creates `.zfa.json` in your project root.

---

## Quick start

### 1. Create the entity

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double \
  --field description:String?
```

### 2. Generate the architecture with `make`

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

## The v5 command model

| Command                | Purpose                                        |
| ---------------------- | ---------------------------------------------- |
| `zfa entity create`    | Create or evolve Zorphy entities               |
| `zfa make`             | Canonical architecture/code generation command |
| `zfa feature scaffold` | Wrapper over `zfa make --preset=feature`       |
| `zfa build`            | Run the codegen/build step                     |
| `zfa config`           | Manage `.zfa.json` defaults                    |
| `zfa manifest`         | Inspect available capabilities                 |
| `zfa apply`            | Execute a previously generated plan            |
| `zfa doctor`           | Inspect tooling and environment health         |

---

## `zfa entity create`

Use `entity create` for domain entities. In v5, entity output is fixed to:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

### Examples

```bash
zfa entity create -n Order \
  --field id:String \
  --field total:double \
  --field createdAt:DateTime
```

```bash
zfa entity enum -n OrderStatus --value pending,paid,shipped
```

```bash
zfa entity add-field -n Product --field stock:int
```

### Important v5 rules

- Entities are **Zorphy-first** on public docs/config surfaces.
- The domain root is fixed to `lib/src/domain`.
- Legacy `--output` values are accepted by some commands for compatibility but are not the public v5 contract.

---

## `zfa make`

`make` resolves a normalized plan before generation. You can drive it with:

- a **preset** such as `crud` or `feature`,
- explicit plugin IDs like `usecase`, `repository`, `datasource`, `view`, `presenter`, `controller`, `state`,
- aliases such as `vpc`, and
- additive/subtractive controls via `--with` and `--without`.

### Syntax

```bash
zfa make <Name> <plugin1> <plugin2> ... [options]
```

### Preset-first usage

```bash
zfa make Product --preset=crud --methods=get,getList,create,update,delete
```

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di \
  --test
```

### Explicit plugin usage

```bash
zfa make Product usecase repository datasource view presenter controller state di test \
  --methods=get,getList,create,update,delete
```

### Common add-ons

Caching:

```bash
zfa make Product --preset=crud --methods=get,getList --cache
```

Mocks + DI:

```bash
zfa make Product --preset=crud --mock --di --use-mock --methods=get,getList
```

GraphQL:

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create \
  --gql \
  --graphql
```

Custom use case:

```bash
zfa make SearchProducts usecase \
  --domain=search \
  --params=SearchQuery \
  --returns=List<Product>
```

---

## Planning and machine-readable output

One of the most useful v5 capabilities is plan inspection.

### Show the normalized plan

```bash
zfa make Product --preset=crud --with=vpc --plan
```

### Explain why the plan resolved that way

```bash
zfa make Product --preset=crud --with=vpc --explain
```

### Get JSON output

```bash
zfa make Product --preset=crud --with=vpc --plan --format=json
```

### Read input from JSON

```json
{
  "name": "Product",
  "preset": "crud",
  "with": ["vpc"],
  "methods": ["get", "getList", "create", "update", "delete"]
}
```

```bash
zfa make --from-json make_config.json --plan --format=json
```

### Read input from stdin

```bash
cat make_config.json | zfa make --from-stdin --plan --format=json
```

---

## `zfa feature scaffold` is a wrapper

`feature scaffold` still exists for convenience, but the public v5 docs treat it as a preset wrapper rather than the primary workflow.

These are equivalent in intent:

```bash
zfa make Product --preset=feature --plan
```

```bash
zfa feature scaffold Product --plan
```

Use `feature scaffold` only when you want the wrapper semantics. Prefer `make` when teaching, scripting, or guiding AI agents.

---

## `zfa build`

Use `zfa build` instead of calling `build_runner` directly in v5 docs.

```bash
zfa build
zfa build --watch
zfa build --clean
```

---

## `.zfa.json` and `.zfa/`

### `.zfa.json`

Project-level defaults live in `.zfa.json`.

Examples:

```bash
zfa config init
zfa config show
zfa config set diByDefault true
zfa config set entityFirst true
```

### `.zfa/`

The canonical v5 documentation model treats `.zfa/` as project memory for:

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

Use it as the mental model for how future agents resume work:

- `.zfa.json` tells them the defaults.
- `.zfa/` tells them what has already been planned, generated, or decided.

During the migration to full v5 persistence, some internals may still reference older storage paths. Public docs should still point forward to `.zfa/`.

---

## Migration summary

If you used older Zuraffa docs, update your habits to:

- create entities with `zfa entity create`,
- generate architecture with `zfa make`,
- treat `zfa feature` as a wrapper, and
- finish with `zfa build`.

Also assume:

- fixed domain root: `lib/src/domain`
- fixed entity root: `lib/src/domain/entities`
- Zorphy-first entities on public v5 surfaces

See `doc/MIGRATION_GUIDE.md` for the v4 → v5 migration details.

---

## Recommended agent workflow

When acting as a coding agent in a Zuraffa project:

1. Inspect or create the entity.
2. Use `zfa make` with `--plan` first if the shape is unclear.
3. Execute the generation command.
4. Run `zfa build`.
5. Hand-edit only manual UI composition or business implementation details outside generated ownership.

---

## Examples recap

```bash
# CRUD domain/data only
zfa make Product --preset=crud --methods=get,getList,create,update,delete

# CRUD + presentation + DI + tests
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di \
  --test

# Add watch logic to an existing feature
zfa make Product presenter controller state --methods=watch --force

# Feature wrapper when you explicitly want the preset alias
zfa feature scaffold Product --plan

# Build after generation
zfa build
```
