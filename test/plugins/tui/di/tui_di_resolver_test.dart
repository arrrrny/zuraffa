import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/di/tui_di_resolver.dart';
import 'package:get_it/get_it.dart';
import 'package:zuraffa/src/core/module/di_container.dart';

void main() {
  group('TuiDiResolver (FR-008)', () {
    test(
      'A14 / U29: get<T>() resolves via the caller-supplied '
      'ZuraffaDIContainer (and its underlying GetIt)',
      () {
        final getIt = GetIt.asNewInstance();
        getIt.registerSingleton<String>('hello-from-di');

        final di = ZuraffaDIContainer(getIt: getIt);
        final resolver = TuiDiResolver(di);

        expect(resolver.get<String>(), 'hello-from-di');
        expect(resolver.call<String>(), 'hello-from-di');
        expect(resolver.isRegistered<String>(), isTrue);
      },
    );

    test(
      'U30: resolver does NOT create its own container — it uses the '
      'caller-supplied one verbatim',
      () {
        final getIt = GetIt.asNewInstance();
        getIt.registerSingleton<int>(42);

        final di = ZuraffaDIContainer(getIt: getIt);
        final resolver = TuiDiResolver(di);

        // The resolver's container is the same instance — no shadow copy.
        expect(identical(resolver.container, di), isTrue);
        expect(identical(resolver.container.getIt, getIt), isTrue);

        // The resolver resolves the value the caller registered.
        expect(resolver.get<int>(), 42);
      },
    );

    test(
      'A14: tests MAY register or override bindings through the same '
      'caller-supplied container',
      () async {
        final getIt = GetIt.asNewInstance();
        final di = ZuraffaDIContainer(getIt: getIt);

        // Register through the caller's container — the resolver sees it.
        await di.registerLazySingleton<String>(() => 'first');
        final resolver = TuiDiResolver(di);
        expect(resolver.get<String>(), 'first');

        // Override through the caller's container — the resolver sees the
        // new value, proving the resolver never caches or shadows.
        await di.registerLazySingleton<String>(() => 'second', override: true);
        expect(resolver.get<String>(), 'second');
      },
    );
  });
}
