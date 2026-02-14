# Getting Started

This guide gets you productive quickly with Zuraffa v3. You will install the package, generate a feature, and understand the main patterns without drowning in boilerplate.

## Install

```yaml
dependencies:
  zuraffa: ^3.0.0
```

```bash
flutter pub get
dart pub global activate zuraffa
```

## Generate a first feature

```bash
zfa entity create -n Product \
  --field name:String \
  --field price:double \
  --field description:String?

zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --di --test
```

You now have:
- Entity models with JSON support
- Use cases and repository interfaces
- Data sources and repository implementations
- Presentation layer (view, presenter, controller, state)
- DI setup and tests

## Core patterns

### Entity-based CRUD

```bash
zfa generate Product --methods=get,getList,create,update,delete --data --vpc
```

### Custom use case with repository

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

## Next steps

- Run `zfa build` to generate entity code
- Implement your data sources
- Wire DI using generated setup files
- Run `flutter test`

Next: [Architecture Overview](../architecture/overview)
