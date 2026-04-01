import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Fake reporter for testing.
class FakeFailureReporter extends FailureReporter {
  final List<List<FailureReport>> reportedBatches = [];
  bool shouldFail = false;
  int failCount = 0;
  int maxFails = 0;
  Duration? artificialDelay;

  @override
  String get id => 'fake-reporter';

  @override
  Future<void> reportBatch(List<FailureReport> reports) async {
    if (artificialDelay != null) {
      await Future<void>.delayed(artificialDelay!);
    }
    if (shouldFail && failCount < maxFails) {
      failCount++;
      throw Exception('Simulated reporter failure #$failCount');
    }
    reportedBatches.add(List.from(reports));
  }
}

/// Reporter that filters server errors only.
class ServerOnlyReporter extends FailureReporter {
  final List<List<FailureReport>> reportedBatches = [];

  @override
  String get id => 'server-only';

  @override
  bool shouldReport(AppFailure failure) => failure is ServerFailure;

  @override
  Future<void> reportBatch(List<FailureReport> reports) async {
    reportedBatches.add(List.from(reports));
  }
}

void main() {
  group('FailureReport', () {
    test('creates with required fields', () {
      final failure = ServerFailure('test error');
      final report = FailureReport(
        failure: failure,
        timestamp: DateTime(2024, 1, 1),
      );

      expect(report.failure, equals(failure));
      expect(report.timestamp, equals(DateTime(2024, 1, 1)));
      expect(report.stackTrace, isNull);
      expect(report.attributes, isNull);
    });

    test('creates with optional fields', () {
      final failure = NetworkFailure('offline');
      final trace = StackTrace.current;
      final report = FailureReport(
        failure: failure,
        timestamp: DateTime.now(),
        stackTrace: trace,
        attributes: {'usecase': 'GetProductUseCase'},
      );

      expect(report.stackTrace, equals(trace));
      expect(report.attributes, {'usecase': 'GetProductUseCase'});
    });

    test('toString includes type and message', () {
      final report = FailureReport(
        failure: ServerFailure('server down'),
        timestamp: DateTime(2024, 1, 1),
      );

      expect(report.toString(), contains('ServerFailure'));
      expect(report.toString(), contains('server down'));
    });
  });

  group('FailureReporter', () {
    test('shouldReport defaults to true for most failures', () {
      final reporter = FakeFailureReporter();

      expect(reporter.shouldReport(ServerFailure('test')), isTrue);
      expect(reporter.shouldReport(NetworkFailure('test')), isTrue);
      expect(reporter.shouldReport(UnknownFailure('test')), isTrue);
      expect(reporter.shouldReport(ValidationFailure('test')), isTrue);
    });

    test('shouldReport defaults to false for CancellationFailure', () {
      final reporter = FakeFailureReporter();

      expect(reporter.shouldReport(CancellationFailure('cancelled')), isFalse);
    });

    test('shouldReport can be overridden', () {
      final reporter = ServerOnlyReporter();

      expect(reporter.shouldReport(ServerFailure('test')), isTrue);
      expect(reporter.shouldReport(NetworkFailure('test')), isFalse);
    });
  });

  group('ReportRetryPolicy', () {
    group('ExponentialBackoffRetryPolicy', () {
      test('first retry uses initial delay', () {
        const policy = ExponentialBackoffRetryPolicy(
          initialDelay: Duration(seconds: 1),
        );

        final delay = policy.nextDelay(0, Duration.zero);
        expect(delay, equals(const Duration(seconds: 1)));
      });

      test('subsequent retries use exponential backoff', () {
        const policy = ExponentialBackoffRetryPolicy(
          multiplier: 2.0,
          initialDelay: Duration(seconds: 1),
        );

        final d1 = policy.nextDelay(0, Duration.zero);
        expect(d1, equals(const Duration(seconds: 1)));

        final d2 = policy.nextDelay(1, d1!);
        expect(d2, equals(const Duration(seconds: 2)));

        final d3 = policy.nextDelay(2, d2!);
        expect(d3, equals(const Duration(seconds: 4)));
      });

      test('caps at maxInterval', () {
        const policy = ExponentialBackoffRetryPolicy(
          multiplier: 10.0,
          maxInterval: Duration(seconds: 5),
          initialDelay: Duration(seconds: 1),
        );

        final d1 = policy.nextDelay(0, Duration.zero);
        final d2 = policy.nextDelay(1, d1!);
        // 1s * 10 = 10s, capped to 5s
        expect(d2, equals(const Duration(seconds: 5)));
      });

      test('returns null after maxRetries', () {
        const policy = ExponentialBackoffRetryPolicy(maxRetries: 2);

        expect(policy.nextDelay(0, Duration.zero), isNotNull);
        expect(policy.nextDelay(1, const Duration(seconds: 1)), isNotNull);
        expect(policy.nextDelay(2, const Duration(seconds: 2)), isNull);
      });

      test('default OTel values', () {
        const policy = ExponentialBackoffRetryPolicy();
        expect(policy.multiplier, 1.5);
        expect(policy.maxInterval, const Duration(seconds: 30));
        expect(policy.maxRetries, 5);
        expect(policy.maxElapsed, const Duration(seconds: 300));
        expect(policy.initialDelay, const Duration(seconds: 1));
      });
    });

    group('FixedIntervalRetryPolicy', () {
      test('returns constant interval', () {
        const policy = FixedIntervalRetryPolicy(
          interval: Duration(seconds: 3),
          maxRetries: 5,
        );

        expect(
          policy.nextDelay(0, Duration.zero),
          equals(const Duration(seconds: 3)),
        );
        expect(
          policy.nextDelay(1, const Duration(seconds: 3)),
          equals(const Duration(seconds: 3)),
        );
      });

      test('returns null after maxRetries', () {
        const policy = FixedIntervalRetryPolicy(maxRetries: 2);

        expect(policy.nextDelay(0, Duration.zero), isNotNull);
        expect(policy.nextDelay(1, Duration.zero), isNotNull);
        expect(policy.nextDelay(2, Duration.zero), isNull);
      });
    });

    group('NoRetryPolicy', () {
      test('always returns null', () {
        const policy = NoRetryPolicy();

        expect(policy.nextDelay(0, Duration.zero), isNull);
        expect(policy.nextDelay(1, const Duration(seconds: 1)), isNull);
      });
    });
  });

  group('FailureReportQueue', () {
    late FakeFailureReporter reporter;

    setUp(() {
      reporter = FakeFailureReporter();
    });

    test('enqueues and flushes reports', () async {
      final queue = FailureReportQueue(
        reporters: [reporter],
        flushInterval: const Duration(hours: 1), // disable auto-flush
      );

      queue.enqueue(
        FailureReport(
          failure: ServerFailure('test'),
          timestamp: DateTime.now(),
        ),
      );

      expect(queue.length, 1);

      await queue.flush();

      expect(queue.length, 0);
      expect(reporter.reportedBatches.length, 1);
      expect(reporter.reportedBatches[0].length, 1);

      await queue.dispose();
    });

    test('respects maxQueueSize and drops oldest', () async {
      final queue = FailureReportQueue(
        reporters: [reporter],
        maxQueueSize: 3,
        flushInterval: const Duration(hours: 1),
      );

      for (var i = 0; i < 5; i++) {
        queue.enqueue(
          FailureReport(
            failure: ServerFailure('error $i'),
            timestamp: DateTime.now(),
          ),
        );
      }

      // Should keep the last 3 (queue drops oldest when full)
      expect(queue.length, 3);

      await queue.flush();

      // The remaining reports should be errors 2, 3, 4
      final messages = reporter.reportedBatches
          .expand((b) => b)
          .map((r) => r.failure.message)
          .toList();
      expect(messages, containsAll(['error 2', 'error 3', 'error 4']));

      await queue.dispose();
    });

    test('batches by maxBatchSize', () async {
      final queue = FailureReportQueue(
        reporters: [reporter],
        maxBatchSize: 2,
        flushInterval: const Duration(hours: 1),
      );

      for (var i = 0; i < 5; i++) {
        queue.enqueue(
          FailureReport(
            failure: ServerFailure('error $i'),
            timestamp: DateTime.now(),
          ),
        );
      }

      await queue.flush();

      // 5 reports with batch size 2 = 3 batches (2+2+1)
      expect(reporter.reportedBatches.length, 3);
      expect(reporter.reportedBatches[0].length, 2);
      expect(reporter.reportedBatches[1].length, 2);
      expect(reporter.reportedBatches[2].length, 1);

      await queue.dispose();
    });

    test('filters reports based on shouldReport', () async {
      final serverOnlyReporter = ServerOnlyReporter();
      final queue = FailureReportQueue(
        reporters: [serverOnlyReporter],
        flushInterval: const Duration(hours: 1),
      );

      // This should be enqueued (ServerFailure)
      queue.enqueue(
        FailureReport(
          failure: ServerFailure('server error'),
          timestamp: DateTime.now(),
        ),
      );

      // This should NOT be enqueued (NetworkFailure, reporter doesn't want it)
      queue.enqueue(
        FailureReport(
          failure: NetworkFailure('network error'),
          timestamp: DateTime.now(),
        ),
      );

      expect(queue.length, 1);

      await queue.flush();

      expect(serverOnlyReporter.reportedBatches.length, 1);
      expect(serverOnlyReporter.reportedBatches[0].length, 1);
      expect(
        serverOnlyReporter.reportedBatches[0][0].failure,
        isA<ServerFailure>(),
      );

      await queue.dispose();
    });

    test('does not enqueue after dispose', () async {
      final queue = FailureReportQueue(
        reporters: [reporter],
        flushInterval: const Duration(hours: 1),
      );

      await queue.dispose();

      queue.enqueue(
        FailureReport(
          failure: ServerFailure('late error'),
          timestamp: DateTime.now(),
        ),
      );

      expect(queue.length, 0);
    });

    test(
      'does not enqueue CancellationFailure with default reporter',
      () async {
        final queue = FailureReportQueue(
          reporters: [reporter],
          flushInterval: const Duration(hours: 1),
        );

        queue.enqueue(
          FailureReport(
            failure: CancellationFailure('cancelled'),
            timestamp: DateTime.now(),
          ),
        );

        expect(queue.length, 0);

        await queue.dispose();
      },
    );
  });

  group('FailureReporterRegistry', () {
    late FailureReporterRegistry registry;

    setUp(() async {
      registry = FailureReporterRegistry.instance;
      await registry.reset();
    });

    tearDown(() async {
      await registry.reset();
    });

    test('starts with no reporters', () {
      expect(registry.hasReporters, isFalse);
      expect(registry.reporters, isEmpty);
    });

    test('registers and unregisters reporters', () async {
      final reporter = FakeFailureReporter();

      await registry.register(reporter);
      expect(registry.hasReporters, isTrue);
      expect(registry.reporters.length, 1);

      await registry.unregister('fake-reporter');
      expect(registry.hasReporters, isFalse);
    });

    test('throws on duplicate registration', () async {
      final reporter = FakeFailureReporter();

      await registry.register(reporter);

      expect(
        () => registry.register(FakeFailureReporter()),
        throwsA(isA<StateError>()),
      );
    });

    test('reportFailure is fire-and-forget when no reporters', () {
      // Should not throw
      registry.reportFailure(ServerFailure('test'));
    });

    test('reportFailure enqueues to queue', () async {
      final reporter = FakeFailureReporter();
      await registry.register(reporter);

      registry.reportFailure(ServerFailure('test error'));

      expect(registry.queue, isNotNull);
      expect(registry.queue!.length, 1);
    });

    test('flush sends queued reports', () async {
      registry.configure(flushInterval: const Duration(hours: 1));
      final reporter = FakeFailureReporter();
      await registry.register(reporter);

      registry.reportFailure(ServerFailure('error 1'));
      registry.reportFailure(NetworkFailure('error 2'));

      await registry.flush();

      expect(reporter.reportedBatches.length, 1);
      expect(reporter.reportedBatches[0].length, 2);
    });

    test('dispose flushes and clears', () async {
      registry.configure(flushInterval: const Duration(hours: 1));
      final reporter = FakeFailureReporter();
      await registry.register(reporter);

      registry.reportFailure(ServerFailure('test'));

      await registry.dispose();

      expect(registry.hasReporters, isFalse);
      expect(registry.queue, isNull);
      // Reporter should have received the report during flush
      expect(reporter.reportedBatches.length, 1);
    });

    test('configure sets queue parameters', () async {
      registry.configure(
        maxQueueSize: 100,
        maxBatchSize: 10,
        flushInterval: const Duration(seconds: 10),
        retryPolicy: const NoRetryPolicy(),
      );

      final reporter = FakeFailureReporter();
      await registry.register(reporter);

      expect(registry.queue, isNotNull);
      expect(registry.queue!.maxQueueSize, 100);
      expect(registry.queue!.maxBatchSize, 10);
    });
  });

  group('Integration: FailureReporter with RetryPolicy', () {
    late FailureReporterRegistry registry;

    setUp(() async {
      registry = FailureReporterRegistry.instance;
      await registry.reset();
    });

    tearDown(() async {
      await registry.reset();
    });

    test('retries on reporter failure then succeeds', () async {
      registry.configure(
        retryPolicy: const FixedIntervalRetryPolicy(
          interval: Duration(milliseconds: 10),
          maxRetries: 3,
        ),
        flushInterval: const Duration(hours: 1),
      );

      final reporter = FakeFailureReporter()
        ..shouldFail = true
        ..maxFails = 1; // Fail once then succeed

      await registry.register(reporter);

      registry.reportFailure(ServerFailure('test error'));
      await registry.flush();

      // Reporter should have retried and then succeeded
      expect(reporter.failCount, 1);
      expect(reporter.reportedBatches.length, 1);
    });

    test('gives up after maxRetries with NoRetryPolicy', () async {
      registry.configure(
        retryPolicy: const NoRetryPolicy(),
        flushInterval: const Duration(hours: 1),
      );

      final reporter = FakeFailureReporter()
        ..shouldFail = true
        ..maxFails = 999; // Always fail

      await registry.register(reporter);

      registry.reportFailure(ServerFailure('doomed error'));
      await registry.flush();

      // Should have tried once and given up
      expect(reporter.failCount, 1);
      expect(reporter.reportedBatches, isEmpty);
    });
  });
}
