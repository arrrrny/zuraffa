import 'package:get_it/get_it.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/contracts.dart';

// ---------------------------------------------------------------------------
// A minimal fake Zuraffa-native package, mirroring exactly what
// `zfa package create` + `zfa make ... di` produce in package mode:
// a registrar function registering a datasource + a usecase through the
// container's GetIt, and a module calling it from registerDependencies.
// ---------------------------------------------------------------------------

class NoteRemoteDataSource {
  String fetch() => 'note-data';
}

class GetNoteUseCase {
  final NoteRemoteDataSource ds;
  GetNoteUseCase(this.ds);

  String call() => ds.fetch();
}

/// Mirrors the generated package registrar (spec 025, FR-004/FR-005):
/// registers the package's datasource + usecase into the consuming app's
/// container — called ONLY through the package module.
void registerFakeNotesPackage(ZuraffaDIContainer di) {
  final getIt = di.getIt;
  getIt.registerLazySingleton<NoteRemoteDataSource>(
    () => NoteRemoteDataSource(),
  );
  getIt.registerFactory<GetNoteUseCase>(
    () => GetNoteUseCase(getIt.get<NoteRemoteDataSource>()),
  );
}

class FakeNotesPackageModule extends PackageModule {
  @override
  String get pluginId => 'fake_notes';

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    registerFakeNotesPackage(di);
  }

  @override
  Map<String, ZuraffaRouteHandler> get routes => const {};
}

class OtherPackageModule extends PackageModule {
  @override
  String get pluginId => 'other_pkg';

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    di.getIt.registerLazySingleton<String>(
      () => 'other-datasource',
      instanceName: 'other',
    );
  }

  @override
  Map<String, ZuraffaRouteHandler> get routes => const {};
}

void main() {
  late GetIt getIt;
  late ZuraffaDIContainer container;

  setUp(() {
    getIt = GetIt.asNewInstance();
    container = ZuraffaDIContainer(getIt: getIt);
  });

  group('consuming-app auto-registration (FR-005, SC-002 — spec 025)', () {
    test('U25: app resolves package datasource + usecase with zero '
        'manual registration code', () async {
      // === the ENTIRE "app" code: activate the module and bootstrap ===
      final engine = ZuraffaEngine(di: container)
        ..registerPackage(FakeNotesPackageModule());
      await engine.bootstrap();
      // ================================================================

      // No manual registration line exists anywhere in this test above —
      // the container resolves the package's components (SC-002).
      final ds = container.get<NoteRemoteDataSource>();
      expect(ds, isA<NoteRemoteDataSource>());
      expect(ds.fetch(), 'note-data');

      final usecase = container.get<GetNoteUseCase>();
      expect(usecase, isA<GetNoteUseCase>());
      expect(usecase.call(), 'note-data');
    });

    test(
      'U25b: without the module, nothing registers (import-scoped, US3-S3)',
      () async {
        final engine = ZuraffaEngine(di: container);
        // The app did NOT import/activate the package module.
        expect(engine.pluginCount, 0);
        expect(container.isRegistered<NoteRemoteDataSource>(), isFalse);
        expect(container.isRegistered<GetNoteUseCase>(), isFalse);
      },
    );

    test(
      'U26: two packages merge into one container without conflicts',
      () async {
        final engine = ZuraffaEngine(di: container)
          ..registerPackage(FakeNotesPackageModule())
          ..registerPackage(OtherPackageModule());
        await engine.bootstrap();

        // Both packages' contributions coexist — no manual merge logic.
        expect(container.get<NoteRemoteDataSource>(), isNotNull);
        expect(getIt.get<String>(instanceName: 'other'), 'other-datasource');
        expect(
          engine.activeModuleIds,
          containsAll(['fake_notes', 'other_pkg']),
        );
      },
    );

    test(
      'U27: lifecycle order per module; empty module-only package works',
      () async {
        final log = <String>[];

        final lifecycleModule = _LifecycleModule('lifecycle_pkg', log);
        final emptyModule = _EmptyPackageModule('empty_pkg');

        final engine = ZuraffaEngine(di: container)
          ..registerPackage(lifecycleModule)
          ..registerPackage(emptyModule);

        await engine.bootstrap();
        await engine.ready();
        await engine.shutdown();

        expect(
          log,
          containsAllInOrder([
            'register:lifecycle_pkg',
            'init:lifecycle_pkg',
            'ready:lifecycle_pkg',
            'dispose:lifecycle_pkg',
          ]),
        );
      },
    );

    test(
      'U27b: module init failure propagates (fail-fast, no silent swallow)',
      () async {
        final engine = ZuraffaEngine(di: container)
          ..registerPackage(_FailingModule());
        await expectLater(engine.bootstrap(), throwsStateError);
      },
    );
  });
}

class _LifecycleModule extends PackageModule {
  _LifecycleModule(this._id, this.log);

  final String _id;
  final List<String> log;

  @override
  String get pluginId => _id;

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    log.add('register:$_id');
  }

  @override
  Map<String, ZuraffaRouteHandler> get routes => {};

  @override
  Future<void> onInit(ZuraffaDIContainer di) async => log.add('init:$_id');

  @override
  Future<void> onReady(ZuraffaDIContainer di) async => log.add('ready:$_id');

  @override
  Future<void> onDispose(ZuraffaDIContainer di) async =>
      log.add('dispose:$_id');
}

class _EmptyPackageModule extends PackageModule {
  _EmptyPackageModule(this._id);

  final String _id;

  @override
  String get pluginId => _id;

  @override
  void registerDependencies(ZuraffaDIContainer di) {}

  @override
  Map<String, ZuraffaRouteHandler> get routes => {};
}

class _FailingModule extends PackageModule {
  @override
  String get pluginId => 'failing_pkg';

  @override
  void registerDependencies(ZuraffaDIContainer di) {}

  @override
  Map<String, ZuraffaRouteHandler> get routes => {};

  @override
  Future<void> onInit(ZuraffaDIContainer di) async {
    throw StateError('module startup failure');
  }
}
