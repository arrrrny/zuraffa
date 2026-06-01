# Migration Guide: Zuraffa v4 → v5

Zuraffa v5 simplifies the public generation contract around one canonical workflow:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

The biggest conceptual change is that `zfa make` is now the primary generator. `zfa feature scaffold` remains available, but it should be treated as a wrapper over the feature preset rather than the main public workflow.

---

## Quick checklist

- Update your docs, scripts, and prompts to use `zfa make`.
- Use `zfa entity create` for entities.
- Use `zfa build` instead of teaching `build_runner` directly.
- Assume a fixed domain root: `lib/src/domain`.
- Assume entities live under `lib/src/domain/entities`.
- Assume public v5 docs are Zorphy-first.
- Adopt `.zfa.json` for defaults and the canonical `.zfa/` memory model.

---

## Command mapping

| Before | After |
| --- | --- |
| one-shot architecture generation | `zfa make <Name> ...` |
| feature-first public docs | `zfa make` as primary, `zfa feature scaffold` as wrapper |
| direct build runner guidance | `zfa build` |
| hand-created entities in docs | `zfa entity create` |

---

## Canonical v5 example

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

---

## Fixed layout rules

Zuraffa v5 public docs assume:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example:

```text
lib/src/domain/entities/product/product.dart
```

Do not document alternate domain roots for v5.

---

## `.zfa.json` and `.zfa/`

Use these concepts when migrating teams and AI prompts:

- **`.zfa.json`** = project defaults
- **`.zfa/`** = canonical project memory for plans, runs, decisions, blueprints, manifests, and context

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

During the migration period, some internals may still reference older storage paths. Public docs should still point forward to `.zfa/`.

---

## Agent guidance

When updating prompts, AGENTS guidance, or skills, normalize to this sentence:

> In v5, create the entity first, generate architecture with `zfa make`, and finish with `zfa build`. `zfa feature` is only a wrapper over the feature preset.

---

## Related docs

- [Intro](../intro)
- [Getting Started](./getting-started)
- [CLI Commands Reference](../cli/commands)
