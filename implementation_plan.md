# Failure Reporting with OpenTelemetry

Ship a pluggable `FailureReporter` system in Zuraffa core with **opinionated OpenTelemetry** support, an **in-memory batch queue** with retry, and zero per-UseCase work — register once in [main()](file:///Users/arrrrny/Developer/zuraffa/test/core/failure_handler_test.dart#13-187), done.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  UseCase.call() catch blocks                                    │
│  FailureHandler.logAndHandleError()                             │
│        │ fire-and-forget                                        │
│        ▼                                                        │
│  FailureReporterRegistry (singleton)                            │
│        │                                                        │
│        ▼                                                        │
│  FailureReportQueue (in-memory, bounded)                        │
│  ┌─────────────────────────────────────────┐                    │
│  │ queue ← FailureReport{failure,time,ctx} │                    │
│  │ flush timer (scheduledDelay: 5s)        │                    │
│  │ maxQueueSize: 256 (configurable)        │                    │
│  │ maxBatchSize: 32 (configurable)         │                    │
│  └──────────────┬──────────────────────────┘                    │
│                 │ batch flush                                    │
│                 ▼                                                │
│  RetryPolicy (abstract, like CachePolicy)                       │
│  ┌─────────────────────────────────────────┐                    │
│  │ ExponentialBackoffRetry (default)       │                    │
│  │   multiplier: 1.5                       │                    │
│  │   maxInterval: 30s                      │                    │
│  │   maxRetries: 5                         │                    │
│  │   maxElapsed: 300s                      │                    │
│  └──────────────┬──────────────────────────┘                    │
│                 ▼                                                │
│  FailureReporter (abstract)                                     │
│  ┌──────────────┬──────────────────────────┐                    │
│  │ OTel         │ Custom (user-provided)   │                    │
│  │ Reporter     │ SentryReporter etc.      │                    │
│  └──────────────┴──────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

### Convention Source

This follows the **OpenTelemetry spec conventions exactly**:
- **BatchSpanProcessor** pattern: in-memory queue → periodic batch flush → exporter
- **OTLP retry**: exponential backoff (1.5x multiplier, 30s cap, 5 min max elapsed)
- **Philosophy**: telemetry must never crash the app — failed reports are dropped silently after max retries

And mirrors Zuraffa's own patterns:
- **CachePolicy** pattern: abstract strategy + concrete implementations
- **PluginRegistry** pattern: singleton registry with [register()](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/plugin_system/plugin_registry.dart#21-27)/[discover()](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/plugin_system/plugin_registry.dart#34-37)
- Opinionated defaults (like `go_router`, `get_it`)

## User Review Required

> [!IMPORTANT]
> **New dependency**: Adding `opentelemetry: ^0.18.11` to zuraffa's [pubspec.yaml](file:///Users/arrrrny/Developer/zuraffa/pubspec.yaml). Since you already ship `go_router`, `get_it`, `hive_ce_generator` etc., this is consistent with your opinionated approach. ~140k pub.dev downloads, maintained by Workiva.

> [!WARNING]
> **Queue is in-memory only** — if the app is killed during a flush, queued failures are lost. Disk persistence would require a storage dependency (Hive/SQLite). I recommend shipping in-memory first, then optionally adding persistent storage later. This matches OTel's own convention (in-memory by default, persistent optional).

## Proposed Changes

### New Files

---

#### [NEW] [failure_reporter.dart](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/failure_reporter.dart)

Core abstractions:

```dart
/// A single failure report with context.
class FailureReport {
  final AppFailure failure;
  final DateTime timestamp;
  final StackTrace? stackTrace;
  final Map<String, String>? attributes; // e.g. usecase name, user id
}

/// Abstract reporter — implement to send failures anywhere.
abstract class FailureReporter {
  String get id;

  /// Filter which failures to report (default: all except CancellationFailure).
  bool shouldReport(AppFailure failure) => failure is! CancellationFailure;

  /// Send a batch of failure reports. Throwing = retry eligible.
  Future<void> reportBatch(List<FailureReport> reports);

  Future<void> initialize() async {}
  Future<void> dispose() async {}
}
```

---

#### [NEW] [failure_report_queue.dart](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/failure_report_queue.dart)

Batch queue with configurable flush:

```dart
/// In-memory bounded queue that batches failures for reporting.
/// Follows OTel BatchSpanProcessor conventions.
class FailureReportQueue {
  final int maxQueueSize;      // default: 256
  final int maxBatchSize;      // default: 32
  final Duration flushInterval; // default: 5s

  FailureReportQueue({...});

  void enqueue(FailureReport report);  // drops if full
  Future<void> flush();                // called by timer + on dispose
  Future<void> dispose();              // flush remaining + stop timer
}
```

---

#### [NEW] [retry_policy.dart](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/retry_policy.dart)

Abstract strategy (like [CachePolicy](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/cache_policy.dart#4-17)):

```dart
/// Abstract retry strategy for failure reporting.
abstract class ReportRetryPolicy {
  /// Calculate delay before next retry, or null to give up.
  Duration? nextDelay(int attemptNumber, Duration lastDelay);
}
```

---

#### [NEW] [retry_policies.dart](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/retry_policies.dart)

Concrete implementations (like [DailyCachePolicy](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/cache_policies.dart#17-59), [TtlCachePolicy](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/cache_policies.dart#113-157)):

```dart
/// Exponential backoff — OTel standard convention.
class ExponentialBackoffRetryPolicy implements ReportRetryPolicy {
  final double multiplier;     // default: 1.5
  final Duration maxInterval;  // default: 30s
  final int maxRetries;        // default: 5
  final Duration maxElapsed;   // default: 300s (5 min)

  @override
  Duration? nextDelay(int attempt, Duration lastDelay) {
    if (attempt >= maxRetries) return null; // give up
    final next = lastDelay * multiplier;
    return next > maxInterval ? maxInterval : next;
  }
}

/// Immediate retry with fixed delay.
class FixedIntervalRetryPolicy implements ReportRetryPolicy { ... }

/// No retry — fire once, drop on failure.
class NoRetryPolicy implements ReportRetryPolicy {
  @override
  Duration? nextDelay(int attempt, Duration lastDelay) => null;
}
```

---

#### [NEW] [otel_failure_reporter.dart](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/otel_failure_reporter.dart)

Opinionated OTel implementation:

```dart
/// OpenTelemetry failure reporter — shipped with Zuraffa.
/// Maps AppFailure → OTel Span with error status + attributes.
class OtelFailureReporter extends FailureReporter {
  final Uri collectorEndpoint;
  final String serviceName;
  late final TracerProvider _tracerProvider;
  late final Tracer _tracer;

  OtelFailureReporter({
    required this.collectorEndpoint,
    required this.serviceName,
  });

  @override
  Future<void> initialize() async {
    _tracerProvider = TracerProviderBase(processors: [
      BatchSpanProcessor(CollectorExporter(collectorEndpoint)),
    ]);
    _tracer = _tracerProvider.getTracer('zuraffa-failure-reporter');
  }

  @override
  Future<void> reportBatch(List<FailureReport> reports) async {
    for (final report in reports) {
      final span = _tracer.startSpan(
        'failure.${report.failure.runtimeType}',
        attributes: _buildAttributes(report),
      );
      span.setStatus(StatusCode.error, report.failure.message);
      if (report.stackTrace != null) {
        span.recordException(report.failure, stackTrace: report.stackTrace);
      }
      span.end();
    }
  }
}
```

---

#### [NEW] [failure_reporter_registry.dart](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/failure_reporter_registry.dart)

Singleton wiring everything together:

```dart
class FailureReporterRegistry {
  static final instance = FailureReporterRegistry._();

  FailureReportQueue? _queue;
  ReportRetryPolicy _retryPolicy = ExponentialBackoffRetryPolicy();
  final Map<String, FailureReporter> _reporters = {};

  /// Register a reporter. Initializes queue on first registration.
  Future<void> register(FailureReporter reporter) async { ... }

  /// Report a failure (fire-and-forget, enqueues in batch queue).
  void reportFailure(AppFailure failure, {StackTrace? stackTrace, ...});

  /// Flush pending reports and dispose all reporters.
  Future<void> dispose() async { ... }
}
```

### Modified Files

---

#### [MODIFY] [usecase.dart](file:///Users/arrrrny/Developer/zuraffa/lib/src/domain/usecase.dart)

Add auto-reporting in the [call()](file:///Users/arrrrny/Developer/zuraffa/lib/src/domain/usecase.dart#52-83) catch blocks (already in base class → zero per-UseCase work):

```diff
 } on AppFailure catch (e) {
   logger.warning('$runtimeType failed with AppFailure: $e');
+  FailureReporterRegistry.instance.reportFailure(e, stackTrace: e.stackTrace);
   return Result.failure(e);
 } catch (e, stackTrace) {
   logger.severe('$runtimeType failed unexpectedly', e, stackTrace);
-  return Result.failure(AppFailure.from(e, stackTrace));
+  final failure = AppFailure.from(e, stackTrace);
+  FailureReporterRegistry.instance.reportFailure(failure, stackTrace: stackTrace);
+  return Result.failure(failure);
 }
```

Same change in `StreamUseCase`, `BackgroundUseCase`, `SyncUseCase`.

---

#### [MODIFY] [failure_handler.dart](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/failure_handler.dart)

Add reporting to [logAndHandleError](file:///Users/arrrrny/Developer/zuraffa/lib/src/core/failure_handler.dart#319-328):

```diff
 AppFailure logAndHandleError(Object error, [StackTrace? stackTrace]) {
   final failure = handleError(error, stackTrace);
   logger.severe('Error occurred: $failure', error, stackTrace);
+  FailureReporterRegistry.instance.reportFailure(failure, stackTrace: stackTrace);
   return failure;
 }
```

---

#### [MODIFY] [zuraffa.dart](file:///Users/arrrrny/Developer/zuraffa/lib/zuraffa.dart)

Export new files + convenience methods on [Zuraffa](file:///Users/arrrrny/Developer/zuraffa/lib/zuraffa.dart#275-391) class:

```dart
export 'src/core/failure_reporter.dart';
export 'src/core/failure_report_queue.dart';
export 'src/core/retry_policy.dart';
export 'src/core/retry_policies.dart';
export 'src/core/otel_failure_reporter.dart';
export 'src/core/failure_reporter_registry.dart';

class Zuraffa {
  /// Register a failure reporter with optional retry policy.
  static Future<void> addFailureReporter(
    FailureReporter reporter, {
    ReportRetryPolicy? retryPolicy,
    int? maxQueueSize,
    Duration? flushInterval,
  }) async { ... }

  /// Convenience: set up OpenTelemetry failure reporting in one call.
  static Future<void> enableOtelReporting({
    required Uri collectorEndpoint,
    required String serviceName,
    ReportRetryPolicy? retryPolicy,
  }) async { ... }
}
```

---

#### [MODIFY] [pubspec.yaml](file:///Users/arrrrny/Developer/zuraffa/pubspec.yaml)

```diff
 dependencies:
+  opentelemetry: ^0.18.11
```

---

#### [NEW] [failure_reporter_test.dart](file:///Users/arrrrny/Developer/zuraffa/test/core/failure_reporter_test.dart)

Tests for queue, retry, registry, filtering, fire-and-forget safety.

## User-Facing Usage

```dart
void main() {
  // Option A: Full control
  Zuraffa.enableLogging();
  Zuraffa.addFailureReporter(
    OtelFailureReporter(
      collectorEndpoint: Uri.parse('https://otel.mybackend.com/v1/traces'),
      serviceName: 'zik_zak',
    ),
  );

  // Option B: One-liner convenience
  Zuraffa.enableOtelReporting(
    collectorEndpoint: Uri.parse('https://otel.mybackend.com/v1/traces'),
    serviceName: 'zik_zak',
  );

  runApp(MyApp());
}

// That's it. Every UseCase failure is now auto-queued, batched, and sent
// to your OTel collector with exponential backoff retry.
// Network goes down? Failures queue up in memory and flush when it's back.
```

## Verification Plan

### Automated Tests

```bash
flutter test                                    # all existing tests still pass
flutter test test/core/failure_reporter_test.dart # new tests
```

### Manual Verification

Test the queue/retry behavior by:
1. Starting a local OTel collector (`docker run otel/opentelemetry-collector`)
2. Registering `OtelFailureReporter` pointing at localhost
3. Triggering a UseCase failure → verify span appears in collector
4. Stopping the collector → triggering failures → verify they queue
5. Restarting the collector → verify queued failures flush
