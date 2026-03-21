import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/core/failure_report_store.dart';
import 'package:zuraffa/src/core/failure_report_queue.dart';

void main() {
  late String tempDir;
  late String filePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('failure_store_test').path;
    filePath = '$tempDir/zuraffa_failure_queue.json';
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('FailureReportStore', () {
    test('save and load roundtrip preserves all failure types', () async {
      final store = FailureReportStore(filePath: filePath);

      final reports = [
        FailureReport(
          failure: ServerFailure('Server error', statusCode: 500),
          timestamp: DateTime.utc(2024, 1, 15, 10, 30),
          stackTrace: StackTrace.current,
          attributes: {'usecase': 'GetProductUseCase'},
        ),
        FailureReport(
          failure: NetworkFailure('No internet'),
          timestamp: DateTime.utc(2024, 1, 15, 10, 31),
        ),
        FailureReport(
          failure: ValidationFailure(
            'Bad input',
            fieldErrors: {
              'email': ['Invalid format', 'Required'],
            },
          ),
          timestamp: DateTime.utc(2024, 1, 15, 10, 32),
        ),
        FailureReport(
          failure: NotFoundFailure(
            'Missing',
            resourceType: 'User',
            resourceId: 'u-123',
          ),
          timestamp: DateTime.utc(2024, 1, 15, 10, 33),
        ),
        FailureReport(
          failure: TimeoutFailure('Slow', timeout: const Duration(seconds: 30)),
          timestamp: DateTime.utc(2024, 1, 15, 10, 34),
        ),
        FailureReport(
          failure: UnauthorizedFailure('Token expired'),
          timestamp: DateTime.utc(2024, 1, 15, 10, 35),
        ),
        FailureReport(
          failure: ForbiddenFailure(
            'Access denied',
            requiredPermission: 'admin',
          ),
          timestamp: DateTime.utc(2024, 1, 15, 10, 36),
        ),
        FailureReport(
          failure: CacheFailure('Cache miss'),
          timestamp: DateTime.utc(2024, 1, 15, 10, 37),
        ),
        FailureReport(
          failure: ConflictFailure('Duplicate', conflictType: 'unique_key'),
          timestamp: DateTime.utc(2024, 1, 15, 10, 38),
        ),
        FailureReport(
          failure: PlatformFailure('OS error', code: 'ENOENT'),
          timestamp: DateTime.utc(2024, 1, 15, 10, 39),
        ),
        FailureReport(
          failure: UnknownFailure('Mystery error'),
          timestamp: DateTime.utc(2024, 1, 15, 10, 40),
        ),
      ];

      await store.save(reports);
      expect(File(filePath).existsSync(), isTrue);

      final loaded = await store.load();

      expect(loaded.length, equals(reports.length));

      // ServerFailure
      expect(loaded[0].failure, isA<ServerFailure>());
      expect(loaded[0].failure.message, equals('Server error'));
      expect((loaded[0].failure as ServerFailure).statusCode, equals(500));
      expect(loaded[0].timestamp, equals(DateTime.utc(2024, 1, 15, 10, 30)));
      expect(loaded[0].attributes!['usecase'], equals('GetProductUseCase'));
      expect(loaded[0].attributes!['failure.persisted'], equals('true'));
      expect(loaded[0].stackTrace, isNotNull);

      // NetworkFailure
      expect(loaded[1].failure, isA<NetworkFailure>());
      expect(loaded[1].failure.message, equals('No internet'));

      // ValidationFailure
      expect(loaded[2].failure, isA<ValidationFailure>());
      final valFailure = loaded[2].failure as ValidationFailure;
      expect(valFailure.fieldErrors!['email'], contains('Invalid format'));

      // NotFoundFailure
      expect(loaded[3].failure, isA<NotFoundFailure>());
      final nfFailure = loaded[3].failure as NotFoundFailure;
      expect(nfFailure.resourceType, equals('User'));
      expect(nfFailure.resourceId, equals('u-123'));

      // TimeoutFailure
      expect(loaded[4].failure, isA<TimeoutFailure>());
      final toFailure = loaded[4].failure as TimeoutFailure;
      expect(toFailure.timeout, equals(const Duration(seconds: 30)));

      // ForbiddenFailure
      expect(loaded[6].failure, isA<ForbiddenFailure>());
      final fbFailure = loaded[6].failure as ForbiddenFailure;
      expect(fbFailure.requiredPermission, equals('admin'));

      // ConflictFailure
      expect(loaded[8].failure, isA<ConflictFailure>());
      final cfFailure = loaded[8].failure as ConflictFailure;
      expect(cfFailure.conflictType, equals('unique_key'));

      // PlatformFailure
      expect(loaded[9].failure, isA<PlatformFailure>());
      final pfFailure = loaded[9].failure as PlatformFailure;
      expect(pfFailure.code, equals('ENOENT'));

      // File is cleared after load
      expect(File(filePath).existsSync(), isFalse);
    });

    test('load returns empty list for non-existent file', () async {
      final store = FailureReportStore(filePath: '$tempDir/nonexistent.json');
      final loaded = await store.load();
      expect(loaded, isEmpty);
    });

    test('load returns empty list for corrupted file', () async {
      final store = FailureReportStore(filePath: filePath);
      await File(filePath).writeAsString('not valid json!!!');

      final loaded = await store.load();
      expect(loaded, isEmpty);
      // Corrupted file should be cleaned up
      expect(File(filePath).existsSync(), isFalse);
    });

    test('load skips individual corrupted entries', () async {
      final store = FailureReportStore(filePath: filePath);
      final json =
          '[{"failureType":"ServerFailure","message":"ok","timestamp":"2024-01-15T10:30:00.000Z"},{"broken":true}]';
      await File(filePath).writeAsString(json);

      final loaded = await store.load();
      expect(loaded.length, equals(1));
      expect(loaded[0].failure.message, equals('ok'));
    });

    test('clear deletes the file', () async {
      final store = FailureReportStore(filePath: filePath);
      await File(filePath).create(recursive: true);
      await File(filePath).writeAsString('[]');

      expect(File(filePath).existsSync(), isTrue);
      await store.clear();
      expect(File(filePath).existsSync(), isFalse);
    });

    test('hasPersisted returns correct value', () async {
      final store = FailureReportStore(filePath: filePath);

      expect(store.hasPersisted, isFalse);

      await store.save([
        FailureReport(failure: ServerFailure('err'), timestamp: DateTime.now()),
      ]);

      expect(store.hasPersisted, isTrue);

      await store.clear();
      expect(store.hasPersisted, isFalse);
    });

    test('save empty list clears the file', () async {
      final store = FailureReportStore(filePath: filePath);

      // Save something first
      await store.save([
        FailureReport(failure: ServerFailure('err'), timestamp: DateTime.now()),
      ]);
      expect(File(filePath).existsSync(), isTrue);

      // Save empty list should clear
      await store.save([]);
      expect(File(filePath).existsSync(), isFalse);
    });

    test('unknown failure type deserializes as UnknownFailure', () async {
      final store = FailureReportStore(filePath: filePath);
      final json =
          '[{"failureType":"FutureFailureType","message":"from the future","timestamp":"2024-01-15T10:30:00.000Z"}]';
      await File(filePath).writeAsString(json);

      final loaded = await store.load();
      expect(loaded.length, equals(1));
      expect(loaded[0].failure, isA<UnknownFailure>());
      expect(loaded[0].failure.message, equals('from the future'));
      expect(
        loaded[0].attributes!['failure.original_type'],
        equals('FutureFailureType'),
      );
    });
  });

  group('FailureReportQueue with persistence', () {
    test('persists unflushed reports on dispose', () async {
      final store = FailureReportStore(filePath: filePath);
      final reporter = _FailingReporter();

      final queue = FailureReportQueue(
        reporters: [reporter],
        store: store,
        flushInterval: const Duration(hours: 1),
        retryPolicy: const NoRetryPolicy(),
      );

      queue.enqueue(
        FailureReport(
          failure: ServerFailure('persisted error', statusCode: 503),
          timestamp: DateTime.now(),
        ),
      );

      // Dispose — flush will fail, reports should be persisted
      await queue.dispose();

      expect(store.hasPersisted, isTrue);

      // Verify persisted content
      final loaded = await store.load();
      expect(loaded.length, equals(1));
      expect(loaded[0].failure.message, equals('persisted error'));
    });

    test('loads persisted reports on creation', () async {
      final store = FailureReportStore(filePath: filePath);

      // Pre-persist a report
      await store.save([
        FailureReport(
          failure: NetworkFailure('from last session'),
          timestamp: DateTime.now(),
          attributes: {'failure.persisted': 'true'},
        ),
      ]);

      final reporter = _TrackingReporter();
      final queue = FailureReportQueue(
        reporters: [reporter],
        store: store,
        flushInterval: const Duration(hours: 1),
        retryPolicy: const NoRetryPolicy(),
      );

      // Give async load + flush time to complete
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // The persisted report should have been loaded and auto-flushed
      expect(reporter.reportedMessages, contains('from last session'));
      await queue.dispose();
    });
  });
}

/// A reporter that always fails (for testing persistence on flush failure).
class _FailingReporter extends FailureReporter {
  @override
  String get id => 'failing-reporter';

  @override
  Future<void> reportBatch(List<FailureReport> reports) async {
    throw Exception('Simulated export failure');
  }
}

/// A reporter that tracks what it received.
class _TrackingReporter extends FailureReporter {
  final List<String> reportedMessages = [];

  @override
  String get id => 'tracking-reporter';

  @override
  Future<void> reportBatch(List<FailureReport> reports) async {
    for (final report in reports) {
      reportedMessages.add(report.failure.message);
    }
  }
}
