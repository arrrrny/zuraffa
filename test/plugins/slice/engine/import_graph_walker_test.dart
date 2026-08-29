/// Tests for ImportGraphWalker (U20-U26) and FileGraph.
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U20: The transitive closure from one entry includes exactly the
///        reachable local files, each exactly once
///   U21: An import cycle terminates with all files in the cycle included once
///   U22: A missing entry file fails with the attempted path and the
///        available alternatives
///   U23: At `view` depth the slice includes view/controller/state and
///        excludes presenter, usecases, and domain
///   U24: At `feature` depth the slice includes domain interfaces/entities
///        and excludes data-layer implementations
///   U25: At `full` depth the slice additionally includes repository
///        implementations, datasources, and providers
///   U26: Multiple entries produce the union of their closures with shared
///        files deduplicated
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/engine/import_graph_walker.dart';
import 'package:zuraffa/src/plugins/slice/engine/package_resolver.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_depth.dart';

import '../helpers/copy_fixture_project.dart';

void main() {
  late String projectRoot;
  late PackageResolver resolver;
  late ImportGraphWalker walker;

  setUp(() async {
    projectRoot = await copySliceFixtureProject();
    resolver = await PackageResolver.load(projectRoot);
    walker = ImportGraphWalker();
  });

  tearDown(() async {
    final dir = Directory(projectRoot);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  /// Relative paths of the walk's included files, sorted, using '/'.
  Future<Set<String>> includedRel(
    List<String> entrySpecs,
    SliceDepth depth,
  ) async {
    final entries = walker.resolveEntrySpecs(entrySpecs, projectRoot);
    final result = await walker.walk(
      entries: entries,
      projectRoot: projectRoot,
      resolver: resolver,
      depth: depth,
    );
    return result.graph.nodes.keys
        .map((path) => path.substring(projectRoot.length + 1))
        .toSet();
  }

  group('ImportGraphWalker closure (FR-001)', () {
    test('U20: closure from one entry is exactly the reachable local files',
        () async {
      final included = await includedRel(['product'], SliceDepth.feature);

      expect(included, contains('lib/src/presentation/pages/product/product_view.dart'));
      expect(included, contains('lib/src/presentation/pages/product/product_controller.dart'));
      expect(included, contains('lib/src/presentation/pages/product/product_presenter.dart'));
      expect(included, contains('lib/src/presentation/pages/product/product_state.dart'));
      // Shared widget via barrel `show PrimaryButton` — and only that one.
      expect(included, contains('lib/src/presentation/widgets/primary_button.dart'));
      expect(included, isNot(contains('lib/src/presentation/widgets/secondary_button.dart')));
      expect(included, isNot(contains('lib/src/presentation/widgets/app_card.dart')));
      expect(included, isNot(contains('lib/src/presentation/widgets/loading_indicator.dart')));
      // Domain layer pulled in via imports and getIt<T>() (FR-001).
      expect(included, contains('lib/src/domain/usecases/product/get_product_usecase.dart'));
      expect(included, contains('lib/src/domain/usecases/product/update_product_usecase.dart'));
      expect(included, contains('lib/src/domain/usecases/shared/fetch_settings_usecase.dart'));
      expect(included, contains('lib/src/domain/entities/product/product.dart'));
      // Companion file rides along (FR-006).
      expect(included, contains('lib/src/domain/entities/product/product.g.dart'));
      // DI registrations for the getIt-resolved usecases (A3).
      expect(included, contains('lib/src/di/usecases/get_product_usecase_di.dart'));
      expect(included, contains('lib/src/di/usecases/update_product_usecase_di.dart'));
      expect(included, contains('lib/src/di/usecases/fetch_settings_usecase_di.dart'));
      // Repository interface (domain) included; implementation (data) is not.
      expect(included, contains('lib/src/domain/repositories/product_repository.dart'));
      // Unreachable or excluded files.
      expect(included, isNot(contains('lib/main.dart')));
      expect(included, isNot(contains('lib/src/presentation/pages/profile/profile_view.dart')));
      expect(included, isNot(contains('lib/src/data/repositories/data_product_repository.dart')));
      expect(included, isNot(contains('lib/src/data/datasources/product_remote_datasource.dart')));
      expect(included, isNot(contains('lib/src/di/repositories/product_repository_di.dart')));
      expect(included, isNot(contains('lib/src/di/index.dart')));
    });

    test('U20: every included file appears exactly once', () async {
      final entries = walker.resolveEntrySpecs(['product'], projectRoot);
      final result = await walker.walk(
        entries: entries,
        projectRoot: projectRoot,
        resolver: resolver,
        depth: SliceDepth.feature,
      );

      final paths = result.graph.nodes.keys.toList();
      expect(paths.toSet().length, equals(paths.length));
    });

    test('U21: an import cycle terminates and includes every cycle file once',
        () async {
      final cycleDir = await Directory(
        '$projectRoot/lib/src/presentation/pages/cycle',
      ).create(recursive: true);
      await File('${cycleDir.path}/cycle_view.dart').writeAsString('''
import 'cycle_state.dart';
import '../../widgets/primary_button.dart';
class CycleView {}
''');
      await File('${cycleDir.path}/cycle_state.dart').writeAsString('''
import 'cycle_view.dart';
import 'cycle_controller.dart';
class CycleState {}
''');
      await File('${cycleDir.path}/cycle_controller.dart').writeAsString('''
import 'cycle_state.dart';
class CycleController {}
''');

      final entries = walker.resolveEntrySpecs(['cycle'], projectRoot);
      final result = await walker.walk(
        entries: entries,
        projectRoot: projectRoot,
        resolver: resolver,
        depth: SliceDepth.view,
      );

      final rel = result.graph.nodes.keys
          .map((path) => path.substring(projectRoot.length + 1))
          .toSet();
      expect(rel, contains('lib/src/presentation/pages/cycle/cycle_view.dart'));
      expect(rel, contains('lib/src/presentation/pages/cycle/cycle_state.dart'));
      expect(rel, contains('lib/src/presentation/pages/cycle/cycle_controller.dart'));
      expect(result.graph.nodes.length, equals(rel.length));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('U22: a missing entry reports the attempted path and alternatives',
        () async {
      expect(
        () => walker.resolveEntrySpecs(['no_such_page'], projectRoot),
        throwsA(
          isA<EntryResolutionError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('no_such_page'),
              contains('product'),
              contains('profile'),
            ),
          ),
        ),
      );
    });

    test('an entry given as a path is used directly', () async {
      final entries = walker.resolveEntrySpecs(
        ['lib/src/presentation/pages/profile/profile_view.dart'],
        projectRoot,
      );

      expect(
        entries.single,
        endsWith('lib/src/presentation/pages/profile/profile_view.dart'),
      );
    });

    test('U23: view depth excludes presenter, usecases, and domain',
        () async {
      final included = await includedRel(['product'], SliceDepth.view);

      expect(included, contains('lib/src/presentation/pages/product/product_view.dart'));
      expect(included, contains('lib/src/presentation/pages/product/product_controller.dart'));
      expect(included, contains('lib/src/presentation/pages/product/product_state.dart'));
      expect(included, contains('lib/src/presentation/widgets/primary_button.dart'));
      expect(included, isNot(contains('lib/src/presentation/pages/product/product_presenter.dart')));
      expect(
        included,
        isNot(contains('lib/src/domain/usecases/product/get_product_usecase.dart')),
      );
      expect(included, isNot(contains('lib/src/domain/entities/product/product.dart')));
    });

    test('U24: feature depth includes domain and excludes data', () async {
      final included = await includedRel(['product'], SliceDepth.feature);

      expect(included, contains('lib/src/domain/repositories/product_repository.dart'));
      expect(included, contains('lib/src/domain/entities/product/product.dart'));
      expect(
        included,
        isNot(contains('lib/src/data/repositories/data_product_repository.dart')),
      );
      expect(
        included,
        isNot(contains('lib/src/data/datasources/product_remote_datasource.dart')),
      );
    });

    test('U25: full depth includes data implementations', () async {
      final included = await includedRel(['product'], SliceDepth.full);

      expect(included, contains('lib/src/data/repositories/data_product_repository.dart'));
      expect(included, contains('lib/src/data/datasources/product_remote_datasource.dart'));
      expect(included, contains('lib/src/di/repositories/product_repository_di.dart'));
    });

    test('U26: two entries union their closures with dedup', () async {
      final included = await includedRel(
        ['product', 'profile'],
        SliceDepth.feature,
      );

      // Both pages present.
      expect(included, contains('lib/src/presentation/pages/product/product_view.dart'));
      expect(included, contains('lib/src/presentation/pages/profile/profile_view.dart'));
      // Profile-only shared widget now included too (bare barrel import).
      expect(included, contains('lib/src/presentation/widgets/app_card.dart'));
      // The shared usecase file appears exactly once across both closures.
      final shared = included
          .where((p) => p == 'lib/src/domain/usecases/shared/fetch_settings_usecase.dart')
          .toList();
      expect(shared, hasLength(1));
      expect(included, contains('lib/src/di/usecases/fetch_settings_usecase_di.dart'));
    });

    test('boundaries at feature depth name the repository interface with its '
        'di registration file', () async {
      final entries = walker.resolveEntrySpecs(['product'], projectRoot);
      final result = await walker.walk(
        entries: entries,
        projectRoot: projectRoot,
        resolver: resolver,
        depth: SliceDepth.feature,
      );

      final repoBoundary = result.boundaries.where(
        (b) => b.typeName == 'ProductRepository',
      );
      expect(repoBoundary, isNotEmpty);
      expect(
        repoBoundary.single.interfaceFile,
        endsWith('lib/src/domain/repositories/product_repository.dart'),
      );
      expect(
        repoBoundary.single.diRegistrationFile,
        endsWith('lib/src/di/repositories/product_repository_di.dart'),
      );
    });

    test('boundaries at view depth name the presenter', () async {
      final entries = walker.resolveEntrySpecs(['product'], projectRoot);
      final result = await walker.walk(
        entries: entries,
        projectRoot: projectRoot,
        resolver: resolver,
        depth: SliceDepth.view,
      );

      expect(
        result.boundaries.map((b) => b.typeName),
        contains('ProductPresenter'),
      );
    });

    test('full depth produces no boundaries', () async {
      final entries = walker.resolveEntrySpecs(['product'], projectRoot);
      final result = await walker.walk(
        entries: entries,
        projectRoot: projectRoot,
        resolver: resolver,
        depth: SliceDepth.full,
      );

      expect(result.boundaries, isEmpty);
    });
  });

  group('FileGraph', () {
    test('getTransitiveClosure walks imports transitively', () async {
      final entries = walker.resolveEntrySpecs(['product'], projectRoot);
      final result = await walker.walk(
        entries: entries,
        projectRoot: projectRoot,
        resolver: resolver,
        depth: SliceDepth.view,
      );
      final graph = result.graph;

      final viewPath = graph.nodes.keys
          .singleWhere((p) => p.endsWith('product_view.dart'));
      final closure = graph.getTransitiveClosure(viewPath);

      // controller and state are reachable; primary_button via the barrel.
      expect(
        closure,
        allOf(
          contains(viewPath),
          contains(graph.nodes.keys.singleWhere(
            (p) => p.endsWith('product_controller.dart'),
          )),
          contains(graph.nodes.keys.singleWhere(
            (p) => p.endsWith('primary_button.dart'),
          )),
        ),
      );
      expect(graph.packageName, equals('zik_zak'));
      expect(graph.projectRoot, equals(projectRoot));
    });
  });
}
