import 'package:test/test.dart';
import 'package:get_it/get_it.dart';
import 'package:zuraffa/src/core/module/contracts.dart';

class _AlphaPlugin extends ZuraffaPlugin {
  @override
  String get pluginId => 'alpha';
  @override
  void registerDependencies(ZuraffaDIContainer di) {
    di.registerLazySingleton<String>(() => 'alpha_value');
  }
  @override
  Map<String, ZuraffaRouteBuilder> get routes => {
        '/alpha': (args) => 'alpha_route',
      };
}

class _BetaPlugin extends ZuraffaPlugin {
  bool initCalled = false;
  @override
  String get pluginId => 'beta';
  @override
  void registerDependencies(ZuraffaDIContainer di) {
    di.registerFactory<int>(() => 42);
  }
  @override
  Map<String, ZuraffaRouteBuilder> get routes => {
        '/beta': (args) => 'beta_route',
        '/shared': (args) => 'shared_route',
      };
  @override
  Future<void> onInit(ZuraffaDIContainer di) async {
    initCalled = true;
  }
}

class _EmptyPlugin extends ZuraffaPlugin {
  @override
  String get pluginId => '';
  @override
  void registerDependencies(ZuraffaDIContainer di) {}
  @override
  Map<String, ZuraffaRouteBuilder> get routes => {};
}

void main() {
  late GetIt getIt;

  setUp(() {
    getIt = GetIt.asNewInstance();
  });

  group('ZuraffaDIContainer', () {
    test('delegates registerLazySingleton and get', () {
      final di = ZuraffaDIContainer(getIt: getIt);
      di.registerLazySingleton<String>(() => 'hello');
      expect(di.get<String>(), 'hello');
    });

    test('delegates registerFactory (new instance each call)', () {
      final di = ZuraffaDIContainer(getIt: getIt);
      var counter = 0;
      di.registerFactory<int>(() => ++counter);
      expect(di.get<int>(), 1);
      expect(di.get<int>(), 2);
    });

    test('delegates registerInstance', () {
      final di = ZuraffaDIContainer(getIt: getIt);
      di.registerInstance<String>('fixed');
      expect(di.get<String>(), 'fixed');
    });

    test('isRegistered returns true after registration', () {
      final di = ZuraffaDIContainer(getIt: getIt);
      expect(di.isRegistered<String>(), false);
      di.registerLazySingleton<String>(() => 'x');
      expect(di.isRegistered<String>(), true);
    });

    test('exposes getIt for interop', () {
      final di = ZuraffaDIContainer(getIt: getIt);
      expect(identical(di.getIt, getIt), true);
    });
  });

  group('ZuraffaEngine', () {
    ZuraffaDIContainer di() => ZuraffaDIContainer(getIt: getIt);

    test('register returns this for chaining', () {
      final engine = ZuraffaEngine(di: di());
      final returned = engine.register(_AlphaPlugin());
      expect(identical(returned, engine), true);
    });

    test('rejects duplicate pluginId', () {
      final engine = ZuraffaEngine(di: di())..register(_AlphaPlugin());
      expect(
        () => engine.register(_AlphaPlugin()),
        throwsArgumentError,
      );
    });

    test('rejects empty pluginId', () {
      final engine = ZuraffaEngine(di: di());
      expect(
        () => engine.register(_EmptyPlugin()),
        throwsArgumentError,
      );
    });

    test('rejects register after bootstrap', () async {
      final engine = ZuraffaEngine(di: di())..register(_AlphaPlugin());
      await engine.bootstrap();
      expect(
        () => engine.register(_BetaPlugin()),
        throwsStateError,
      );
    });

    test('bootstrap throws on zero plugins', () async {
      final engine = ZuraffaEngine(di: di());
      expect(engine.bootstrap, throwsStateError);
    });

    test('bootstrap throws on double call', () async {
      final engine = ZuraffaEngine(di: di())..register(_AlphaPlugin());
      await engine.bootstrap();
      expect(engine.bootstrap, throwsStateError);
    });

    test('bootstrap calls registerDependencies then onInit', () async {
      final beta = _BetaPlugin();
      final engine = ZuraffaEngine(di: di())
        ..register(_AlphaPlugin())
        ..register(beta);
      await engine.bootstrap();

      expect(engine.di.get<String>(), 'alpha_value');
      expect(engine.di.get<int>(), 42);
      expect(beta.initCalled, true);
    });

    test('masterRouteMap merges routes from all plugins', () async {
      final engine = ZuraffaEngine(di: di())
        ..register(_AlphaPlugin())
        ..register(_BetaPlugin());
      await engine.bootstrap();

      final routes = engine.masterRouteMap;
      expect(routes.containsKey('/alpha'), true);
      expect(routes.containsKey('/beta'), true);
      expect(routes.containsKey('/shared'), true);
    });

    test('masterRouteMap is unmodifiable', () async {
      final engine = ZuraffaEngine(di: di())..register(_AlphaPlugin());
      await engine.bootstrap();

      expect(
        () => (engine.masterRouteMap as Map).clear(),
        throwsUnsupportedError,
      );
    });

    test('plugins list preserves insertion order', () {
      final engine = ZuraffaEngine(di: di())
        ..register(_AlphaPlugin())
        ..register(_BetaPlugin());
      expect(engine.plugins[0].pluginId, 'alpha');
      expect(engine.plugins[1].pluginId, 'beta');
    });

    test('operator [] looks up by pluginId', () {
      final engine = ZuraffaEngine(di: di())..register(_AlphaPlugin());
      expect(engine['alpha']?.pluginId, 'alpha');
      expect(engine['nonexistent'], isNull);
    });
  });
}
