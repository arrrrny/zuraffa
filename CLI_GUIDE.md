# ZFA CLI Guide

Zuraffa v5 has one canonical generation workflow:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

This guide focuses on the current public surface. `zfa make` is the primary generator, while `zfa feature` is a wrapper over the normalized feature preset.

---

## Scope: what `zfa` operates on

`zfa` is a clean-architecture generator for **Zuraffa apps** — Dart/Flutter
packages whose `pubspec.yaml` depends on `zuraffa` and `zorphy_annotation`
and whose project defaults live in `.zfa.json`. It scaffolds entities,
controllers, repositories, data sources, and DI wiring inside that contract.

`zfa` does not rewrite existing non-Zuraffa Flutter packages or plugins.
Running `zfa` inside a plugin such as a WebView bridge is out of scope: `zfa
doctor` will report `No .zfa.json found`, `Zuraffa package not found`, and
`zorphy_annotation not found`. That is the expected scope
check, not a malfunction of the CLI. For a non-Zuraffa package you have
three options: keep the code hand-written, add the Zuraffa dependencies to
opt the package into the generator, or file a feature request if `zfa`
should support rewriting non-Zuraffa Flutter packages (for example
generating platform-interface stubs) — that support does not exist today.

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

### Forward references & cyclic entity graphs (`--allow-forward-refs`)

By default, `entity create` and `entity add-field` validate that every
non-primitive field type resolves to either an existing entity directory or
an existing enum file on disk (added by #296 — prevents silently writing
`$InvalidType` placeholders). This guard rejects forward references to
entities that have not been generated yet.

Real-world GraphQL schemas (Vendure, Shopify, etc.) often contain genuine
mutual-reference cycles — `Order ↔ Customer`, `Facet ↔ FacetValue`,
`Fulfillment ↔ FulfillmentLine` — so a schema-driven batch cannot satisfy
"every referenced entity must already exist" in any ordering.

Pass `--allow-forward-refs` to opt out of the on-disk check for a single
invocation. The `ImportResolver` already emits correct `$`-prefixed entity
imports for forward references (e.g. `import '../order/order.dart';` even
when `order/order.dart` does not exist yet), so the build resolves cleanly
once every entity in the batch has been generated.

```bash
# Step 1: Customer references Order (which does not exist yet)
zfa entity create -n Customer \
  --field id:String? \
  --field orders:List<Order> \
  --allow-forward-refs

# Step 2: Order references Customer back — cycle closed
zfa entity create -n Order \
  --field id:String? \
  --field customer:Customer? \
  --allow-forward-refs
```

### Auto-generated ids (`--auto-id`)

`zfa make` requires every entity to have a real identity (issue #307 — the
old silent first-field fallback produced enum-typed ids for id-less entities
like `ChatMessage` / `TelemetryEvent`). Pass `--auto-id` to have zfa declare
a `String id` field that the generated constructor defaults to a fresh
`Uuid().v4()` — callers construct the entity without supplying an id:

```bash
zfa entity create -n ChatMessage --auto-id \
  --field role:ChatMessageRole \
  --field content:String \
  --field timestamp:DateTime
```

The generated entity imports `package:uuid/uuid.dart`; add `uuid` to the
app's pubspec (`dart pub add uuid`) — zfa warns if it is missing.

### Value objects (`--kind=value_object`)

Entities are aggregate/event roots with identity. Immutable composition
types (parser options, transformation mappings, embedded value records)
have no identity of their own — model them as **value objects**:

```bash
zfa entity create -n ParserConfig --kind=value_object \
  --field separator:String \
  --field trimWhitespace:bool
```

A value object's annotation carries `kind: ZorphyKind.valueObject` (the
`@ZValueObject` alias is equivalent). Codegen is identical to an entity
(equality, copyWith, JSON), but `zfa make` treats it as an embedded type:
repository/usecase/controller/presenter (and the other persisted-root
plugins) are skipped with a notice — no id is required and the loud
no-id error never fires for it.

### Id-less entities fail loudly

An entity with no `id` / `*Id` field and no `--auto-id` / value-object
marker makes `zfa make` fail with a clear diagnostic (instead of silently
falling back to the first field). The message lists the three fixes: add an
id field, recreate with `--auto-id`, or model it as a value object.

`--allow-forward-refs` is **opt-in**. The default behaviour (reject unknown
types) is unchanged — it still guards against typos and genuinely missing
enums/entities when you are generating a single entity outside a batch.

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
