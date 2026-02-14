# Welcome to Zuraffa

Zuraffa is a clean architecture toolkit for Flutter that ships with Result-based error handling, a CLI that generates production-ready structure, and a plugin system so you can extend the generator without forking it. Version 3 focuses on clarity: fewer moving parts, more predictable output, and documentation that reads like it was written by a human.

## Why teams choose Zuraffa

- Clean architecture that stays consistent across features
- Result and failure types that make error handling explicit
- Generators for entities, use cases, repositories, and UI layers
- Built-in patterns for CRUD, orchestration, streaming, and background tasks
- Dependency injection, caching, mock data, and GraphQL generation
- Plugin system introduced in v3 to customize the generator

## What’s new in v3

- Plugins are first-class: extend the CLI without editing core code
- Docs are streamlined and focused on how you actually build features
- Better defaults and more predictable CLI output

## Quick start

### Install

```yaml
dependencies:
  zuraffa: ^3.0.0
```

```bash
flutter pub get
dart pub global activate zuraffa
```

### Generate your first feature

```bash
zfa entity create -n Product \
  --field name:String \
  --field description:String? \
  --field price:double

zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --di --test
```

You get a full feature slice: entities, use cases, repositories, data sources, presentation, DI, and tests.

## Core patterns

### Entity-based CRUD

```bash
zfa generate Product --methods=get,getList,create,update,delete --data --vpc
```

### Custom use case with a repository

```bash
zfa generate ProcessCheckout --domain=checkout --repo=Checkout --params=CheckoutRequest --returns=OrderConfirmation
```

### Orchestrator use case

```bash
zfa generate ProcessCheckout --domain=checkout --usecases=ValidateCart,CreateOrder,ProcessPayment --params=CheckoutRequest --returns=Order
```

### Polymorphic variants

```bash
zfa generate Search --domain=search --variants=Barcode,Url,Text --params=SearchInput --returns=Listing --type=stream
```

## Where to go next

- [Getting Started](./guides/getting-started)
- [Architecture Overview](./architecture/overview)
- [UseCase Types](./architecture/usecases)
- [CLI Reference](./cli/commands)
- [Features](./features/dependency-injection)
