# Migration Guide: Zuraffa v1 → v2

This guide helps existing Zuraffa users migrate from v1 to v2. It focuses on CLI changes, file layout changes, and common breakpoints.

## Quick Checklist

- Update dependency version
- Refresh CLI flags in scripts
- Regenerate code with updated flags
- Review custom UseCases for new domain layout
- Update DI expectations

## 1) Update Your Dependency

```yaml
dependencies:
  zuraffa: ^2.8.0
```

```bash
flutter pub get
dart pub global activate zuraffa
```

## 2) CLI Flag Changes

### Replace `--repos` with `--repo`

**Before**
```bash
zfa generate ProcessCheckout --repos=Cart,Order,Payment --params=Request --returns=Order
```

**After**
```bash
zfa generate ProcessCheckout --repo=Checkout --domain=checkout --params=Request --returns=Order
```

### Orchestrators for multi-repo workflows

```bash
zfa generate ValidateCart --repo=Cart --domain=checkout --params=CartId --returns=bool
zfa generate CreateOrder --repo=Order --domain=checkout --params=OrderData --returns=Order
zfa generate ProcessPayment --repo=Payment --domain=checkout --params=PaymentData --returns=Receipt

zfa generate ProcessCheckout \
  --usecases=ValidateCart,CreateOrder,ProcessPayment \
  --domain=checkout \
  --params=CheckoutRequest \
  --returns=Order
```

### Replace `--subdirectory` with `--domain`

Custom UseCases now require `--domain` and generate to:

```
lib/src/domain/usecases/<domain>/
```

## 3) Parameter Type Flags

Parameter handling is now explicit:

- `--id-field-type` controls update/delete identifiers
- `--query-field-type` controls get/watch parameters

Example:

```bash
zfa generate Product --methods=get,getList --data --query-field-type=String
```

For parameterless get/watch, use:

```bash
zfa generate AppConfig --methods=get,watch --data --query-field-type=NoParams
```

## 4) DI Generation Behavior

DI generation is now simplified. The `--di` flag focuses on infrastructure:

- DataSources and Repositories are registered
- UseCases, Presenters, and Controllers are instantiated directly in code

If you depended on auto-registration of UseCases or Presenters in v1, move that wiring into your view or app setup.

## 5) UseCase Folder Structure

Entity UseCases are grouped under:

```
lib/src/domain/usecases/<entity>/
```

Custom UseCases are grouped under:

```
lib/src/domain/usecases/<domain>/
```

Update any manual imports to reflect this structure.

## 6) Append Mode

`--append` can add methods to existing files without full regeneration. Use it when you add new UseCases or methods to an existing entity.

```bash
zfa generate WatchProduct --domain=product --repo=Product --params=String --returns=Stream<Product> --type=stream --append
```

## 7) Regenerate and Review

After updating flags, rerun generation and review diffs:

```bash
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --test --force
```

## Troubleshooting

### Missing file or import errors

- Confirm `--domain` is set for custom UseCases
- Check new usecase folder locations
- Re-run generation with `--force` after moving files

### Parameter mismatch in generated UseCases

- Ensure `--query-field-type` matches your expected `QueryParams` type
- Use `NoParams` for parameterless get/watch methods

### DI registration not found

- In v2, `--di` no longer registers UseCases, Presenters, or Controllers
- Instantiate these in your view or app setup

## FAQ

### Do I have to migrate immediately?

Not required, but new features and fixes target v2. Upgrading keeps you aligned with the current CLI and generator behavior.

### Can I keep my existing folder structure?

You can, but generated code follows the v2 structure. Consider aligning to avoid import drift.
