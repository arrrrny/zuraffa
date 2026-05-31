# Mock Data

Mock generation is part of the v5 `make` workflow.

---

## Generation

### 1. Basic mocks

```bash
zfa make Product --preset=crud --methods=get,getList --mock
```

### 2. Auto-wired mocks with DI

```bash
zfa make Product --preset=crud --methods=get,getList --mock --di --use-mock
```

---

## What gets generated?

When mock generation is enabled, Zuraffa can add:

- static mock data
- mock datasources
- DI wiring for mock-first development flows

---

## Next steps

- [Dependency Injection](./dependency-injection)
- [Testing Strategy](./testing)
- [CLI Commands Reference](../cli/commands)
