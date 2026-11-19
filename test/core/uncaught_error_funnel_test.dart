import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// A [FailureReporter] that records every batch it is handed, so a test can
/// assert that an uncaught error produced a failure-span queue entry.
class _RecordingReporter extends FailureReporter {
  final List<List<FailureReport>> batches = [];

  @override
  String get id => 'uncaught-funnel-test';

  @override
  Future<void> reportBatch(List<FailureReport> reports) async {
    batches.add(List.from(reports));
  }
}

/// A [Logger] listener that records every record it sees.
class _RecordingLogListener {
  final List<LogRecord> records = [];

  StreamSubscription<LogRecord>? _subscription;

  void start() {
    _subscription = Logger.root.onRecord.listen(records.add);
  }

  Future<void> stop() => _subscription?.cancel() ?? Future<void>.value();
}

void main() {
  group('UncaughtErrorFunnel', () {
    late _RecordingLogListener logListener;
    late _RecordingReporter reporter;

    setUp(() async {
      logListener = _RecordingLogListener()..start();
      reporter = _RecordingReporter();
      await FailureReporterRegistry.instance.reset();
      await FailureReporterRegistry.instance.register(reporter);
    });

    tearDown(() async {
      await logListener.stop();
      await FailureReporterRegistry.instance.reset();
    });

    test('captureUncaught logs a SEVERE record with error + stackTrace', () {
      final error = StateError('boom');
      final stackTrace = StackTrace.current;

      UncaughtErrorFunnel.captureUncaught(error, stackTrace);

      final record = logListener.records.last;
      expect(record.level, Level.SEVERE);
      expect(record.error, same(error));
      expect(record.stackTrace, same(stackTrace));
    });

    test('captureUncaught honors a custom context', () {
      UncaughtErrorFunnel.captureUncaught(
        StateError('boom'),
        StackTrace.current,
        context: 'Widget build failed',
      );

      expect(logListener.records.last.message, 'Widget build failed');
    });

    test('captureUncaught defaults context to Uncaught error', () {
      UncaughtErrorFunnel.captureUncaught(StateError('x'), StackTrace.current);
      expect(logListener.records.last.message, 'Uncaught error');
    });

    test('captureUncaught enqueues a failure span by default', () async {
      UncaughtErrorFunnel.captureUncaught(
        StateError('boom'),
        StackTrace.current,
      );

      // reportFailure is fire-and-forget: flush the queue to deliver.
      await FailureReporterRegistry.instance.flush();

      expect(reporter.batches, isNotEmpty);
      final failure = reporter.batches.first.first.failure;
      expect(failure.message, contains('boom'));
    });

    test(
      'captureUncaught skips the failure span when reportAsFailure false',
      () async {
        UncaughtErrorFunnel.captureUncaught(
          StateError('boom'),
          StackTrace.current,
          reportAsFailure: false,
        );

        await FailureReporterRegistry.instance.flush();

        expect(reporter.batches, isEmpty);
      },
    );

    test('runGuarded funnels an async error to captureUncaught', () async {
      final errors = <Object>[];
      final stackTraces = <StackTrace>[];

      UncaughtErrorFunnel.runGuarded(
        () async {
          // A fire-and-forget future that completes with an error.
          Future<void>.error(StateError('async boom'));
        },
        onError: (error, stackTrace) {
          errors.add(error);
          stackTraces.add(stackTrace);
        },
      );

      // Give the microtask queue a turn to deliver the error to the zone.
      await Future<void>.delayed(Duration.zero);

      expect(errors, isNotEmpty);
      expect(errors.first, isA<StateError>());
      expect((errors.first as StateError).message, 'async boom');
      expect(stackTraces, isNotEmpty);
    });

    test('runGuarded defaults onError to captureUncaught', () async {
      UncaughtErrorFunnel.runGuarded(() async {
        Future<void>.error(StateError('funnel boom'));
      });

      await Future<void>.delayed(Duration.zero);

      final record = logListener.records.last;
      expect(record.level, Level.SEVERE);
      expect(record.error, isA<StateError>());
      expect((record.error as StateError).message, 'funnel boom');
    });

    test('runGuarded surfaces a synchronous throw from body', () async {
      Object? caught;

      UncaughtErrorFunnel.runGuarded(() {
        throw StateError('sync boom');
      }, onError: (error, _) => caught = error);

      expect(caught, isA<StateError>());
      expect((caught as StateError).message, 'sync boom');
    });

    test(
      'installUncaughtErrorHandlers is idempotent and exposes a flag',
      () async {
        expect(UncaughtErrorFunnel.isInstalled, isFalse);

        UncaughtErrorFunnel.installUncaughtErrorHandlers();
        expect(UncaughtErrorFunnel.isInstalled, isTrue);

        // A second call must not throw or double-install.
        UncaughtErrorFunnel.installUncaughtErrorHandlers(
          reportAsFailure: false,
        );
        expect(UncaughtErrorFunnel.reportUncaughtAsFailure, isFalse);
      },
    );

    test(
      'isolateErrorPort forwards a spawned isolate uncaught error',
      () async {
        UncaughtErrorFunnel.installUncaughtErrorHandlers();

        // Spawn an isolate that throws; route its uncaught error to the funnel.
        final isolate = await Isolate.spawn<Object>(
          (message) => throw StateError('isolate boom'),
          'unused',
          onError: UncaughtErrorFunnel.isolateErrorPort,
          errorsAreFatal: false,
        );

        // The funnel listens on the isolate error port and forwards to
        // captureUncaught; observe via a one-shot log listener snapshot.
        final before = logListener.records.length;
        await Future<void>.delayed(const Duration(milliseconds: 200));

        isolate.kill(priority: Isolate.immediate);

        // The funnel logged the isolate error at SEVERE. A non-sendable error
        // (StateError) crosses the isolate boundary as its toString(), so the
        // record carries the message text rather than the error object.
        final newRecords = logListener.records.skip(before);
        expect(
          newRecords.any(
            (r) =>
                r.level == Level.SEVERE &&
                r.error.toString().contains('isolate boom'),
          ),
          isTrue,
          reason: 'isolate uncaught error should reach the funnel',
        );
      },
    );
  });
}
