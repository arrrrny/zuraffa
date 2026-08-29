// Spec 025 acceptance proof (SC-002 / SC-004, US3 + US4 + US5 + US7):
// a consuming app resolves a package's datasource + usecase with ZERO
// manual registration, walks the full module lifecycle, and invokes the
// package's agent tool by its namespaced identifier.
//
// Note what is ABSENT from this file: no `registerLazySingleton`, no
// `setupDependencies`, no service-locator import. The only wiring is
// importing the package and activating its module.
import 'package:get_it/get_it.dart';
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:notes_package/notes_package.dart';

void main() {
  test(
    'SC-002: auto-DI resolves datasource + usecase after activation',
    () async {
      final engine = ZuraffaEngine(
        di: ZuraffaDIContainer(getIt: GetIt.asNewInstance()),
      )..registerPackage(NotesPackageModule());

      // Nothing resolves before the module activates (import-scoped).
      expect(engine.di.isRegistered<GetNoteUseCase>(), isFalse);

      await engine.bootstrap();

      final usecase = engine.di.get<GetNoteUseCase>();
      expect(usecase, isA<GetNoteUseCase>());

      final dataSource = engine.di.get<NoteMockDataSource>();
      expect(dataSource, isA<NoteMockDataSource>());

      final note = await usecase.execute(
        QueryParams<Note>(params: {'id': 'id 1'}),
        null,
      );
      expect(note.id, 'id 1');
    },
  );

  test('FR-008/FR-009: agent tool registers namespaced and executes', () async {
    final engine = ZuraffaEngine(
      di: ZuraffaDIContainer(getIt: GetIt.asNewInstance()),
    )..registerPackage(NotesPackageModule());
    await engine.bootstrap();

    final registry = McpToolRegistry();
    // Absent until the app merges the module's tools (import-scoped).
    expect(registry.find('notes_package.get_note'), isNull);

    PackageAgentTools.registerInto(registry, NotesPackageModule(), engine.di);

    final tool = registry.find('notes_package.get_note');
    expect(tool, isNotNull, reason: 'tool must appear as <package>.<tool>');

    final result = await tool!.call({
      'params': {'id': 'id 2'},
    });
    expect(result.isError, isFalse);
    // The mock datasource's query returns a note from its fixture data —
    // the invocation (namespacing + DI-resolved execution + standard
    // result shape) is what this proves, not the mock's filtering.
    expect(result.text, contains('Note(id:'));
  });

  test('FR-006/FR-007: full lifecycle order + discoverable id', () async {
    final log = <String>[];
    final engine = ZuraffaEngine(
      di: ZuraffaDIContainer(getIt: GetIt.asNewInstance()),
    );

    // Track the module's lifecycle by wrapping its hooks.
    final module = _LifecycleTrackingModule(NotesPackageModule(), log);
    engine.register(module);

    expect(engine.activeModuleIds, contains('notes_package'));

    await engine.bootstrap();
    await engine.ready();
    await engine.shutdown();

    expect(log, containsAllInOrder(['register', 'init', 'ready', 'dispose']));
  });
}

/// Wraps a package module to record which lifecycle phases the engine
/// drove through its real hooks (the module's own hooks are no-ops, so
/// the wrapper observes the engine's calls without changing behavior).
class _LifecycleTrackingModule extends PackageModule {
  _LifecycleTrackingModule(this._inner, this.log);

  final NotesPackageModule _inner;
  final List<String> log;

  @override
  String get pluginId => _inner.pluginId;

  @override
  String get zuraffaSdkConstraint => _inner.zuraffaSdkConstraint;

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    log.add('register');
    _inner.registerDependencies(di);
  }

  @override
  Map<String, ZuraffaRouteHandler> get routes => _inner.routes;

  @override
  Future<void> onInit(ZuraffaDIContainer di) async {
    log.add('init');
    await _inner.onInit(di);
  }

  @override
  Future<void> onReady(ZuraffaDIContainer di) async {
    log.add('ready');
    await _inner.onReady(di);
  }

  @override
  Future<void> onDispose(ZuraffaDIContainer di) async {
    log.add('dispose');
    await _inner.onDispose(di);
  }
}
