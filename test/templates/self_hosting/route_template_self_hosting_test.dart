// Bug 1198 (part of #908 P0) — template self-hosting: `route` template.
//
// Trust-tier loop against the fixture entity: structural (route table +
// declared routes manifest + generated route-table test) + byte-stability
// diff guard run in the pure-Dart lane; the compile + behavioral tiers run
// in the downstream-compile gate (`downstream_compile_gate_test.dart`,
// tagged `flutter`) because the emitted routing imports Flutter, go_router
// and the generated view.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late Directory bare;

  setUpAll(() async {
    bare = await createTempFixture('route_bare');
    // Flutter flavor marker — the route template skips pure-Dart targets
    // (Constitution VII engine purity: routes depend on go_router +
    // zuraffa_flutter).
    await File(p.join(bare.path, 'pubspec.yaml')).writeAsString('''
name: route_bare_fixture
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''');
    await writeFixtureEntity(bare);
  });

  tearDownAll(() async {
    if (bare.existsSync()) bare.delete(recursive: true);
  });

  Future<List<({String path, String? content})>> generateInto(
    Directory root,
  ) async {
    final files =
        await RoutePlugin(
          outputDir: p.join(root.path, 'lib', 'src'),
          options: kSelfHostOptions,
        ).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateRoute: true,
            outputDir: p.join(root.path, 'lib', 'src'),
          ),
        );
    return files.map((f) => (path: f.path, content: f.content)).toList();
  }

  group('structural', () {
    test(
      'emits app_routes + entity_routes + index + route-table test',
      () async {
        final files = await generateInto(bare);
        expect(files, hasLength(4));
        final paths = files.map((f) => f.path).toSet();
        expect(
          paths,
          containsAll(<Matcher>[
            contains('lib/src/routing/app_routes.dart'),
            contains('lib/src/routing/product_routes.dart'),
            contains('lib/src/routing/index.dart'),
            contains('test/routing/route_table_test.dart'),
          ]),
        );
      },
    );

    test(
      'declares the fixture-entity routes and the #842 table test',
      () async {
        final files = await generateInto(bare);
        String contentOf(String suffix) =>
            generatedContent(files, bare, suffix);

        final entityRoutes = contentOf('product_routes.dart');
        expect(entityRoutes, contains('abstract class ProductRoutes'));
        expect(
          entityRoutes,
          contains("static const String productList = '/product'"),
        );
        expect(entityRoutes, contains('List<GoRoute> productRoutes()'));

        final tableTest = contentOf('route_table_test.dart');
        // The generated route-table test is the route template's OWN
        // behavioral referee (#842): every declared route resolves to a
        // builder, unknown paths 404, deep links parse.
        expect(tableTest, contains('kDeclaredRoutes'));
        expect(tableTest, contains("'/product': 'ProductRoutes.productList'"));
        expect(
          tableTest,
          contains("import 'package:flutter_test/flutter_test.dart';"),
        );
      },
    );
  });

  group('diff guard', () {
    test(
      'regeneration with identical inputs is byte-stable (receipt)',
      () async {
        await expectByteStable(
          template: 'route',
          pubspec: (name) =>
              '''
name: $name
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''',
          withRepository: true,
          generate: (root) async {
            final files =
                await RoutePlugin(
                  outputDir: p.join(root.path, 'lib', 'src'),
                  options: kSelfHostOptions,
                ).generate(
                  GeneratorConfig(
                    name: kFixtureEntityName,
                    methods: const ['get', 'getList'],
                    generateRoute: true,
                    outputDir: p.join(root.path, 'lib', 'src'),
                  ),
                );
            return files
                .map((f) => (path: f.path, content: f.content))
                .toList();
          },
        );
      },
    );
  });
}
