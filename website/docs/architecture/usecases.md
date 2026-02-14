# UseCase Types

Use cases are the heart of the domain layer. Zuraffa v3 supports multiple styles, with dependencies injected via repositories or services. Data sources stay in the data layer, and providers can be used in the presentation layer when needed.

## Standard use case

Single-shot operations that return a `Result`.

```bash
zfa generate Product --methods=get,getList
```

## Completable use case

Use when there is no return value.

```bash
zfa generate Product --methods=delete
```

## Stream use case

Use for live updates or subscriptions.

```bash
zfa generate Product --methods=watch,watchList
```

## Sync use case

Use for immediate, synchronous operations.

```bash
zfa generate IsWalkthroughRequired --type=sync --params=Customer --returns=bool
```

## Background use case

Runs on an isolate for CPU-heavy work.

```bash
zfa generate CalculatePrimeNumbers --type=background --params=int --returns=int
```

## Orchestrator use case

Composes existing use cases into a workflow.

```bash
zfa generate ProcessCheckout --domain=checkout --usecases=ValidateCart,CreateOrder,ProcessPayment --params=CheckoutRequest --returns=Order
```
