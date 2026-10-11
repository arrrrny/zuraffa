Zuraffa's error handling infrastructure is built on a **sealed class hierarchy** that enables exhaustive compile-time pattern matching, a **`Result<S, F>` type** inspired by functional Either patterns, and a **batched failure reporting pipeline** with persistence and retry — all designed so that every failure path is typed, traceable, and recoverable.

The system has three primary layers:

1. **[AppFailure](#appfailure-sealed-class-hierarchy)** — the typed failure taxonomy
2. **[Result](#resultlts-f-gnified-either)** — the success/failure container
3. **[Failure Reporting Pipeline](#failure-reporting-pipeline)** — detection → classification → enqueue → deliver → persist

---

## AppFailure: Sealed Class Hierarchy

`AppFailure` is the root sealed class for all domain errors. Because it is `sealed`, Dart's `switch` expressions can **exhaustively match** every subtype — the compiler warns if any branch is missing. Each subtype carries only the data relevant to its category, avoiding null fields or generic containers.

```dart
sealed class AppFailure implements Exception {
  final String message;
  final String? code;       // machine-readable error code (e.g. GraphQL type name)
  final StackTrace? stackTrace;
  final Object? cause;
}
```

`AppFailure` implements `Exception`, so it can propagate through `try/catch` blocks naturally. The factory constructor `AppFailure.from(error, [stackTrace])` provides intelligent classification: it walks the subtype chain from most specific (`NetworkFailure`) to least specific (`UnknownFailure`), returning the first match [lib/src/core/failure.dart#L89-L101](lib/src/core/failure.dart#L89-L101).

### Subtype Taxonomy

| Subtype | Category | Key Fields | HTTP Mapping |
|---|---|---|---|
| **ServerFailure** | Server error | `statusCode` | 500–599 |
| **NetworkFailure** | Connectivity | — | DNS/refused/reset |
| **CacheFailure** | Storage | — | — |
| **ValidationFailure** | Input validation | `fieldErrors: Map<String, List<String>>?` | 422 |
| **NotFoundFailure** | Missing resource | `resourceId`, `resourceType` | 404 |
| **UnauthorizedFailure** | Auth missing | — | 401 |
| **ForbiddenFailure** | Auth insufficient | `requiredPermission` | 403 |
| **ConflictFailure** | State conflict | `conflictType` | 409 |
| **TimeoutFailure** | Duration exceeded | `timeout: Duration?` | — |
| **CancellationFailure** | Intentional stop | (no stack trace / cause) | — |
| **PlatformFailure** | Platform-specific | `code`, `details` | — |
| **UnknownFailure** | Fallback | — | — |
| **StateFailure** | Invalid app state | — | — |
| **TypeFailure** | Type mismatch | — | — |
| **UnimplementedFailure** | Not yet built | — | — |
| **UnsupportedFailure** | Not supported | — | — |

Each subtype implements `from(Object error, StackTrace? stackTrace)` returning `Nullable` — the classification chain in `AppFailure.from` short-circuits on first match:

```dart
return NetworkFailure.from(error, stackTrace) ??
    TimeoutFailure.from(error, stackTrace) ??
    NotFoundFailure.from(error, stackTrace) ??
    // ... until UnknownFailure.from(...) which always returns non-null.
```
[lib/src/core/failure.dart#L89-L113](lib/src/core/failure.dart#L89-L113)

### Exhaustive Switch Contract

The sealed hierarchy guarantees that adding a new failure type is a **breaking change** — every `switch` expression over `AppFailure` must be updated. This is enforced by a test that iterates all 15 concrete types and asserts each maps to a non-empty switch label [test/core/failure_test.dart#L405-L424](test/core/failure_test.dart#L405-L424).

```dart
void handleFailure(AppFailure failure) {
  switch (failure) {
    case ServerFailure(:final statusCode):
      print('Server error: $statusCode');
    case NetworkFailure():
      print('Check your connection');
    // ... all 15 cases required by compiler
    case UnknownFailure():
      print('Something went wrong');
  }
}
```
[lib/src/core/failure.dart#L7-L26](lib/src/core/failure.dart#L7-L26)

### Extension Conversions

Two extensions provide ergonomic conversion from Dart primitives:

- **`ExceptionToFailure`** — `exception.toFailure([stackTrace])` → `AppFailure` [lib/src/core/failure.dart#L630-L637](lib/src/core/failure.dart#L630-L637)
- **`ErrorToFailure`** — `error.toFailure([stackTrace])` → `AppFailure` (preserves native `StackTrace`) [lib/src/core/failure.dart#L640-L646](lib/src/core/failure.dart#L640-L646)

---

## FailureHandler Mixin: Automatic Error Classification

The `FailureHandler` mixin provides a single entry point — `handleError(error, [stackTrace])` — that uses Dart's pattern matching (`switch` expression) to classify any exception into the correct `AppFailure` subtype [lib/src/core/failure_handler.dart#L13-L193](lib/src/core/failure_handler.dart#L13-L193).

```dart
class MyDataSource with FailureHandler {
  Future<Customer> getCustomer(String id) async {
    try {
      // ... fetch customer
    } catch (e) {
      throw handleError(e);  // → typed AppFailure
    }
  }
}
```

### Classification Table

| Dart Error/Exception | → AppFailure Subtype | Rationale |
|---|---|---|
| `IndexError` | `ValidationFailure` | Bounds violation = invalid input |
| `RangeError` | `ValidationFailure` | Range violation = invalid input |
| `ArgumentError` | `ValidationFailure` | Bad argument = invalid input |
| `FormatException` | `ValidationFailure` | Parse failure = invalid input |
| `TimeoutException` | `TimeoutFailure` | Direct mapping |
| `CancelledException` | `CancellationFailure` | Direct mapping |
| `ZuraffaPlatformException` | `PlatformFailure` | Platform bridge exception |
| `ZuraffaMissingPluginException` | `UnsupportedFailure` | Plugin absent = unsupported |
| `StateError` / `ConcurrentModificationError` / `StackOverflowError` / `OutOfMemoryError` | `StateFailure` | Runtime state corruption |
| `TypeError` / `NoSuchMethodError` | `TypeFailure` | Type contract violation |
| `UnimplementedError` | `UnimplementedFailure` | Feature not built |
| `UnsupportedError` | `UnsupportedFailure` | Operation not supported |
| Anything else | `AppFailure.from(error)` | Falls through to subtype chain → `UnknownFailure` |

[lib/src/core/failure_handler.dart#L27-L153](lib/src/core/failure_handler.dart#L27-L153)

### Pure-Dart Platform Surrogates

Since `FailureHandler` must work without Flutter SDK dependencies, Zuraffa defines lightweight replacements for Flutter's `PlatformException` and `MissingPluginException` [lib/src/core/failure_handler.dart#L247-L272](lib/src/core/failure_handler.dart#L247-L272):

- **`ZuraffaPlatformException`** — carries `code`, `message?`, `details`
- **`ZuraffaMissingPluginException`** — carries optional `message`

### Log-and-Handle Bridge

`logAndHandleError` combines classification with side effects: it logs at SEVERE level, reports through `FailureReporterRegistry`, and returns the `AppFailure` [lib/src/core/failure_handler.dart#L175-L191](lib/src/core/failure_handler.dart#L175-L191):

```dart
AppFailure logAndHandleError(Object error, [StackTrace? stackTrace]) {
  final failure = handleError(error, stackTrace);
  logger.severe('Error occurred: $failure', error, stackTrace);
  FailureReporterRegistry.instance.reportFailure(failure, stackTrace: stackTrace);
  return failure;
}
```

---

## Failure Reporting Pipeline

The failure reporting pipeline follows OpenTelemetry's **BatchSpanProcessor** conventions: failures are enqueued, batched, and delivered to registered reporters with retry support and disk persistence.

```mermaid
graph TD
    A[Error Occurs] --> B{AppFailure.from<br/>or handleError}
    B --> C[FailureReport<br/>(failure + timestamp + stackTrace + attributes)]
    C --> D[FailureReportQueue.enqueue]
    D --> E{Queue < maxQueueSize?}
    E -->|No| F[Drop oldest report]
    E -->|Yes| G{Queue >= half full?}
    G -->|Yes| H[Trigger async flush]
    G -->|No| I[Wait for flush timer]
    H --> J[Batch by maxBatchSize]
    J --> K[Deliver to each FailureReporter]
    K --> L{All succeeded?}
    L -->|Yes| M[Remove from queue]
    L -->|No| N[Retry per ReportRetryPolicy]
    N --> O{Retry exhausted?}
    O -->|No| K
    O -->|Yes| P[Persist remaining to disk<br/>if FailureReportStore configured]
    M --> Q{More in queue?}
    Q -->|Yes| J
    Q -->|No| R[Clear store if empty]
```

### Pipeline Components

| Component | File | Role |
|---|---|---|
| **FailureReport** | [lib/src/core/failure_reporter.dart#L19-L40](lib/src/core/failure_reporter.dart#L19-L40) | Immutable record: failure + metadata |
| **FailureReporter** (abstract) | [lib/src/core/failure_reporter.dart#L43-L87](lib/src/core/failure_reporter.dart#L43-L87) | Abstract contract for external delivery |
| **OtelFailureReporter** | [lib/src/core/otel_failure_reporter.dart#L18-L64](lib/src/core/otel_failure_reporter.dart#L18-L64) | OTel span mapping (default implementation) |
| **FailureReportQueue** | [lib/src/core/failure_report_queue.dart#L18-L45](lib/src/core/failure_report_queue.dart#L18-L45) | Bounded in-memory batch queue |
| **FailureReportStore** | [lib/src/core/failure_report_store.dart#L17-L37](lib/src/core/failure_report_store.dart#L17-L37) | JSON file persistence across restarts |
| **FailureReporterRegistry** | [lib/src/core/failure_reporter_registry.dart#L26-L64](lib/src/core/failure_reporter_registry.dart#L26-L64) | Global singleton managing reporters + queue |
| **ReportRetryPolicy** | [lib/src/core/retry_policy.dart#L13-L32](lib/src/core/retry_policy.dart#L13-L32) | Abstract retry strategy |

### FailureReporter Contract

Implement `FailureReporter` to deliver failures to any backend [lib/src/core/failure_reporter.dart#L43-L87](lib/src/core/failure_reporter.dart#L43-L87):

```dart
abstract class FailureReporter {
  String get id;
  bool shouldReport(AppFailure failure);        // filter: default excludes CancellationFailure
  Future<void> reportBatch(List<FailureReport> reports);  // called during flush
  Future<void> initialize() async {}            // setup OTel provider, etc.
  Future<void> dispose() async {}               // cleanup
}
```

Key design decision: **throwing in `reportBatch` signals a retryable failure** — the queue will retry per the configured `ReportRetryPolicy`. This allows transient network errors to self-heal without losing reports.

### OtelFailureReporter: Attribute Mapping

The shipped `OtelFailureReporter` maps each `AppFailure` subtype to specific OTel span attributes using exhaustive `switch` pattern matching [lib/src/core/otel_failure_reporter.dart#L157-L260](lib/src/core/otel_failure_reporter.dart#L157-L260):

| Failure Type | OTel Attributes |
|---|---|
| `ServerFailure` | `http.status_code` |
| `NetworkFailure` | `failure.category = "network"` |
| `ValidationFailure` | `failure.category = "validation"`, `failure.fields` |
| `NotFoundFailure` | `failure.category = "not_found"`, `failure.resource_type`, `failure.resource_id` |
| `UnauthorizedFailure` | `failure.category = "auth"`, `failure.auth_type = "unauthorized"` |
| `ForbiddenFailure` | `failure.category = "auth"`, `failure.auth_type = "forbidden"`, `failure.required_permission` |
| `TimeoutFailure` | `failure.category = "timeout"`, `failure.timeout_ms` |
| `ConflictFailure` | `failure.category = "conflict"`, `failure.conflict_type` |
| `PlatformFailure` | `failure.category = "platform"`, `failure.platform_code` |
| All others | `failure.category = <lowercase type name>` |

### FailureReportStore: Disk Persistence

`FailureReportStore` serializes/deserializes reports to JSON, preserving failure-specific data via the `failureData` map [lib/src/core/failure_report_store.dart#L82-L127](lib/src/core/failure_report_store.dart#L82-L127)[lib/src/core/failure_report_store.dart#L143-L167](lib/src/core/failure_report_store.dart#L143-L167):

```dart
Map<String, dynamic> _failureDataToJson(AppFailure failure) {
  return switch (failure) {
    ServerFailure(:final statusCode) => {'statusCode': statusCode},
    NetworkFailure() => {},
    ValidationFailure(:final fieldErrors) => {'fieldErrors': fieldErrors},
    NotFoundFailure(:final resourceType, :final resourceId) => {
      'resourceType': resourceType, 'resourceId': resourceId,
    },
    // ... all 15 subtypes pattern-matched
  };
}
```

On deserialization, unknown failure types reconstruct as `UnknownFailure` but preserve the original type name in `attributes['failure.original_type']` for diagnostic traceability [lib/src/core/failure_report_store.dart#L187-L200](lib/src/core/failure_report_store.dart#L187-L200).

---

## FailureReporterRegistry: Global Orchestrator

The registry is a singleton that wires reporters to the queue, providing zero-config failure reporting for all UseCases [lib/src/core/failure_reporter_registry.dart#L26-L120](lib/src/core/failure_reporter_registry.dart#L26-L120):

```dart
// Register in main()
await FailureReporterRegistry.instance.register(
  OtelFailureReporter(
    collectorEndpoint: Uri.parse('https://otel.mybackend.com/v1/traces'),
    serviceName: 'my_app',
  ),
);
```

Key behaviors:
- **`reportFailure()`** is fire-and-forget — enqueues and returns immediately, never throws [lib/src/core/failure_reporter_registry.dart#L137-L155](lib/src/core/failure_reporter_registry.dart#L137-L155)
- **`configure()`** must be called before first `register()`; queue parameters apply on next restart
- **`reportFailure()`** is called automatically by `UseCase.call()`, `StreamUseCase.call()`, `BackgroundUseCase.call()`, `SyncUseCase.call()`, and `FailureHandler.logAndHandleError()`
- **`dispose()`** performs a final flush, persists remaining reports if a store is configured, then clears everything [lib/src/core/failure_reporter_registry.dart#L170-L200](lib/src/core/failure_reporter_registry.dart#L170-L200)

### Queue Configuration Defaults

| Parameter | Default | Purpose |
|---|---|---|
| `maxQueueSize` | 256 | Maximum reports before oldest are dropped |
| `maxBatchSize` | 32 | Reports per flush batch |
| `flushInterval` | 5 seconds | Periodic flush timer |
| `retryPolicy` | `ExponentialBackoffRetryPolicy` | Retry strategy (1.5× multiplier, 30s cap, 5 max retries) |
| `persistFailures` | false | Enable disk persistence via `FailureReportStore` |

[lib/src/core/failure_reporter_registry.dart#L66-L100](lib/src/core/failure_reporter_registry.dart#L66-L100)

---

## Result<S, F>: The Either Type

`Result` is a sealed class representing either a success (`Success<S, F>`) or failure (`Failure<S, F>`), providing type-safe error handling without exceptions [lib/src/core/result.dart#L1-L26](lib/src/core/result.dart#L1-L26):

```dart
sealed class Result<S, F> {
  const factory Result.success(S value) = Success<S, F>;
  const factory Result.failure(F error) = Failure<S, F>;

  bool get isSuccess;
  bool get isFailure;
  T fold<T>(T Function(S) onSuccess, T Function(F) onFailure);
  Result<T, F> map<T>(T Function(S) transform);
  Result<S, T> mapFailure<T>(T Function(F) transform);
  Result<T, F> flatMap<T>(Result<T, F> Function(S) transform);
  S getOrElse(S Function() defaultValue);
  S? getOrNull();
  S getOrThrow();
  F? getFailureOrNull();
}
```

### Core Methods Comparison

| Method | Success behavior | Failure behavior |
|---|---|---|
| `fold()` | Calls `onSuccess(value)` | Calls `onFailure(error)` |
| `map()` | Transforms value | Passes through unchanged |
| `mapFailure()` | Passes through unchanged | Transforms error |
| `flatMap()` | Chains operation returning Result | Passes failure through |
| `getOrElse()` | Returns value | Returns `defaultValue()` |
| `getOrNull()` | Returns value | Returns `null` |
| `getOrThrow()` | Returns value | Throws error (or wraps in `Exception`) |

### Extension Methods

- **`ResultAsyncExtensions`** — `mapAsync()` and `flatMapAsync()` for async transformations on `Result<S, F>` [lib/src/core/result.dart#L287-L310](lib/src/core/result.dart#L287-L310)
- **`FutureResultExtensions`** — `map()`, `flatMap()`, `getOrElse()`, `getOrNull()`, `fold()` on `Future<Result<S, F>>` [lib/src/core/result.dart#L313-L340](lib/src/core/result.dart#L313-L340)

### LoadingResult

A third state — `LoadingResult<S, F>` — extends `Result` to represent in-progress operations, used with `SignalResult` to model loading without nullable workarounds [lib/src/core/result.dart#L343-L423](lib/src/core/result.dart#L343-L423). It has two const constructors: `LoadingResult.loading()` and `LoadingResult.idle()`.

---

## SignalResult: Reactive Result Wrapper

`SignalResult<T>` wraps `Result<T, AppFailure>` in a reactive `Signal`, providing O(1) reads, fine-grained subscriptions, and async-to-sync bridging [lib/src/core/signals/signal_result.dart#L21-L92](lib/src/core/signals/signal_result.dart#L21-L92):

```dart
// Factory constructors
SignalResult.fromFuture(future, {emitLoading = true})   // async → SignalResult
SignalResult.success(value)                              // immediate success
SignalResult.failure(error)                              // immediate failure

// Read API
Result<T, AppFailure> value                              // O(1) signal read
T? data / AppFailure? error / bool isSuccess / isFailure // derived shorthand

// Write API (used by UseCase implementations)
emit(Result) / emitSuccess(T) / emitFailure(AppFailure) / emitLoading()
update(updater) / updateData(transformer)

// Subscription
listen(callback) / onSuccess(callback) / onFailure(callback) / nextValue

// Transformation
map<R>(transform) / flatMap<R>(transform)
```

`SignalResult.fromFuture` automatically converts exceptions to `AppFailure` via `AppFailure.from(e, st)`, providing a single entry point for async error classification [lib/src/core/signals/signal_result.dart#L75-L89](lib/src/core/signals/signal_result.dart#L75-L89).

---

## Failure Hook System (Legacy → ArtifactPublisher)

`FailureHook` and `FailureHookManager` are **deprecated** backward-compatibility wrappers that delegate to `ArtifactPublisher` [lib/src/core/failure_hooks.dart#L14-L26](lib/src/core/failure_hooks.dart#L14-L26)[lib/src/core/failure_hooks.dart#L157-L236](lib/src/core/failure_hooks.dart#L157-L236). New code should use `ArtifactPublisher`, `ArtifactHook`, and `ArtifactContext` directly.

Key legacy behavior preserved:
- **`FailureHook.shouldTrigger()`** excludes `CancellationFailure` and `UnknownFailure` by default
- **`FailureHookManager`** creates internal `_FailureHookAdapter` instances and registers them with `ArtifactPublisher`
- **`FailureContext.isScrapingFailure`** is a convenience getter that matches `NetworkFailure`, `ServerFailure`, `TimeoutFailure`, and `ValidationFailure` [lib/src/core/failure_hooks.dart#L40-L47](lib/src/core/failure_hooks.dart#L40-L47)

---

## Resilience Patterns

### Transactional File System

`TransactionalFileSystem` wraps a base `FileSystem` and routes all operations through a `GenerationTransaction` when active. If a file is deleted within a transaction, reads **throw an Exception** rather than returning stale data [lib/src/core/transaction/transactional_file_system.dart#L20-L120](lib/src/core/transaction/transactional_file_system.dart#L20-L120):

```dart
Future<String> read(String path) async {
  final transaction = GenerationTransaction.current;
  if (transaction != null) {
    final op = transaction.operations.where(...).lastOrNull;
    if (op != null) {
      if (op.type == FileOperationType.delete) {
        throw Exception('File deleted in transaction: $path');  // ← explicit failure
      }
      return op.content ?? '';
    }
  }
  return base.read(path);
}
```

### Retry Policies

Three built-in retry strategies for failure report delivery [lib/src/core/retry_policies.dart#L1-L102](lib/src/core/retry_policies.dart#L1-L102):

| Policy | Use Case | Key Parameters |
|---|---|---|
| `ExponentialBackoffRetryPolicy` | OTel standard (default) | multiplier: 1.5, maxInterval: 30s, maxRetries: 5 |
| `FixedIntervalRetryPolicy` | Predictable cadence | interval, maxRetries |
| `NoRetryPolicy` | Best-effort, no retries | — |

Custom policies implement `ReportRetryPolicy.nextDelay(int attemptNumber, Duration lastDelay)` returning `null` to stop retrying [lib/src/core/retry_policy.dart#L13-L32](lib/src/core/retry_policy.dart#L13-L32).

### Verdict Schema Enforcement

`VerdictEnvelope.fromJson` **throws `VerdictSchemaException`** for any envelope not matching `zuraffa.verdict.v1` — old drifted schemas break loudly and are never silently reinterpreted [lib/src/core/verdict_envelope.dart#L340-L353](lib/src/core/verdict_envelope.dart#L340-L353). This applies to schema identifier, verdict values, and command presence.

---

## Interceptor Pipeline Integration

`InterceptableUseCase` wraps the `call()` method with an interceptor chain from `InterceptorRegistry`, enabling cross-cutting error handling without modifying each use case [lib/src/core/usecase_interceptor/interceptable_usecase.dart#L46-L73](lib/src/core/usecase_interceptor/interceptable_usecase.dart#L46-L73):

```dart
abstract class InterceptableUseCase<In, Out> extends ZuraffaUseCase<In, Out> {
  final InterceptorRegistry? interceptorRegistry;

  @override
  SignalResult<Out> call(In params, {ZuraffaContext? context}) {
    final registry = interceptorRegistry;
    if (registry == null || registry.isEmpty) {
      return executeCall(params, context: context);
    }
    final pipeline = registry.chain<In, Out>(
      (In request) => executeCall(request, context: context),
    );
    return pipeline(params);
  }

  SignalResult<Out> executeCall(In params, {ZuraffaContext? context});
}
```

Interceptors can **short-circuit** by returning a pre-built `SignalResult.failure(AppFailure)` instead of calling `next`, enabling centralized error handling policies [lib/src/core/usecase_interceptor/interceptable_usecase.dart#L21-L35](lib/src/core/usecase_interceptor/interceptable_usecase.dart#L21-L35).

---

## Reading Progression

To build a complete understanding of Zuraffa's error handling, follow this order:

1. **[Sealed Failures & Error Handling](11-sealed-failures-and-error-handling)** — this page
2. **[UseCase Hierarchy & the Result Pattern](10-usecase-hierarchy-and-the-result-pattern)** — how `Result` and `SignalResult` integrate with UseCases
3. **[Transactional File System, Revert & Plan Store](9-transactional-file-system-revert-and-plan-store)** — transaction-based error containment
4. **[Telemetry, Failure Reporting & Artifacts](29-telemetry-failure-reporting-and-artifacts)** — production failure reporting architecture
5. **[Testing Strategy & Result Matchers](26-testing-strategy-and-result-matchers)** — testing failure paths