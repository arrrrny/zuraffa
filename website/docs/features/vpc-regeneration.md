# VPC Regeneration

Zuraffa v5 supports targeted regeneration of presentation logic while preserving the canonical generation contract.

Use `zfa make` to regenerate presentation layers instead of relying on older feature-first examples.

---

## Common workflows

### 1. Initial VPC generation

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create \
  --with=vpc \
  --state
```

### 2. Add new watch logic without rewriting everything else

```bash
zfa make Product presenter controller state --methods=watch --force
```

### 3. Refresh presenter/controller/state while keeping manual UI work separate

```bash
zfa make Product presenter controller state --methods=create,update --force
```

---

## Manual UI boundary

Generated presentation ownership covers:

- presenter
- controller
- state
- generated view scaffolding

Manual UI composition and page-specific layout refinements should remain hand-authored.

---

## Next steps

- [UseCase Types](../architecture/usecases)
- [CLI Commands Reference](../cli/commands)
