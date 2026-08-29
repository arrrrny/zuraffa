import 'package:get_it/get_it.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/contracts.dart';
import 'package:zuraffa/src/version.dart';

/// Records lifecycle hook firings for order assertions (FR-006/FR-007).
class _RecordingModule extends PackageModule {
  _RecordingModule(this._id, this.log, {this.initThrows = false});

  final String _id;
  final List<String> log;
  final bool initThrows;

  @override
  String get pluginId => _id;

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    log.add('register:$_id');
    di.registerLazySingleton<String>(
      () => 'value_from_$_id',
      instanceName: _id,
    );
  }

  @override
  Map<String, ZuraffaRouteHandler> get routes => const {};

  @override
  Future<void> onInit(ZuraffaDIContainer di) async {
    log.add('init:$_id');
    if (initThrows) throw StateError('boom in $_id');
  }

  @override
  Future<void> onReady(ZuraffaDIContainer di) async {
    log.add('ready:$_id');
  }

  @override
  Future<void> onDispose(ZuraffaDIContainer di) async {
    log.add('dispose:$_id');
  }
}

/// A plain v6 plugin with NO onReady/onDispose overrides — proves the new
/// hooks are source-compatible defaults for existing plugins (U5).
class _PlainPlugin extends ZuraffaPlugin {
  @override
  String get pluginId => 'plain';
  @override
  void registerDependencies(ZuraffaDIContainer di) {}
  @override
  Map<String, ZuraffaRouteHandler> get routes => {};
}

void main() {
  late GetIt getIt;
  late ZuraffaDIContainer container;

  setUp(() {
    getIt = GetIt.asNewInstance();
    container = ZuraffaDIContainer(getIt: getIt);
  });

  group('PackageModule contract (FR-006)', () {
    test('U6: packageName defaults to pluginId; agentTools default empty', () {
      final module = _RecordingModule('my_pkg', []);
      expect(module.packageName, 'my_pkg');
      expect(module.buildAgentTools(ZuraffaDIContainer(getIt: getIt)), isEmpty);
      expect(module, isA<ZuraffaPlugin>());
    });
  });

  group('ZuraffaEngine lifecycle extension (FR-006/FR-007)', () {
    test('U7: ready() fires onReady in registration order, once', () async {
      final log = <String>[];
      final engine = ZuraffaEngine(di: container)
        ..register(_RecordingModule('a', log))
        ..register(_RecordingModule('b', log));

      await engine.bootstrap();
      await engine.ready();

      expect(
        log,
        containsAllInOrder(['init:a', 'init:b', 'ready:a', 'ready:b']),
      );

      // Second ready() is a programming error, not a silent no-op.
      expect(() => engine.ready(), throwsStateError);
    });

    test(
      'U8: shutdown() fires onDispose in reverse registration order',
      () async {
        final log = <String>[];
        final engine = ZuraffaEngine(di: container)
          ..register(_RecordingModule('a', log))
          ..register(_RecordingModule('b', log));

        await engine.bootstrap();
        await engine.ready();
        await engine.shutdown();

        expect(log, containsAllInOrder(['dispose:b', 'dispose:a']));
      },
    );

    test('U9: activeModuleIds lists discoverable module identifiers', () async {
      final engine = ZuraffaEngine(di: container)
        ..register(_RecordingModule('my_pkg', []))
        ..register(_PlainPlugin());

      expect(engine.activeModuleIds, containsAll(['my_pkg', 'plain']));

      await engine.bootstrap();
      // Queryable after bootstrap — the package module is discoverable
      // by its stable identifier (US4-S3).
      expect(engine.activeModuleIds, contains('my_pkg'));
      expect(engine.isRegistered('my_pkg'), isTrue);
    });

    test(
      'U5: plain plugin without new hooks survives full lifecycle',
      () async {
        final engine = ZuraffaEngine(di: container)..register(_PlainPlugin());
        await engine.bootstrap();
        await engine.ready();
        await engine.shutdown();
        expect(engine.pluginCount, 1);
      },
    );

    test(
      'U27: full per-module order register→init→ready→dispose; modules independent',
      () async {
        final log = <String>[];
        final engine = ZuraffaEngine(di: container)
          ..register(_RecordingModule('pkg_a', log))
          ..register(_RecordingModule('pkg_b', log));

        await engine.bootstrap();
        await engine.ready();
        await engine.shutdown();

        // Each module walks its own register→init→ready→dispose chain; module
        // b's dispose does not interfere with module a's (independence).
        expect(
          log,
          containsAllInOrder(['register:pkg_a', 'init:pkg_a', 'ready:pkg_a']),
        );
        expect(
          log,
          containsAllInOrder(['register:pkg_b', 'init:pkg_b', 'ready:pkg_b']),
        );
        expect(log, containsAllInOrder(['dispose:pkg_b', 'dispose:pkg_a']));
      },
    );

    test(
      'module init failure propagates out of bootstrap (fail-fast, edge)',
      () async {
        final engine = ZuraffaEngine(di: container)
          ..register(_RecordingModule('bad', [], initThrows: true));
        await expectLater(engine.bootstrap(), throwsStateError);
      },
    );
  });

  group('registerPackage compatibility gate (FR-015)', () {
    test(
      'U12: incompatible module rejected with clear StateError naming versions',
      () {
        // _RecordingModule has the default constraint (compatible); build a
        // mismatching one inline instead.
        final incompatible = _ConstrainedModule('future_pkg', '^7.0.0');
        final engine = ZuraffaEngine(di: container);
        expect(
          () => engine.registerPackage(incompatible),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('7.0.0'), contains(version)),
            ),
          ),
        );
        expect(engine.isRegistered('future_pkg'), isFalse);
      },
    );

    test('U12: compatible module registers through registerPackage', () {
      final engine = ZuraffaEngine(di: container);
      engine.registerPackage(_ConstrainedModule('ok_pkg', '^6.0.0'));
      expect(engine.isRegistered('ok_pkg'), isTrue);
    });
  });
}

class _ConstrainedModule extends PackageModule {
  _ConstrainedModule(this._id, this._constraint);

  final String _id;
  final String _constraint;

  @override
  String get pluginId => _id;

  @override
  String get zuraffaSdkConstraint => _constraint;

  @override
  void registerDependencies(ZuraffaDIContainer di) {}

  @override
  Map<String, ZuraffaRouteHandler> get routes => const {};
}
