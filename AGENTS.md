# AI Agents Guide for Zuraffa

This file defines the current v5 contract for AI agents working in Zuraffa projects.

## Generation contract: use the canonical v5 workflow

When you need to create or evolve architecture code, use this sequence:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

### Canonical example

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

## Hard rules

- **Do not use the removed legacy one-shot generator.**
- **Prefer `zfa make` over `zfa feature`.** `zfa feature scaffold` is only a wrapper over the feature preset.
- **Do not hand-create entities.** Use `zfa entity create`.
- **Do not call `build_runner` directly in normal agent flows.** Use `zfa build`.
- **Do not invent alternate folder structures.** Zuraffa v5 assumes a fixed domain root.

## Fixed layout assumptions

Zuraffa v5 public docs assume:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example:

```text
lib/src/domain/entities/product/product.dart
```

Also assume:

- fixed domain root: `lib/src/domain`
- entities are Zorphy-first on public v5 surfaces
- output examples should target `lib/src`, not custom architecture roots

## What `make` should be used for

Use `zfa make` for:

- CRUD architecture around an entity
- adding or regenerating repository/data layers
- adding VPC layers via `--with=vpc` and `--state`
- enabling DI, tests, cache, mock, route, gql, or graphql support
- custom use cases and orchestrators

Examples:

```bash
# Basic CRUD stack
zfa make Product --preset=crud --methods=get,getList,create,update,delete

# Add presentation and tests
zfa make Product --preset=crud --with=vpc --state --test --methods=get,getList

# Add cache + DI + mocks
zfa make Product --preset=crud --cache --di --mock --use-mock --methods=get,getList

# Custom use case
zfa make SearchProducts usecase --domain=search --params=SearchQuery --returns=List<Product>
```

## `feature` is still available, but not primary

If a user explicitly asks for `zfa feature`, treat it as wrapper syntax over the normalized feature preset.

Equivalent examples:

```bash
zfa make Product --preset=feature --plan
```

```bash
zfa feature scaffold Product --plan
```

In tutorials, prompts, and examples, prefer `zfa make`.

## Generated architecture vs manual UI

Use `zfa` for generated architecture ownership:

- entities
- repositories
- datasources
- usecases
- presenters/controllers/state
- DI/test/mock/cache/route/graphql support

Handcraft only the parts that are intentionally manual, such as:

- view composition details
- page-specific widget layout adjustments
- styling and presentation refinements
- feature-specific business implementation inside generated extension points

## `.zfa.json` and `.zfa/` memory for agents

Agents should treat these as the project memory surfaces:

- **`.zfa.json`**: project defaults, plugin defaults, entity-first settings
- **`.zfa/`**: canonical v5 memory for plans, runs, decisions, blueprints, manifests, and context

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

During the migration period, some internals may still use older storage paths. Use `.zfa/` as the public-facing docs contract and `.zfa.json` as the active config file.

## Search guidance

- Prefer semantic/code-aware search when available.
- Use exact grep only when you need literal string matches.
- When updating docs, verify examples match the current CLI help and tests.

## Validation guidance

After editing generation-related docs or workflows, prefer focused validation such as:

```bash
flutter test test/regression/docs_command_consistency_test.dart
flutter test test/core/artifact_publisher_test.dart
```

Use `dart analyze` or the editor analyzer on the files you touched.

## Migration shorthand for older projects

If you encounter older guidance, normalize it to:

- old entity setup → `zfa entity create`
- old generation step → `zfa make`
- old direct build-runner step → `zfa build`

For a user coming from older Zuraffa docs, the shortest correct explanation is:

> In v5, create the entity first, generate architecture with `zfa make`, and finish with `zfa build`. Treat `zfa feature` as a wrapper, not the primary workflow.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read specs/008-mock-json-method/plan.md
<!-- SPECKIT END -->
