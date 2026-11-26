import 'dart:async';

import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'package:zuraffa/zuraffa.dart';

class TestDataSource with Loggable, FailureHandler {
  @override
  Logger get logger => Logger('TestDataSource');
}

void main() {
  late TestDataSource dataSource;

  setUp(() {
    dataSource = TestDataSource();
  });

  group('FailureHandler', () {
    test('handleError should convert TimeoutException to TimeoutFailure', () {
      final exception = TimeoutException(
        'Connection timed out',
        const Duration(seconds: 5),
      );
      final failure = dataSource.handleError(exception);

      expect(failure, isA<TimeoutFailure>());
      expect((failure as TimeoutFailure).message, 'Connection timed out');
      expect(failure.timeout, const Duration(seconds: 5));
    });

    test(
      'handleError should convert FormatException to BoundaryViolationFailure',
      () {
        final exception = FormatException('Invalid format');
        final failure = dataSource.handleError(exception);

        expect(failure, isA<BoundaryViolationFailure>());
        expect(failure.message, 'Invalid format');
      },
    );

    test(
      'handleError should convert ArgumentError to BoundaryViolationFailure',
      () {
        final exception = ArgumentError('Invalid argument');
        final failure = dataSource.handleError(exception);

        expect(failure, isA<BoundaryViolationFailure>());
        expect(failure.message, 'Invalid argument');
      },
    );

    test(
      'handleError should convert CancelledException to CancelledFailure',
      () {
        final exception = CancelledException('Request cancelled');
        final failure = dataSource.handleError(exception);

        expect(failure, isA<CancelledFailure>());
        expect(failure.message, 'Request cancelled');
      },
    );

    test(
      'handleError should convert RangeError to BoundaryViolationFailure',
      () {
        final exception = RangeError('Value too large');
        final failure = dataSource.handleError(exception);

        expect(failure, isA<BoundaryViolationFailure>());
        expect(failure.message, contains('Value out of range'));
      },
    );

    test(
      'handleError should convert IndexError to BoundaryViolationFailure',
      () {
        final exception = IndexError(10, []);
        final failure = dataSource.handleError(exception);

        expect(failure, isA<BoundaryViolationFailure>());
        expect(failure.message, 'Index out of bounds');
      },
    );

    test('handleError should convert StateError to UnexpectedFailure', () {
      final exception = StateError('Bad state');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.message, 'Bad state');
    });

    test(
      'handleError should convert UnimplementedError to UnexpectedFailure',
      () {
        final exception = UnimplementedError();
        final failure = dataSource.handleError(exception);

        expect(failure, isA<UnexpectedFailure>());
        expect(failure.message, 'Feature not implemented');
      },
    );

    test(
      'handleError should convert UnsupportedError to UnexpectedFailure',
      () {
        final exception = UnsupportedError('Feature not supported');
        final failure = dataSource.handleError(exception);

        expect(failure, isA<UnexpectedFailure>());
        expect(failure.message, 'Feature not supported');
      },
    );

    test('handleError should convert TypeError to UnexpectedFailure', () {
      Object x = 1;
      try {
        // ignore: unused_local_variable
        String s = x as String;
      } catch (e) {
        final failure = dataSource.handleError(e);
        expect(failure, isA<UnexpectedFailure>());
        expect(failure.message, contains('Type error:'));
      }
    });

    test(
      'handleError should convert ZuraffaPlatformException to UnexpectedFailure',
      () {
        final exception = ZuraffaPlatformException(
          code: 'ERROR',
          message: 'Platform error',
        );
        final failure = dataSource.handleError(exception);

        expect(failure, isA<UnexpectedFailure>());
        expect(failure.message, 'Platform error');
      },
    );

    test(
      'handleError should convert ZuraffaMissingPluginException to UnexpectedFailure',
      () {
        final exception = ZuraffaMissingPluginException('Plugin not present');
        final failure = dataSource.handleError(exception);

        expect(failure, isA<UnexpectedFailure>());
        expect(failure.message, 'Plugin not present');
      },
    );

    test(
      'handleError should convert ConcurrentModificationError to UnexpectedFailure',
      () {
        final exception = ConcurrentModificationError();
        final failure = dataSource.handleError(exception);

        expect(failure, isA<UnexpectedFailure>());
        expect(failure.message, 'Concurrent modification detected');
      },
    );

    test(
      'handleError should check for NoSuchMethodError and convert to UnexpectedFailure',
      () {
        try {
          dynamic d = 1;
          d.substring(0);
        } catch (e) {
          final failure = dataSource.handleError(e);
          expect(failure, isA<UnexpectedFailure>());
          expect(failure.message, contains('No such method'));
        }
      },
    );

    test('handleError should use AppFailure.from for unknown exceptions', () {
      final exception = Exception('Unknown error');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.message, 'Exception: Unknown error');
    });

    test('folded StateError keeps its cause and supplied stack trace', () {
      final stack = StackTrace.fromString('#0 the original throw site');
      final failure = dataSource.handleError(StateError('bad state'), stack);

      expect(failure, isA<UnexpectedFailure>());
      final unexpected = failure as UnexpectedFailure;
      expect(unexpected.cause, contains('Bad state: bad state'));
      expect(unexpected.stackTrace, contains('original throw site'));
    });

    test('handler timeout matches the top-level helper retry semantics', () {
      final failure =
          dataSource.handleError(
                TimeoutException('too slow', const Duration(seconds: 1)),
              )
              as TimeoutFailure;
      expect(
        failure.isRetryable,
        AppFailure.timeout(message: 'test').isRetryable,
      );
    });

    test('an ArgumentError becomes a boundary violation naming the field', () {
      final failure = dataSource.handleError(
        ArgumentError.value(-1, 'count', 'must be positive'),
      );
      expect(failure, isA<BoundaryViolationFailure>());
      final violation = (failure as BoundaryViolationFailure).violations.single;
      expect(violation.path, '/count');
      expect(violation.actual, '-1');
      expect(failure.message, contains('must be positive'));
    });
  });
}
