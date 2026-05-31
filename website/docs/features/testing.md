# Testing Strategy

Zuraffa treats test generation as an opt-in part of the normalized `make` plan.

Canonical flow:

1. create entity
2. generate architecture with `zfa make`
3. add `--test` when you want generated tests
4. run `zfa build`

---

## Generation

### 1. CRUD slice with tests

```bash
zfa make Product --preset=crud --methods=get,getList,create --test
```

### 2. Custom use case test generation

```bash
zfa make SearchProducts usecase --domain=search --params=SearchQuery --returns=List<Product> --test
```

---

## What gets generated?

Typical generated tests cover:

- success paths
- failure paths
- repository or service interactions
- stream behavior for watch-style use cases

---

## Hermetic default suite

External infrastructure tests should stay opt-in and outside the default hermetic test path. In this repository, local-infra integration tests are tagged separately so normal `flutter test` runs remain hermetic.

---

## Next steps

- [Mock Data](./mock-data)
- [CLI Commands Reference](../cli/commands)
