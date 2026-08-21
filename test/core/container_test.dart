import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

class _TestService {
  _TestService();
  String greet() => 'hello';
}

class _TestRepo {
  _TestRepo(this.service);
  final _TestService service;
}

void main() {
  group('ZuraffaContainer', () {
    setUp(() => ZuraffaContainer.instance.reset());
    tearDown(() => ZuraffaContainer.instance.reset());

    test('register and resolve transient', () {
      ZuraffaContainer.instance.registerFactory<_TestService>(
        () => _TestService(),
      );
      final instance = ZuraffaContainer.instance.resolve<_TestService>();
      expect(instance, isA<_TestService>());
      expect(instance.greet(), 'hello');
    });

    test('transient creates new instance each time', () {
      ZuraffaContainer.instance.registerFactory<_TestService>(
        () => _TestService(),
      );
      final a = ZuraffaContainer.instance.resolve<_TestService>();
      final b = ZuraffaContainer.instance.resolve<_TestService>();
      expect(a, isNot(same(b)));
    });

    test('singleton returns same instance', () {
      ZuraffaContainer.instance.registerSingleton<_TestService>(
        () => _TestService(),
      );
      final a = ZuraffaContainer.instance.resolve<_TestService>();
      final b = ZuraffaContainer.instance.resolve<_TestService>();
      expect(a, same(b));
    });

    test('lazy singleton returns same instance after first resolution', () {
      ZuraffaContainer.instance.registerLazySingleton<_TestService>(
        () => _TestService(),
      );
      final a = ZuraffaContainer.instance.resolve<_TestService>();
      final b = ZuraffaContainer.instance.resolve<_TestService>();
      expect(a, same(b));
    });

    test('registerInstance stores the provided value', () {
      final service = _TestService();
      ZuraffaContainer.instance.registerInstance<_TestService>(service);
      final resolved = ZuraffaContainer.instance.resolve<_TestService>();
      expect(resolved, same(service));
    });

    test('isRegistered returns true for registered types', () {
      ZuraffaContainer.instance.registerFactory<_TestService>(
        () => _TestService(),
      );
      expect(ZuraffaContainer.instance.isRegistered<_TestService>(), true);
      expect(ZuraffaContainer.instance.isRegistered<_TestRepo>(), false);
    });

    test('resolve throws StateError for unregistered types', () {
      expect(
        () => ZuraffaContainer.instance.resolve<_TestService>(),
        throwsStateError,
      );
    });

    test('reset clears all registrations', () {
      ZuraffaContainer.instance.registerFactory<_TestService>(
        () => _TestService(),
      );
      ZuraffaContainer.instance.reset();
      expect(ZuraffaContainer.instance.isRegistered<_TestService>(), false);
    });
  });
}
