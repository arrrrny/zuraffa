import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
      final exception = TimeoutException('Connection timed out', const Duration(seconds: 5));
      final failure = dataSource.handleError(exception);

      expect(failure, isA<TimeoutFailure>());
      expect((failure as TimeoutFailure).message, 'Connection timed out');
      expect(failure.timeout, const Duration(seconds: 5));
    });

    test('handleError should convert FormatException to ValidationFailure', () {
      final exception = FormatException('Invalid format');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Invalid format');
    });

    test('handleError should convert ArgumentError to ValidationFailure', () {
      final exception = ArgumentError('Invalid argument');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Invalid argument');
    });

    test('handleError should convert CancelledException to CancellationFailure', () {
      final exception = CancelledException('Request cancelled');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<CancellationFailure>());
      expect(failure.message, 'Request cancelled');
    });

    test('handleError should convert RangeError to ValidationFailure', () {
      final exception = RangeError('Value too large');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('Value out of range'));
    });

    test('handleError should convert IndexError to ValidationFailure', () {
      final exception = IndexError(10, []);
      final failure = dataSource.handleError(exception);

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Index out of bounds');
    });

    test('handleError should convert StateError to StateFailure', () {
      final exception = StateError('Bad state');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<StateFailure>());
      expect(failure.message, 'Bad state');
    });

    test('handleError should convert UnimplementedError to UnimplementedFailure', () {
      final exception = UnimplementedError();
      final failure = dataSource.handleError(exception);

      expect(failure, isA<UnimplementedFailure>());
      expect(failure.message, 'Feature not implemented');
    });

    test('handleError should convert UnsupportedError to UnsupportedFailure', () {
      final exception = UnsupportedError('Feature not supported');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<UnsupportedFailure>());
      expect(failure.message, 'Feature not supported');
    });

    test('handleError should convert TypeError to TypeFailure', () {
      try {
        throw ArgumentError(); // Dummy error to catch
      } catch (e) {
        // We can't easily instantiate TypeError as it is private/internal in unexpected ways sometimes,
        // but we can simulate handling one if we cast something invalid.
        // Or cleaner: just manually call handleError with a mock or if we can use a known TypeError scenario.
        // Actually, let's just use the behavior of the mixin which calculates it from `error is TypeError`.
        // Dart's TypeError is an Error.
      }
      // Simulating a TypeError is tricky in test code without actually causing one.
      // Let's create a real TypeError.
      Object x = 1;
      try {
        // ignore: unused_local_variable
        String s = x as String;
      } catch (e) {
        final failure = dataSource.handleError(e);
        expect(failure, isA<TypeFailure>());
        expect(failure.message, contains('Type error:'));
      }
    });

    test('handleError should convert PlatformException to PlatformFailure', () {
      final exception = PlatformException(code: 'ERROR', message: 'Platform error');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<PlatformFailure>());
      expect((failure as PlatformFailure).code, 'ERROR');
      expect(failure.message, 'Platform error');
    });

    test('handleError should convert MissingPluginException to UnsupportedFailure', () {
      final exception = MissingPluginException('Plugin not present');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<UnsupportedFailure>());
      expect(failure.message, 'Plugin not present');
    });

    test('handleError should convert ConcurrentModificationError to StateFailure', () {
      final exception = ConcurrentModificationError();
      final failure = dataSource.handleError(exception);

      expect(failure, isA<StateFailure>());
      expect(failure.message, 'Concurrent modification detected');
    });

    test('handleError should check for NoSuchMethodError and convert to TypeFailure', () {
       try {
         // Create a real NoSuchMethodError
         dynamic d = 1;
         d.substring(0);
       } catch (e) {
         final failure = dataSource.handleError(e);
         expect(failure, isA<TypeFailure>());
         expect(failure.message, contains('No such method'));
       }
    });

    test('handleError should use AppFailure.from for unknown exceptions', () {
      final exception = Exception('Unknown error');
      final failure = dataSource.handleError(exception);

      expect(failure, isA<UnknownFailure>());
      expect(failure.message, 'Exception: Unknown error');
    });
  });
}
