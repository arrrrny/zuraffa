# Quickstart: UseCase Registration Commands

**Feature**: Declarative UseCase Registration
**Date**: 2026-06-12

---

## Overview

Register and unregister commands let you add or remove use cases in existing Presenters, Controllers, and State classes.

## Basic Usage

### Register in Presenter

```
zfa presenter register GetProduct
```

This appends:

- A `late final GetProductUseCase _getProduct;` field
- A `_getProduct = registerUseCase(getIt<GetProductUseCase>());` constructor statement
- The necessary import

### Register in Controller

```
zfa controller register GetProduct
```

Same pattern as presenter -- appends field + constructor + import.

### Register in State

```
zfa state register product --type=Product?
```

This appends:

- A `final Product? product;` field
- A copyWith entry

### Register in All Layers at Once

```
zfa register GetProduct --all
zfa register GetProduct -c -p
```

### Unregister (remove) a use case

```
zfa presenter unregister DeleteProduct
zfa controller unregister DeleteProduct
zfa state unregister selectedProduct
```

## Common Workflows

### Adding a new use case to an existing feature

```
zfa make GetProduct usecase --domain=product
zfa register GetProduct --all
```

### Preview changes before applying

```
zfa register GetProduct --all --dry-run
```

### Custom domain

```
zfa presenter register CreateCustomer --domain=customer
zfa state register customer --type=Customer? --domain=customer
```

## Validation

```
dart analyze lib/src/presentation/pages/product/
```

Or run the existing test suite:

```
dart test
```
