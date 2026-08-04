import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:zuraffa/src/core/module/contracts.dart';

void main() {
  late GetIt getIt;
  late ZuraffaDIContainer di;

  setUp(() {
    getIt = GetIt.asNewInstance();
    di = ZuraffaDIContainer(getIt: getIt);
  });

  group('override parameter', () {
    test('registerLazySingleton throws when duplicate without override', () {
      di.registerLazySingleton<String>(() => 'first');
      expect(
        () => di.registerLazySingleton<String>(() => 'second'),
        throwsStateError,
      );
    });

    test('registerLazySingleton replaces with override: true', () {
      di.registerLazySingleton<String>(() => 'first');
      di.registerLazySingleton<String>(() => 'second', override: true);
      expect(di.get<String>(), 'second');
    });

    test('registerFactory throws when duplicate without override', () {
      di.registerFactory<int>(() => 1);
      expect(
        () => di.registerFactory<int>(() => 2),
        throwsStateError,
      );
    });

    test('registerFactory replaces with override: true', () {
      di.registerFactory<int>(() => 1);
      di.registerFactory<int>(() => 2, override: true);
      expect(di.get<int>(), 2);
    });

    test('registerSingleton throws when duplicate without override', () {
      di.registerSingleton<double>(() => 1.0);
      expect(
        () => di.registerSingleton<double>(() => 2.0),
        throwsStateError,
      );
    });

    test('registerSingleton replaces with override: true', () {
      di.registerLazySingleton<double>(() => 1.0);
      di.registerLazySingleton<double>(() => 2.0, override: true);
      expect(di.get<double>(), 2.0);
    });

    test('registerInstance throws when duplicate without override', () {
      di.registerInstance<String>('first');
      expect(
        () => di.registerInstance<String>('second'),
        throwsStateError,
      );
    });

    test('registerInstance replaces with override: true', () {
      di.registerInstance<String>('first');
      di.registerInstance<String>('second', override: true);
      expect(di.get<String>(), 'second');
    });

    test('override with instanceName does not affect unnamed', () {
      di.registerLazySingleton<String>(() => 'unnamed');
      di.registerLazySingleton<String>(
        () => 'named',
        instanceName: 'v2',
      );
      // Override the named one.
      di.registerLazySingleton<String>(
        () => 'named_v2',
        instanceName: 'v2',
        override: true,
      );
      expect(di.get<String>(), 'unnamed');
      expect(di.get<String>(instanceName: 'v2'), 'named_v2');
    });

    test('error message mentions the type', () {
      di.registerLazySingleton<int>(() => 0);
      try {
        di.registerLazySingleton<int>(() => 1);
        fail('Expected StateError');
      } on StateError catch (e) {
        expect(e.message, contains('int'));
        expect(e.message, contains('override'));
      }
    });
  });

  group('interceptorRegistry', () {
    test('container creates its own registry by default', () {
      expect(di.interceptorRegistry, isNotNull);
      expect(di.interceptorRegistry.isEmpty, true);
    });

    test('registerInterceptor delegates to the registry', () {
      di.registerInterceptor<String, int>(
        InterceptorEntry<String, int>(
          name: 'test',
          handler: (req, next) => next(req),
        ),
      );
      expect(di.interceptorRegistry.isEmpty, false);
      final entries = di.interceptorRegistry.entriesFor<String, int>();
      expect(entries.length, 1);
      expect(entries.first.name, 'test');
    });

    test('reset clears both registrations and interceptors', () async {
      di.registerLazySingleton<String>(() => 'x');
      di.registerInterceptor<String, String>(
        InterceptorEntry<String, String>(
          name: 'i',
          handler: (req, next) => next(req),
        ),
      );
      await di.reset();
      expect(di.isRegistered<String>(), false);
      expect(di.interceptorRegistry.isEmpty, true);
    });
  });
}