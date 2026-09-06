// Bug 1198 (part of #908 P0) — template self-hosting: `view`/`skin`
// template.
//
// Trust-tier loop against the fixture entity: structural + byte-stability
// diff guard run in the pure-Dart lane; the compile + behavioral tiers run
// in the downstream-compile gate (`downstream_compile_gate_test.dart`,
// tagged `flutter`) because the emitted view imports Flutter and
// zuraffa_flutter.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late Directory bare;

  setUpAll(() async {
    bare = await createTempFixture('view_bare');
    // Flutter flavor marker — the view plugin's #420 gate skips pure-Dart
    // targets, so the fixture must look like a Flutter app.
    await File(p.join(bare.path, 'pubspec.yaml')).writeAsString('''
name: view_bare_fixture
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''');
    // The view cluster (view + controller + presenter) imports the entity
    // AND the repository interface at the project-root domain/ tree.
    await writeFixtureEntity(bare, withRepository: true, libDir: 'domain');
  });

  tearDownAll(() async {
    if (bare.existsSync()) bare.delete(recursive: true);
  });

  Future<List<({String path, String? content})>> generateInto(
    Directory root,
  ) async {
    final files =
        await ViewPlugin(
          outputDir: root.path,
          options: kSelfHostOptions,
        ).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateView: true,
            outputDir: root.path,
          ),
        );
    return files.map((f) => (path: f.path, content: f.content)).toList();
  }

  group('structural', () {
    test('emits master + detail views for get + getList', () async {
      final files = await generateInto(bare);
      expect(files, hasLength(2));
      final paths = files.map((f) => f.path).toSet();
      expect(
        paths,
        containsAll(<Matcher>[
          contains('presentation/pages/product/product_view.dart'),
          contains('presentation/pages/product/product_detail_view.dart'),
        ]),
      );
    });

    test('declares the fixture-entity view contract', () async {
      final files = await generateInto(bare);
      final content = generatedContent(files, bare, 'product_view.dart');
      expect(content, contains('class ProductView extends CleanView'));
      expect(
        content,
        contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart'"),
      );
      expect(
        content,
        contains("import '../../../domain/entities/product/product.dart';"),
      );
    });
  });

  group('diff guard', () {
    test(
      'regeneration with identical inputs is byte-stable (receipt)',
      () async {
        await expectByteStable(
          template: 'view',
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
                await ViewPlugin(
                  outputDir: root.path,
                  options: kSelfHostOptions,
                ).generate(
                  GeneratorConfig(
                    name: kFixtureEntityName,
                    methods: const ['get', 'getList'],
                    generateView: true,
                    outputDir: root.path,
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
