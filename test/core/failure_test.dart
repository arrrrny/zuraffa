import 'package:zuraffa/zuraffa.dart';
import 'package:test/test.dart';

void main() {
  group('AppFailure', () {
    group('classifier AppFailure.from()', () {
      test('returns same instance if already AppFailure', () {
        final failure = AppFailure.network(message: 'test error');
        final result = AppFailure.from(failure);
        expect(identical(result, failure), isTrue);
      });

      test('creates NetworkFailure for socket exceptions', () {
        final error = Exception('SocketException: Connection refused');
        final failure = AppFailure.from(error);
        expect(failure, isA<NetworkFailure>());
      });

      test('creates NetworkFailure for connection errors', () {
        final error = Exception('Connection reset by peer');
        expect(AppFailure.from(error), isA<NetworkFailure>());
      });

      test('creates NetworkFailure for failed host lookup', () {
        final error = Exception('Failed host lookup');
        expect(AppFailure.from(error), isA<NetworkFailure>());
      });

      test('creates NetworkFailure for a bare no-address DNS exception', () {
        final error = Exception('No address associated with hostname');
        expect(AppFailure.from(error), isA<NetworkFailure>());
      });

      test('keeps 403 + validation as an authorization failure (v2 order)', () {
        final failure = AppFailure.from(
          Exception('HTTP 403 Forbidden: validation failed'),
        );
        expect(failure, isA<PolicyDeniedFailure>());
        expect((failure as PolicyDeniedFailure).reason, 'forbidden');
      });

      test('creates TimeoutFailure for timeout errors', () {
        final error = Exception('Request timed out');
        expect(AppFailure.from(error), isA<TimeoutFailure>());
      });

      test('creates TimeoutFailure for deadline exceeded', () {
        final error = Exception('Deadline exceeded');
        expect(AppFailure.from(error), isA<TimeoutFailure>());
      });

      test('creates NotFoundFailure for 404 errors', () {
        final error = Exception('HTTP 404 Not Found');
        expect(AppFailure.from(error), isA<NotFoundFailure>());
      });

      test('creates NotFoundFailure for "does not exist" errors', () {
        final error = Exception('Resource does not exist');
        expect(AppFailure.from(error), isA<NotFoundFailure>());
      });

      test('creates PolicyDeniedFailure for 401 errors', () {
        final error = Exception('HTTP 401 Unauthorized');
        expect(AppFailure.from(error), isA<PolicyDeniedFailure>());
      });

      test('creates PolicyDeniedFailure for token errors', () {
        final error = Exception('Token expired');
        expect(AppFailure.from(error), isA<PolicyDeniedFailure>());
      });

      test('creates PolicyDeniedFailure for 403 errors', () {
        final error = Exception('HTTP 403 Forbidden');
        expect(AppFailure.from(error), isA<PolicyDeniedFailure>());
      });

      test('creates NetworkFailure for 500 errors', () {
        final error = Exception('HTTP 500 Internal Server Error');
        expect(AppFailure.from(error), isA<NetworkFailure>());
      });

      test('creates NetworkFailure for 502 errors', () {
        final error = Exception('Bad Gateway 502');
        expect(AppFailure.from(error), isA<NetworkFailure>());
      });

      test('creates NetworkFailure for 503 errors', () {
        final error = Exception('Service Unavailable 503');
        expect(AppFailure.from(error), isA<NetworkFailure>());
      });

      test('creates UnexpectedFailure for unrecognized errors', () {
        final error = Exception('Something completely random happened');
        expect(AppFailure.from(error), isA<UnexpectedFailure>());
      });
    });

    group('NetworkFailure', () {
      test('stores message', () {
        final failure = AppFailure.network(message: 'No internet connection');
        expect(failure.message, equals('No internet connection'));
      });

      test('isRetryable defaults to false', () {
        final failure = AppFailure.network(message: 'Connection refused');
        expect(failure.isRetryable, isFalse);
      });

      test('toString returns generated format', () {
        final failure = AppFailure.network(message: 'Connection refused');
        expect(failure.toString(), contains('NetworkFailure'));
        expect(failure.toString(), contains('Connection refused'));
      });
    });

    group('StorageFailure', () {
      test('stores message', () {
        final failure = AppFailure.storage(message: 'Cache miss');
        expect(failure.message, equals('Cache miss'));
      });

      test('layer defaults to cache', () {
        final failure = AppFailure.storage(message: 'Cache corrupted');
        expect((failure as StorageFailure).layer, equals('cache'));
      });

      test('toString returns generated format', () {
        final failure = AppFailure.storage(message: 'Cache corrupted');
        expect(failure.toString(), contains('StorageFailure'));
        expect(failure.toString(), contains('Cache corrupted'));
      });
    });

    group('BoundaryViolationFailure', () {
      test('stores violations', () {
        final failure = AppFailure.boundaryViolation(
          message: 'Validation failed',
          violations: const [
            FieldViolation(path: '/email', expected: 'string', actual: 'bad'),
            FieldViolation(path: '/password', expected: 'string', actual: ''),
          ],
        );
        expect((failure as BoundaryViolationFailure).violations, hasLength(2));
        expect(failure.violations.first.path, equals('/email'));
      });

      test('toString works without violations', () {
        final failure = AppFailure.boundaryViolation(
          message: 'Validation failed',
        );
        expect(failure.toString(), contains('BoundaryViolationFailure'));
        expect(failure.toString(), contains('Validation failed'));
      });

      test('carries violations with JSON Pointer paths verbatim', () {
        // Pointer escaping (`/` -> `~1`, `~` -> `~0`) is the CALLER's contract
        // in v8 — the variant stores what it is given.
        const violations = [
          FieldViolation(path: '/a~1b', expected: 'string', actual: 'bad'),
          FieldViolation(path: '/~01', expected: 'string', actual: 'collision'),
        ];
        final failure = AppFailure.boundaryViolation(
          message: 'Validation failed',
          violations: violations,
        );
        expect((failure as BoundaryViolationFailure).violations, violations);
      });
    });

    group('NotFoundFailure', () {
      test('stores resourceId and resourceType', () {
        final failure = AppFailure.notFound(
          message: 'User not found',
          resourceId: '123',
          resourceType: 'User',
        );
        expect((failure as NotFoundFailure).resourceId, equals('123'));
        expect(failure.resourceType, equals('User'));
      });

      test('toString works without resource info', () {
        final failure = AppFailure.notFound(message: 'Resource not found');
        expect(failure.toString(), contains('NotFoundFailure'));
        expect(failure.toString(), contains('Resource not found'));
      });
    });

    group('PolicyDeniedFailure', () {
      test('stores message', () {
        final failure = AppFailure.policyDenied(message: 'Token expired');
        expect(failure.message, equals('Token expired'));
      });

      test('reason defaults to permission', () {
        final failure = AppFailure.policyDenied(message: 'Access denied');
        expect((failure as PolicyDeniedFailure).reason, equals('permission'));
      });

      test('accepts an explicit reason', () {
        final failure = AppFailure.policyDenied(
          message: 'Access denied',
          reason: 'forbidden',
        );
        expect((failure as PolicyDeniedFailure).reason, equals('forbidden'));
      });

      test('a rule name is carried as the reason verbatim', () {
        final failure = AppFailure.policyDenied(
          message: 'Denied',
          reason: 'maxCascadeDepth',
        );
        expect(
          (failure as PolicyDeniedFailure).reason,
          equals('maxCascadeDepth'),
        );
      });
    });

    group('ConflictFailure', () {
      test('stores message', () {
        final failure = AppFailure.conflict(message: 'Duplicate entry');
        expect(failure.message, equals('Duplicate entry'));
      });

      test('toString returns generated format', () {
        final failure = AppFailure.conflict(message: 'Version conflict');
        expect(failure.toString(), contains('ConflictFailure'));
        expect(failure.toString(), contains('Version conflict'));
      });
    });

    group('TimeoutFailure', () {
      test('stores timeout duration', () {
        final failure = AppFailure.timeout(
          message: 'Request timed out',
          timeout: const Duration(seconds: 30),
        );
        expect(
          (failure as TimeoutFailure).timeout,
          equals(const Duration(seconds: 30)),
        );
      });

      test('isRetryable defaults to true', () {
        final failure = AppFailure.timeout(message: 'Request timed out');
        expect(failure.isRetryable, isTrue);
      });
    });

    group('CancelledFailure', () {
      test('has default message', () {
        final failure = AppFailure.cancelled(
          message: 'Operation was cancelled',
        );
        expect(failure.message, equals('Operation was cancelled'));
      });

      test('accepts custom message', () {
        final failure = AppFailure.cancelled(message: 'User cancelled');
        expect(failure.message, equals('User cancelled'));
      });
    });

    group('InterruptedFailure', () {
      test('stores intentDigest', () {
        final failure = AppFailure.interrupted(
          message: 'Interrupted',
          intentDigest: 'abc123',
        );
        expect((failure as InterruptedFailure).intentDigest, equals('abc123'));
      });
    });

    group('UnexpectedFailure', () {
      test('stores message', () {
        final failure = AppFailure.unexpected(message: 'Something went wrong');
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
          AppFailure.network(message: 'test'),
          AppFailure.timeout(message: 'test'),
          AppFailure.boundaryViolation(message: 'test'),
          AppFailure.policyDenied(message: 'test'),
          AppFailure.notFound(message: 'test'),
          AppFailure.conflict(message: 'test'),
          AppFailure.cancelled(message: 'test'),
          AppFailure.interrupted(message: 'test'),
          AppFailure.storage(message: 'test'),
          AppFailure.unexpected(message: 'test'),
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
        final original = AppFailure.notFound(
          message: 'User not found',
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
          AppFailure.network(
            message: 'net',
            statusCode: 503,
            traceId: 'trace-network',
            isRetryable: true,
          ),
          AppFailure.timeout(
            message: 'slow',
            timeout: const Duration(seconds: 2),
            traceId: 'trace-timeout',
            isRetryable: false,
          ),
          AppFailure.boundaryViolation(
            message: 'bad input',
            violations: const [
              FieldViolation(path: '/name', expected: 'string', actual: 'int'),
            ],
            traceId: 'trace-boundary',
            isRetryable: true,
          ),
          AppFailure.policyDenied(
            message: 'denied',
            reason: 'forbidden',
            traceId: 'trace-policy',
            isRetryable: true,
          ),
          AppFailure.notFound(
            message: 'missing',
            resourceType: 'User',
            resourceId: '42',
            traceId: 'trace-notfound',
            isRetryable: true,
          ),
          AppFailure.conflict(
            message: 'clash',
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
          AppFailure.interrupted(
            message: 'halted',
            intentDigest: 'digest',
            traceId: 'trace-interrupted',
            isRetryable: false,
          ),
          AppFailure.storage(
            message: 'cache miss',
            layer: 'database',
            traceId: 'trace-storage',
            isRetryable: true,
          ),
          AppFailure.unexpected(
            message: 'boom',
            cause: 'bad state',
            stackTrace: '#0 boom',
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
