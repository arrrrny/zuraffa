import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // @RequiresAuth golden tests
  // ═══════════════════════════════════════════════════════════════
  group('Golden: @RequiresAuth DDA Plugin', () {
    test(
        'AC1: @RequiresAuth(Role.admin) generates security interceptor '
        'that emits AppFailure.session for unauthorized', () {
      final gen = AuthGenerator();
      gen.addAuthEntry(
        className: 'DeleteUserUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/delete_user_usecase.dart',
        returnType: 'Future<void>',
        parameters: [
          const ParameterInfo(name: 'userId', type: 'String'),
        ],
        roles: ['admin'],
        mode: AuthorizationMode.all,
        isClassLevel: true,
      );

      final output = gen.generate();

      expect(output, contains('ZfaAuthGuard'));
      expect(output, contains('requireRole'));
      expect(output, contains('AppFailure.session'));
      expect(output, contains('DeleteUserUseCase'));
      expect(output, contains('Role.admin'));
      expect(output, contains('Unauthorized'));
      expect(output, contains('zfa DDA pipeline'));
    });

    test('AC2: role hierarchy — admin satisfies admin-only UseCase', () {
      final gen = AuthGenerator();
      gen.addAuthEntry(
        className: 'AdminOnlyUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/admin_usecase.dart',
        returnType: 'Future<Report>',
        parameters: const [],
        roles: ['admin'],
        mode: AuthorizationMode.all,
        isClassLevel: true,
      );

      final output = gen.generate();

      // Should use Role.satisfies for hierarchy check
      expect(output, contains('Role.satisfies'));
      expect(output, contains('requireRole'));
      expect(output, contains('AdminOnlyUseCase'));
    });

    test('AuthorizationMode.any with multiple roles', () {
      final gen = AuthGenerator();
      gen.addAuthEntry(
        className: 'ViewReportsUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/view_reports_usecase.dart',
        returnType: 'Future<Report>',
        parameters: const [],
        roles: ['admin', 'manager'],
        mode: AuthorizationMode.any,
        isClassLevel: false,
      );

      final output = gen.generate();

      // Any mode: uses || chain
      expect(output, contains('Role.satisfies(userRole, Role.admin)'));
      expect(output, contains('Role.satisfies(userRole, Role.manager)'));
      expect(output, contains('||'));
      expect(output, contains('requires one of'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // @Retry golden tests
  // ═══════════════════════════════════════════════════════════════
  group('Golden: @Retry DDA Plugin', () {
    test('AC3: @Retry(attempts: 3) generates retry wrapper', () {
      final gen = RetryGenerator();
      gen.addRetryEntry(
        className: 'FetchProductsUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/fetch_products_usecase.dart',
        returnType: 'Future<List<Product>>',
        parameters: const [],
        attempts: 3,
        backoff: BackoffStrategy.exponential,
        maxDelayMs: 30000,
        baseDelayMs: 1000,
        retryOn: ['network', 'server'],
      );

      final output = gen.generate();

      expect(output, contains('ZfaRetryPolicy'));
      expect(output, contains('computeDelay'));
      expect(output, contains('isRetryable'));
      expect(output, contains('FetchProductsUseCase'));
      expect(output, contains('for (var i = 0; i < 2;'));
      expect(output, contains('Future.delayed'));
      expect(output, contains('zfa DDA pipeline'));
    });

    test('AC4: exponential backoff with max delay cap', () {
      final gen = RetryGenerator();
      gen.addRetryEntry(
        className: 'SyncOrdersUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/sync_orders_usecase.dart',
        returnType: 'Future<void>',
        parameters: const [],
        attempts: 5,
        backoff: BackoffStrategy.exponential,
        maxDelayMs: 30000,
        baseDelayMs: 1000,
        retryOn: ['network'],
      );

      final output = gen.generate();

      // Exponential strategy
      expect(output, contains('BackoffStrategy.exponential'));
      expect(output, contains('pow(2, attemptIndex)'));
      expect(output, contains('maxDelayMs'));
    });

    test('AC5: non-retryable failures are not retried', () {
      final gen = RetryGenerator();
      gen.addRetryEntry(
        className: 'CreateOrderUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/create_order_usecase.dart',
        returnType: 'Future<Order>',
        parameters: [
          const ParameterInfo(name: 'params', type: 'CreateOrderParams'),
        ],
        attempts: 3,
        backoff: BackoffStrategy.fixed,
        maxDelayMs: 2000,
        baseDelayMs: 2000,
        retryOn: ['network', 'server'],
      );

      final output = gen.generate();

      // Should check isRetryable before retrying
      expect(output, contains('isRetryable'));
      expect(output, contains('rethrow'));
      expect(output, contains('catch (e)'));
      // Validation errors should NOT be in retryOn list
      expect(output, contains("'network'"));
      expect(output, contains("'server'"));
    });

    test('fixed backoff strategy', () {
      final gen = RetryGenerator();
      gen.addRetryEntry(
        className: 'RefreshTokenUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/refresh_token_usecase.dart',
        returnType: 'Future<Token>',
        parameters: const [],
        attempts: 3,
        backoff: BackoffStrategy.fixed,
        maxDelayMs: 2000,
        baseDelayMs: 2000,
        retryOn: ['network'],
      );

      final output = gen.generate();

      expect(output, contains('BackoffStrategy.fixed'));
      expect(output, contains('Duration(milliseconds: baseDelayMs)'));
    });

    test('retry budget enforcement', () {
      final gen = RetryGenerator();
      gen.addRetryEntry(
        className: 'BulkSyncUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/bulk_sync_usecase.dart',
        returnType: 'Future<void>',
        parameters: const [],
        attempts: 10,
        backoff: BackoffStrategy.exponential,
        maxDelayMs: 5000,
        baseDelayMs: 500,
        maxCumulativeMs: 30000,
        retryOn: ['network'],
      );

      final output = gen.generate();

      expect(output, contains('budgetMs'));
      expect(output, contains('elapsedMs'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // @TrackEvent golden tests
  // ═══════════════════════════════════════════════════════════════
  group('Golden: @TrackEvent DDA Plugin', () {
    test(
        'AC6: @TrackEvent(eventName: ...) generates analytics call '
        'before/after execution', () {
      final gen = TrackEventGenerator();
      gen.addTrackEventEntry(
        className: 'CheckoutUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/checkout_usecase.dart',
        returnType: 'Future<Order>',
        parameters: [
          const ParameterInfo(name: 'userId', type: 'String'),
          const ParameterInfo(name: 'total', type: 'double'),
        ],
        eventName: 'checkout_started',
        properties: ['userId', 'total'],
        trackDuration: true,
        trackResult: true,
        analyticsService: 'AnalyticsService',
      );

      final output = gen.generate();

      expect(output, contains('ZfaEventTracker'));
      expect(output, contains('trackStart'));
      expect(output, contains('trackEnd'));
      expect(output, contains('checkout_started'));
      expect(output, contains('CheckoutUseCase'));
      expect(output, contains('zfa DDA pipeline'));
    });

    test('AC7: no analytics calls in domain code — all in generated', () {
      final gen = TrackEventGenerator();
      gen.addTrackEventEntry(
        className: 'PlaceOrderUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/place_order_usecase.dart',
        returnType: 'Future<Order>',
        parameters: [
          const ParameterInfo(name: 'cartId', type: 'String'),
        ],
        eventName: 'order_placed',
        properties: ['cartId'],
        trackDuration: true,
        trackResult: true,
        analyticsService: 'AnalyticsService',
      );

      final output = gen.generate();

      // Generated adapter class wraps the source — domain code untouched
      expect(output, contains('_PlaceOrderUseCaseEventAdapter'));
      expect(output, contains('_source.execute'));
      expect(output, contains('Stopwatch'));
      expect(output, contains('durationMs'));
      expect(output, contains('success: true'));
      expect(output, contains('success: false'));
    });

    test('trackDuration and trackResult flags', () {
      final gen = TrackEventGenerator();
      gen.addTrackEventEntry(
        className: 'SimpleLogUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/simple_log_usecase.dart',
        returnType: 'Future<void>',
        parameters: const [],
        eventName: 'simple_event',
        properties: const [],
        trackDuration: false,
        trackResult: false,
        analyticsService: 'AnalyticsService',
      );

      final output = gen.generate();

      // No Stopwatch when trackDuration is false
      expect(output, contains('trackStart'));
      // Should NOT contain Stopwatch or durationMs
      expect(output, isNot(contains('Stopwatch')));
      expect(output, isNot(contains('durationMs')));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // AC8: Mixed middleware golden test
  // ═══════════════════════════════════════════════════════════════
  group('AC8: Mixed middleware — all three decorators produce expected output',
      () {
    test('auth + retry + trackEvent each produce valid output', () {
      // Auth
      final authGen = AuthGenerator();
      authGen.addAuthEntry(
        className: 'AdminDeleteUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/admin_delete.dart',
        returnType: 'Future<void>',
        parameters: [
          const ParameterInfo(name: 'id', type: 'String'),
        ],
        roles: ['admin'],
        mode: AuthorizationMode.all,
        isClassLevel: true,
      );
      final authOutput = authGen.generate();
      expect(authOutput, contains('ZfaAuthGuard'));
      expect(authOutput, contains('AppFailure.session'));

      // Retry
      final retryGen = RetryGenerator();
      retryGen.addRetryEntry(
        className: 'FetchDataUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/fetch_data.dart',
        returnType: 'Future<List<Data>>',
        parameters: const [],
        attempts: 3,
        backoff: BackoffStrategy.exponential,
        maxDelayMs: 30000,
        baseDelayMs: 1000,
        retryOn: ['network', 'server'],
      );
      final retryOutput = retryGen.generate();
      expect(retryOutput, contains('ZfaRetryPolicy'));
      expect(retryOutput, contains('computeDelay'));
      expect(retryOutput, contains('isRetryable'));

      // TrackEvent
      final eventGen = TrackEventGenerator();
      eventGen.addTrackEventEntry(
        className: 'CheckoutUseCase',
        methodName: 'execute',
        importUri: 'package:myapp/domain/usecases/checkout.dart',
        returnType: 'Future<Order>',
        parameters: [
          const ParameterInfo(name: 'userId', type: 'String'),
          const ParameterInfo(name: 'total', type: 'double'),
        ],
        eventName: 'checkout_started',
        properties: ['userId', 'total'],
        trackDuration: true,
        trackResult: true,
        analyticsService: 'AnalyticsService',
      );
      final eventOutput = eventGen.generate();
      expect(eventOutput, contains('ZfaEventTracker'));
      expect(eventOutput, contains('trackStart'));
      expect(eventOutput, contains('trackEnd'));
    });
  });
}
