// Regression test for issue #328:
// https://github.com/arrrrny/zuraffa/issues/328
//
// Two contract mismatches between `zfa route create` and `zfa view create`:
//
//   A. `zfa route create --methods=get,getList` emitted an import for
//      `<entity>_detail_view.dart` and referenced `<Entity>DetailView`
//      even when no such file existed on disk. `zfa view create` only
//      emits a separate detail-view file when the view was generated with
//      BOTH a list method (getList/watchList) AND a detail method
//      (get/watch). When the view was created with different methods than
//      the route (the common smoke-test case: view defaults to
//      `get,update`, then route is run with `get,getList`), the detail
//      view file does not exist, and analyze flagged `uri_does_not_exist`.
//
//   B. `zfa route create` always passed `View(entityCamel: state.extra as
//      Entity?)` for CRUD-backed entities, but `zfa view create` only
//      added the `entityCamel` named-param to the view constructor under
//      `--state`. Without `--state` the route's named-arg had no matching
//      constructor parameter, producing `extra_positional_arguments` /
//      undefined named-param errors.
//
// Fix:
//   - route_builder.dart probes the actual `<entity>_detail_view.dart`
//     file on disk and only emits the `DetailView` reference + import
//     when the file exists.
//   - view_plugin.dart emits the `entityCamel` field (and entity import)
//     whenever the entity is CRUD-backed (`isEntityBased`), not just
//     under `--state`.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_issue328_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ─────────────────────────────────────────────────────────────────
  // Bug A: route builder must not reference a non-existent detail view
  // ─────────────────────────────────────────────────────────────────

  group('issue #328 A — route/view detail_view contract', () {
    test(
      'route does NOT import detail_view.dart when no detail view file '
      'exists on disk',
      () async {
        final builder = RouteBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        // Simulate the smoke-test scenario: route create with
        // --methods=get,getList but NO view files generated yet (or view
        // was generated with different methods).
        await builder.generate(
          GeneratorConfig(
            name: 'ZikZakScore',
            methods: const ['get', 'getList'],
            generateVpcs: true,
            generateRoute: true,
            outputDir: outputDir,
          ),
        );

        final routesFile = File(
          '$outputDir/routing/zik_zak_score_routes.dart',
        );
        expect(routesFile.existsSync(), isTrue);
        final content = routesFile.readAsStringSync();

        // Must NOT import the non-existent detail view file.
        expect(
          content.contains('zik_zak_score_detail_view.dart'),
          isFalse,
          reason:
              'route must not import <entity>_detail_view.dart when the '
              'file does not exist on disk (was the cause of 53× '
              'uri_does_not_exist errors in issue #328).',
        );
        // Must NOT reference the non-existent DetailView class.
        expect(
          content.contains('ZikZakScoreDetailView'),
          isFalse,
          reason:
              'route must not reference <Entity>DetailView when the '
              'detail view file does not exist on disk.',
        );
        // The detail route should fall back to the main View.
        expect(
          content.contains('ZikZakScoreView'),
          isTrue,
          reason: 'detail route should use the main <Entity>View.',
        );
        // The list view import must still be present.
        expect(
          content.contains('zik_zak_score_view.dart'),
          isTrue,
          reason: 'route must still import the main view file.',
        );
      },
    );

    test(
      'route DOES import detail_view.dart when the detail view file '
      'exists on disk',
      () async {
        // Simulate `zfa view create --methods=get,getList` having been
        // run first, which generates both <entity>_view.dart and
        // <entity>_detail_view.dart.
        final viewDir = Directory(
          '$outputDir/presentation/pages/zik_zak_score',
        );
        await viewDir.create(recursive: true);
        // Touch both view files so the route builder's filesystem probe
        // finds the detail view.
        await File('${viewDir.path}/zik_zak_score_view.dart').writeAsString(
          '// stub view file\n',
        );
        await File(
          '${viewDir.path}/zik_zak_score_detail_view.dart',
        ).writeAsString('// stub detail view file\n');

        final builder = RouteBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        await builder.generate(
          GeneratorConfig(
            name: 'ZikZakScore',
            methods: const ['get', 'getList'],
            generateVpcs: true,
            generateRoute: true,
            outputDir: outputDir,
          ),
        );

        final routesFile = File(
          '$outputDir/routing/zik_zak_score_routes.dart',
        );
        expect(routesFile.existsSync(), isTrue);
        final content = routesFile.readAsStringSync();

        // When the detail view file exists, the route SHOULD import it.
        expect(
          content.contains('zik_zak_score_detail_view.dart'),
          isTrue,
          reason:
              'route must import <entity>_detail_view.dart when the file '
              'exists on disk (the master/detail contract).',
        );
        // And reference the DetailView class.
        expect(
          content.contains('ZikZakScoreDetailView'),
          isTrue,
          reason:
              'route must reference <Entity>DetailView when the detail '
              'view file exists on disk.',
        );
      },
    );

    test(
      'route falls back to main View for detail route when only the '
      'list view exists (no detail file)',
      () async {
        // Only the list view file exists, not the detail view.
        final viewDir = Directory(
          '$outputDir/presentation/pages/product',
        );
        await viewDir.create(recursive: true);
        await File('${viewDir.path}/product_view.dart').writeAsString(
          '// stub view file\n',
        );
        // Note: product_detail_view.dart is intentionally NOT created.

        final builder = RouteBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        await builder.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList', 'create'],
            generateVpcs: true,
            generateRoute: true,
            outputDir: outputDir,
          ),
        );

        final routesFile = File('$outputDir/routing/product_routes.dart');
        expect(routesFile.existsSync(), isTrue);
        final content = routesFile.readAsStringSync();

        expect(
          content.contains('product_detail_view.dart'),
          isFalse,
          reason: 'detail view file does not exist; must not be imported.',
        );
        expect(
          content.contains('ProductDetailView'),
          isFalse,
          reason: 'detail view class does not exist; must not be referenced.',
        );
        // The detail route should use ProductView (the main view).
        expect(
          content.contains('ProductView'),
          isTrue,
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────
  // Bug B: view constructor must accept the entity named-param
  // ─────────────────────────────────────────────────────────────────

  group('issue #328 B — view constructor entity named-param', () {
    test(
      'view constructor accepts entity named-param when CRUD-backed '
      'WITHOUT --state',
      () async {
        // Default zfa view create: methods=get,update, no --state flag.
        // Before the fix, the constructor only had {super.key,
        // super.routeObserver, required this.repository, this.id} and
        // did NOT accept `this.<entityCamel>`, so the route's
        // `View(entityCamel: state.extra as Entity?)` call failed.
        final plugin = ViewPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        final files = await plugin.generate(
          GeneratorConfig(
            name: 'ZikZakScore',
            methods: const ['get', 'update'],
            generateView: true,
            outputDir: outputDir,
          ),
        );
        expect(files, isNotEmpty);
        final content = files.first.content ?? '';

        // The constructor must accept the entity named-param.
        // The field is emitted as `this.zikZakScore` (a `final` field
        // initialized via the constructor).
        expect(
          content.contains('this.zikZakScore,'),
          isTrue,
          reason:
              'view constructor must accept the entity named-param '
              '(this.zikZakScore) when the entity is CRUD-backed, even '
              'without --state. The route generator passes '
              '`zikZakScore: state.extra as ZikZakScore?` and the view '
              'must accept it (issue #328 class B).',
        );
        // The entity import must be present (the field type references
        // the entity class).
        expect(
          content.contains(
            '../domain/entities/zik_zak_score/zik_zak_score.dart',
          ),
          isTrue,
          reason:
              'entity import must be present when the constructor '
              'accepts the entity named-param.',
        );
      },
    );

    test(
      'view constructor accepts entity named-param when --state is set '
      '(existing behavior preserved)',
      () async {
        final plugin = ViewPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList'],
            generateView: true,
            generateState: true,
            outputDir: outputDir,
          ),
        );
        expect(files, isNotEmpty);
        // Find the list view file (not the detail view).
        final listViewFile = files.firstWhere(
          (f) => f.path.contains('product_view.dart'),
        );
        final content = listViewFile.content ?? '';

        expect(
          content.contains('this.product,'),
          isTrue,
          reason:
              'view constructor must accept the entity named-param '
              '(this.product) under --state (existing behavior).',
        );
      },
    );

    test(
      'view constructor does NOT accept entity named-param when '
      'noEntity is true',
      () async {
        final plugin = ViewPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Notification',
            methods: const ['get', 'update'],
            generateView: true,
            noEntity: true,
            outputDir: outputDir,
          ),
        );
        expect(files, isNotEmpty);
        final content = files.first.content ?? '';

        expect(
          content.contains('this.notification,'),
          isFalse,
          reason:
              'view constructor must NOT accept the entity named-param '
              'when noEntity is true (non-entity-backed view).',
        );
      },
    );

    test(
      'route passes entity named-param using the exact camelCase name '
      'the view declares',
      () async {
        // Generate the view first (so the detail view file exists and
        // the route builder picks the DetailView path).
        final viewPlugin = ViewPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        await viewPlugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList'],
            generateView: true,
            outputDir: outputDir,
          ),
        );

        // Now generate routes with the same methods.
        final routeBuilder = RouteBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        await routeBuilder.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList'],
            generateVpcs: true,
            generateRoute: true,
            outputDir: outputDir,
          ),
        );

        final routesFile = File('$outputDir/routing/product_routes.dart');
        expect(routesFile.existsSync(), isTrue);
        final routeContent = routesFile.readAsStringSync();

        // The route must pass the entity named-param.
        expect(
          routeContent.contains('product: (state.extra as Product?)'),
          isTrue,
          reason:
              'route must pass the entity named-param using the exact '
              'camelCase name the view declares.',
        );

        // And the view file must accept it.
        final viewFile = File(
          '$outputDir/presentation/pages/product/product_view.dart',
        );
        expect(viewFile.existsSync(), isTrue);
        final viewContent = viewFile.readAsStringSync();
        expect(
          viewContent.contains('this.product,'),
          isTrue,
          reason: 'view must accept the entity named-param the route passes.',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────
  // End-to-end contract: route + view generated together must compile
  // ─────────────────────────────────────────────────────────────────

  group('issue #328 end-to-end route+view contract', () {
    test(
      'route references only view files that actually exist on disk',
      () async {
        // Generate the view with default methods (get,update) — only
        // product_view.dart is created, no product_detail_view.dart.
        final viewPlugin = ViewPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        await viewPlugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'update'],
            generateView: true,
            outputDir: outputDir,
          ),
        );

        // Now generate routes with a DIFFERENT methods list
        // (--methods=get,getList) — the smoke-test scenario from #328.
        final routeBuilder = RouteBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        await routeBuilder.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList'],
            generateVpcs: true,
            generateRoute: true,
            outputDir: outputDir,
          ),
        );

        final routesFile = File('$outputDir/routing/product_routes.dart');
        expect(routesFile.existsSync(), isTrue);
        final content = routesFile.readAsStringSync();

        // Collect every view import the route references.
        final viewImportPattern = RegExp(
          r"import\s+'([^']*_view\.dart)';",
        );
        final importedViews = viewImportPattern
            .allMatches(content)
            .map((m) => m.group(1)!)
            .toList();

        // The route file lives at <outputDir>/routing/product_routes.dart,
        // so relative imports resolve against <outputDir>/routing/.
        final routeDir = path.join(outputDir, 'routing');

        // Every imported view file must actually exist on disk.
        for (final importPath in importedViews) {
          final resolvedPath = path.normalize(
            path.join(routeDir, importPath),
          );
          expect(
            File(resolvedPath).existsSync(),
            isTrue,
            reason:
                'route imports `$importPath` but the file does not exist '
                'at $resolvedPath. This is the #328 contract violation: '
                'the route generator must only import view files that '
                'actually exist on disk.',
          );
        }
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────
  // Regeneration: existing route files must stay synchronized when the
  // detail-view file appears or disappears between runs.
  // ─────────────────────────────────────────────────────────────────

  group('issue #328 — detail-view availability sync on regeneration', () {
    GeneratorConfig makeConfig() => GeneratorConfig(
      name: 'Product',
      methods: const ['get', 'getList'],
      generateVpcs: true,
      generateRoute: true,
      outputDir: outputDir,
    );

    int routeCount(String content, String routeName) => RegExp(
      "name:\\s*'$routeName'",
    ).allMatches(content).length;

    test(
      'rerun after the detail-view file is deleted removes the stale '
      'import and replaces (not duplicates) the detail route',
      () async {
        final builder = RouteBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        // Run 1: detail view file exists → route uses ProductDetailView.
        final viewDir = Directory('$outputDir/presentation/pages/product');
        await viewDir.create(recursive: true);
        await File('${viewDir.path}/product_view.dart').writeAsString(
          '// stub view file\n',
        );
        final detailFile = File('${viewDir.path}/product_detail_view.dart');
        await detailFile.writeAsString('// stub detail view file\n');

        await builder.generate(makeConfig());
        final routesFile = File('$outputDir/routing/product_routes.dart');
        var content = routesFile.readAsStringSync();
        expect(content.contains('product_detail_view.dart'), isTrue);
        expect(content.contains('ProductDetailView'), isTrue);
        expect(routeCount(content, 'product_detail'), 1);

        // Run 2: detail view file deleted → the existing route file must
        // be synchronized, not appended to.
        await detailFile.delete();
        await builder.generate(makeConfig());

        content = routesFile.readAsStringSync();
        expect(
          content.contains('product_detail_view.dart'),
          isFalse,
          reason:
              'stale detail-view import must be removed when the file no '
              'longer exists (uri_does_not_exist).',
        );
        expect(
          content.contains('ProductDetailView'),
          isFalse,
          reason: 'stale DetailView reference must be removed.',
        );
        expect(
          content.contains('ProductView'),
          isTrue,
          reason: 'detail route must fall back to the main view.',
        );
        expect(
          routeCount(content, 'product_detail'),
          1,
          reason:
              'the detail route must be replaced by stable identity, not '
              'duplicated when its source changes.',
        );

        // Run 3: detail view file reappears → import and DetailView come
        // back, still without duplicating the route.
        await detailFile.writeAsString('// stub detail view file\n');
        await builder.generate(makeConfig());

        content = routesFile.readAsStringSync();
        expect(content.contains('product_detail_view.dart'), isTrue);
        expect(content.contains('ProductDetailView'), isTrue);
        expect(routeCount(content, 'product_detail'), 1);
      },
    );
  });
}
