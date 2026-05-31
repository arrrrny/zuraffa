# UseCase Types

Use cases are the center of the domain layer in Zuraffa.

The v5 workflow for generating them is still:

1. create or verify the entity with `zfa entity create`
2. generate the use cases with `zfa make`
3. run `zfa build`

---

## UseCase patterns

### 1. Standard UseCase (async)

```bash
zfa make Product --preset=crud --methods=get,getList
```

### 2. Stream UseCase

```bash
zfa make Product --preset=crud --methods=watch,watchList
```

### 3. Sync UseCase

```bash
zfa make ValidateEmail usecase --type=sync --params=String --returns=bool --domain=auth
```

### 4. Completable UseCase

```bash
zfa make Product --preset=crud --methods=delete
```

### 5. Background UseCase

```bash
zfa make ProcessImages usecase --type=background --params=List<File> --returns=List<Image> --domain=media
```

### 6. Orchestrator UseCase

```bash
zfa make ProcessCheckout usecase --domain=checkout --usecases=ValidateCart,CreateOrder,ProcessPayment --params=CheckoutRequest --returns=Order
```

---

## Execution model

Generated use cases remain callable classes that return `Result<T, AppFailure>` variants or streams thereof, depending on the selected use case type.

---

## Next steps

- [CLI Commands Reference](../cli/commands)
- [Entity Generation](../entities/intro)
