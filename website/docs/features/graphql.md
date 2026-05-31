# GraphQL Generation

GraphQL generation is additive in Zuraffa v5: create the entity first, then use `zfa make` to add GraphQL-related outputs to the normalized plan.

---

## Basic usage

### 1. Entity-based generation

```bash
zfa make Product --preset=crud --methods=get,getList,create --gql
```

### 2. Add schema generation too

```bash
zfa make Product --preset=crud --methods=get,getList,create --gql --graphql
```

### 3. Custom return fields

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList \
  --gql \
  --gql-returns="id,name,price,category,stock,isActive"
```

---

## Custom use case example

```bash
zfa make SearchProducts usecase \
  --domain=search \
  --params=SearchRequest \
  --returns=List<Product> \
  --gql \
  --gql-type=query \
  --gql-name=searchProducts \
  --gql-input-type=SearchInput \
  --gql-returns="id,name,price,category"
```

---

## Operation mapping

Entity methods typically map as follows:

| Method                       | GraphQL operation |
| ---------------------------- | ----------------- |
| `get`, `getList`             | query             |
| `create`, `update`, `delete` | mutation          |
| `watch`, `watchList`         | subscription      |

---

## Next steps

- [CLI Commands Reference](../cli/commands)
- [Caching](./caching)
