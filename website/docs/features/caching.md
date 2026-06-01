# Caching Strategy

Zuraffa supports cache-aware generation through `zfa make`.

For v5 docs, the canonical pattern is:

1. `zfa entity create`
2. `zfa make ... --cache`
3. `zfa build`

---

## Basic usage

### 1. Generate with caching

```bash
zfa make Product --preset=crud --methods=get,getList --cache
```

### 2. Configure storage

```bash
zfa make Product --preset=crud --methods=get,getList --cache --cache-storage=sqlite
```

---

## What `--cache` adds

When caching is enabled, the normalized plan adds cache-related generation on top of the CRUD/domain/data stack.

Typical result:

- remote datasource
- local datasource
- cache policy wiring
- cached repository orchestration

---

## Next steps

- [Dependency Injection](./dependency-injection)
- [CLI Commands Reference](../cli/commands)
