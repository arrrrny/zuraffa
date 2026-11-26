import 'package:zuraffa/zuraffa.dart';
import 'package:test/test.dart';

void main() {
  group('AppFailure', () {
    group('classifier appFailureFrom()', () {
      test('returns same instance if already AppFailure', () {
        final failure = networkFailure('test error');
        final result = appFailureFrom(failure);
        expect(identical(result, failure), isTrue);
      });

      test('creates NetworkFailure for socket exceptions', () {
        final error = Exception('SocketException: Connection refused');
        final failure = appFailureFrom(error);
        expect(failure, isA<NetworkFailure>());
      });

      test('creates NetworkFailure for connection errors', () {
        final error = Exception('Connection reset by peer');
        expect(appFailureFrom(error), isA<NetworkFailure>());
      });

      test('creates NetworkFailure for failed host lookup', () {
        final error = Exception('Failed host lookup');
        expect(appFailureFrom(error), isA<NetworkFailure>());
      });

      test('creates NetworkFailure for a bare no-address DNS exception', () {
        final error = Exception('No address associated with hostname');
        expect(appFailureFrom(error), isA<NetworkFailure>());
      });

      test('keeps 403 + validation as an authorization failure (v2 order)', () {
        final failure = appFailureFrom(
          Exception('HTTP 403 Forbidden: validation failed'),
        );
        expect(failure, isA<PolicyDeniedFailure>());
        expect((failure as PolicyDeniedFailure).reason, 'forbidden');
      });

      test('creates TimeoutFailure for timeout errors', () {
        final error = Exception('Request timed out');
        expect(appFailureFrom(error), isA<TimeoutFailure>());
      });

      test('creates TimeoutFailure for deadline exceeded', () {
        final error = Exception('Deadline exceeded');
        expect(appFailureFrom(error), isA<TimeoutFailure>());
      });

      test('creates NotFoundFailure for 404 errors', () {
        final error = Exception('HTTP 404 Not Found');
        expect(appFailureFrom(error), isA<NotFoundFailure>());
      });

      test('creates NotFoundFailure for "does not exist" errors', () {
        final error = Exception('Resource does not exist');
        expect(appFailureFrom(error), isA<NotFoundFailure>());
      });

      test('creates PolicyDeniedFailure for 401 errors', () {
        final error = Exception('HTTP 401 Unauthorized');
        expect(appFailureFrom(error), isA<PolicyDeniedFailure>());
      });

      test('creates PolicyDeniedFailure for token errors', () {
        final error = Exception('Token expired');
        expect(appFailureFrom(error), isA<PolicyDeniedFailure>());
      });

      test('creates PolicyDeniedFailure for 403 errors', () {
        final error = Exception('HTTP 403 Forbidden');
        expect(appFailureFrom(error), isA<PolicyDeniedFailure>());
      });

      test('creates NetworkFailure for 500 errors', () {
        final error = Exception('HTTP 500 Internal Server Error');
        expect(appFailureFrom(error), isA<NetworkFailure>());
      });

      test('creates NetworkFailure for 502 errors', () {
        final error = Exception('Bad Gateway 502');
        expect(appFailureFrom(error), isA<NetworkFailure>());
      });

      test('creates NetworkFailure for 503 errors', () {
        final error = Exception('Service Unavailable 503');
        expect(appFailureFrom(error), isA<NetworkFailure>());
      });

      test('creates UnexpectedFailure for unrecognized errors', () {
        final error = Exception('Something completely random happened');
        expect(appFailureFrom(error), isA<UnexpectedFailure>());
      });
    });

    group('NetworkFailure', () {
      test('stores message', () {
        final failure = networkFailure('No internet connection');
        expect(failure.message, equals('No internet connection'));
      });

      test('isRetryable defaults to false', () {
        final failure = networkFailure('Connection refused');
        expect(failure.isRetryable, isFalse);
      });

      test('toString returns generated format', () {
        final failure = networkFailure('Connection refused');
        expect(failure.toString(), contains('NetworkFailure'));
        expect(failure.toString(), contains('Connection refused'));
      });
    });

    group('StorageFailure', () {
      test('stores message', () {
        final failure = storageFailure('Cache miss');
        expect(failure.message, equals('Cache miss'));
      });

      test('layer defaults to cache', () {
        final failure = storageFailure('Cache corrupted');
        expect(failure.layer, equals('cache'));
      });

      test('toString returns generated format', () {
        final failure = storageFailure('Cache corrupted');
        expect(failure.toString(), contains('StorageFailure'));
        expect(failure.toString(), contains('Cache corrupted'));
      });
    });

    group('BoundaryViolationFailure', () {
      test('stores violations', () {
        final failure = boundaryViolationFailure(
          'Validation failed',
          violations: const [
            FieldViolation(path: '/email', expected: 'string', actual: 'bad'),
            FieldViolation(path: '/password', expected: 'string', actual: ''),
          ],
        );
        expect(failure.violations, hasLength(2));
        expect(failure.violations.first.path, equals('/email'));
      });

      test('toString works without violations', () {
        final failure = boundaryViolationFailure('Validation failed');
        expect(failure.toString(), contains('BoundaryViolationFailure'));
        expect(failure.toString(), contains('Validation failed'));
      });

      test('escapes legacy field names as one JSON Pointer token', () {
        final failure = boundaryViolationFailure(
          'Validation failed',
          fieldErrors: const {
            'a/b': ['bad'],
            '~1': ['collision'],
          },
        );
        expect(failure.violations.map((v) => v.path).toList(), [
          '/a~1b',
          '/~01',
        ]);
      });
    });

    group('NotFoundFailure', () {
      test('stores resourceId and resourceType', () {
        final failure = notFoundFailure(
          'User not found',
          resourceId: '123',
          resourceType: 'User',
        );
        expect(failure.resourceId, equals('123'));
        expect(failure.resourceType, equals('User'));
      });

      test('toString works without resource info', () {
        final failure = notFoundFailure('Resource not found');
        expect(failure.toString(), contains('NotFoundFailure'));
        expect(failure.toString(), contains('Resource not found'));
      });
    });

    group('PolicyDeniedFailure', () {
      test('stores message', () {
        final failure = policyDeniedFailure('Token expired');
        expect(failure.message, equals('Token expired'));
      });

      test('reason defaults to permission', () {
        final failure = policyDeniedFailure('Access denied');
        expect(failure.reason, equals('permission'));
      });

      test('accepts an explicit reason', () {
        final failure = policyDeniedFailure(
          'Access denied',
          reason: 'forbidden',
        );
        expect(failure.reason, equals('forbidden'));
      });

      test('explicit reason beats a policy rule', () {
        final failure = policyDeniedFailure(
          'Denied',
          reason: 'forbidden',
          policyRule: 'maxCascadeDepth',
        );
        expect(failure.reason, equals('forbidden'));
      });

      test('cascade rules map to cascadeDepth before other rules', () {
        expect(
          policyDeniedFailure('Denied', policyRule: 'maxCascadeDepth').reason,
          'cascadeDepth',
        );
        expect(
          policyDeniedFailure('Denied', policyRule: 'dailyQuota').reason,
          'dailyQuota',
        );
      });
    });

    group('ConflictFailure', () {
      test('stores message', () {
        final failure = conflictFailure('Duplicate entry');
        expect(failure.message, equals('Duplicate entry'));
      });

      test('toString returns generated format', () {
        final failure = conflictFailure('Version conflict');
        expect(failure.toString(), contains('ConflictFailure'));
        expect(failure.toString(), contains('Version conflict'));
      });
    });

    group('TimeoutFailure', () {
      test('stores timeout duration', () {
        final failure = timeoutFailure(
          'Request timed out',
          timeout: const Duration(seconds: 30),
        );
        expect(failure.timeout, equals(const Duration(seconds: 30)));
      });

      test('isRetryable defaults to true', () {
        final failure = timeoutFailure('Request timed out');
        expect(failure.isRetryable, isTrue);
      });
    });

    group('CancelledFailure', () {
      test('has default message', () {
        final failure = cancelledFailure();
        expect(failure.message, equals('Operation was cancelled'));
      });

      test('accepts custom message', () {
        final failure = cancelledFailure('User cancelled');
        expect(failure.message, equals('User cancelled'));
      });
    });

    group('InterruptedFailure', () {
      test('stores intentDigest', () {
        final failure = interruptedFailure(
          'Interrupted',
          intentDigest: 'abc123',
        );
        expect(failure.intentDigest, equals('abc123'));
      });
    });

    group('UnexpectedFailure', () {
      test('stores message', () {
        final failure = unexpectedFailure('Something went wrong');
        expect(failure.message, equals('Something went wrong'));
      });
    });

    group('ExceptionToFailure extension', () {
      test('converts Exception to AppFailure', () {
        final exception = Exception('Test error');
        final failure = exception.toFailure();
        expect(failure, isA<AppFailure>());
        expect(failure.message, contains('Test error'));
      });
    });

    group('ErrorToFailure extension', () {
      test('converts Error to AppFailure', () {
        final error = ArgumentError('Invalid argument');
        final failure = error.toFailure();
        expect(failure, isA<AppFailure>());
        expect(failure.message, contains('Invalid argument'));
      });
    });

    group('sealed class exhaustiveness', () {
      test('all ten variants can be matched in a switch', () {
        final failures = <AppFailure>[
          networkFailure('test'),
          timeoutFailure('test'),
          boundaryViolationFailure('test'),
          policyDeniedFailure('test'),
          notFoundFailure('test'),
          conflictFailure('test'),
          cancelledFailure('test'),
          interruptedFailure('test'),
          storageFailure('test'),
          unexpectedFailure('test'),
        ];

        for (final failure in failures) {
          final kind = switch (failure) {
            NetworkFailure() => 'network',
            TimeoutFailure() => 'timeout',
            BoundaryViolationFailure() => 'boundaryViolation',
            PolicyDeniedFailure() => 'policyDenied',
            NotFoundFailure() => 'notFound',
            ConflictFailure() => 'conflict',
            CancelledFailure() => 'cancelled',
            InterruptedFailure() => 'interrupted',
            StorageFailure() => 'storage',
            UnexpectedFailure() => 'unexpected',
          };
          expect(kind, isNotEmpty);
        }
      });
    });

    group('wire round-trip', () {
      test('AppFailure.fromWire(failure.toWire()) round-trips a variant', () {
        final original = notFoundFailure(
          'User not found',
          resourceId: '123',
          resourceType: 'User',
        );
        final decoded = AppFailure.fromWire(original.toWire());
        expect(decoded, isA<BoundaryOk<AppFailure>>());
        final value = (decoded as BoundaryOk<AppFailure>).value;
        expect(value, isA<NotFoundFailure>());
        expect((value as NotFoundFailure).resourceId, equals('123'));
      });

      // Every variant must survive the trust boundary with its shared fields
      // (message, traceId, isRetryable) and its variant-specific fields
      // intact — not just NotFoundFailure (#2179 review finding).
      test('round-trips all ten variants with variant-specific fields', () {
        AppFailure roundTrip(AppFailure original) {
          final decoded = AppFailure.fromWire(original.toWire());
          expect(
            decoded,
            isA<BoundaryOk<AppFailure>>(),
            reason: '${original.runtimeType} failed to decode',
          );
          return (decoded as BoundaryOk<AppFailure>).value;
        }

        final originals = <AppFailure>[
          networkFailure(
            'net',
            statusCode: 503,
            traceId: 'trace-network',
            isRetryable: true,
          ),
          timeoutFailure(
            'slow',
            timeout: const Duration(seconds: 2),
            traceId: 'trace-timeout',
            isRetryable: false,
          ),
          boundaryViolationFailure(
            'bad input',
            violations: const [
              FieldViolation(path: '/name', expected: 'string', actual: 'int'),
            ],
            traceId: 'trace-boundary',
            isRetryable: true,
          ),
          policyDeniedFailure(
            'denied',
            reason: 'forbidden',
            traceId: 'trace-policy',
            isRetryable: true,
          ),
          notFoundFailure(
            'missing',
            resourceType: 'User',
            resourceId: '42',
            traceId: 'trace-notfound',
            isRetryable: true,
          ),
          conflictFailure(
            'clash',
            localPatchWire: const {'local': 1},
            remotePatchWire: const {'remote': 2},
            traceId: 'trace-conflict',
            isRetryable: true,
          ),
          CancelledFailure.fromTrusted(
            message: 'stopped',
            traceId: 'trace-cancelled',
            isRetryable: true,
          ),
          interruptedFailure(
            'halted',
            intentDigest: 'digest',
            traceId: 'trace-interrupted',
            isRetryable: false,
          ),
          storageFailure(
            'cache miss',
            layer: 'database',
            traceId: 'trace-storage',
            isRetryable: true,
          ),
          unexpectedFailure(
            'boom',
            cause: 'bad state',
            stackTrace: StackTrace.fromString('#0 boom'),
            traceId: 'trace-unexpected',
            isRetryable: true,
          ),
        ];

        final decoded = [for (final original in originals) roundTrip(original)];
        expect(decoded.length, 10);
        for (var i = 0; i < originals.length; i++) {
          expect(decoded[i].runtimeType, originals[i].runtimeType);
          expect(decoded[i].message, originals[i].message);
          expect(decoded[i].traceId, originals[i].traceId);
          expect(decoded[i].isRetryable, originals[i].isRetryable);
        }

        expect((decoded[0] as NetworkFailure).statusCode, 503);
        expect(
          (decoded[1] as TimeoutFailure).timeout,
          const Duration(seconds: 2),
        );
        final violation =
            (decoded[2] as BoundaryViolationFailure).violations.single;
        expect(violation.path, '/name');
        expect(violation.expected, 'string');
        expect(violation.actual, 'int');
        expect((decoded[3] as PolicyDeniedFailure).reason, 'forbidden');
        final notFound = decoded[4] as NotFoundFailure;
        expect(notFound.resourceType, 'User');
        expect(notFound.resourceId, '42');
        final conflict = decoded[5] as ConflictFailure;
        expect(conflict.localPatchWire, {'local': 1});
        expect(conflict.remotePatchWire, {'remote': 2});
        expect((decoded[7] as InterruptedFailure).intentDigest, 'digest');
        expect((decoded[8] as StorageFailure).layer, 'database');
        final unexpected = decoded[9] as UnexpectedFailure;
        expect(unexpected.cause, 'bad state');
        expect(unexpected.stackTrace, contains('boom'));
      });
    });
  });
}
