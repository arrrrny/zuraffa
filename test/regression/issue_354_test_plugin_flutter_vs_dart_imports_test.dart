import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/test/builders/test_builder.dart';

/// #354 regression: zfa test plugin must generate package:test/test.dart
/// (not flutter_test) and package:zuraffa/zuraffa.dart (not
/// zuraffa_flutter) when the target project is pure-Dart (no
/// flutter: sdk: flutter in pubspec.yaml).
void main() {
  group('issue 354 - test plugin Flutter-vs-pure-Dart imports', () {
    late Directory tempDir;
    late String projectRoot;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zuraffa_354_');
      projectRoot = tempDir.path;
      outputDir = path.join(projectRoot, 'lib', 'src');

      // Create minimal project structure so DiscoveryEngine + TestBuilder
      // can resolve paths.
      await Directory(outputDir).create(recursive: true);
      await Directory(
        path.join(outputDir, 'domain', 'entities', 'product'),
      ).create(recursive: true);
      await Directory(
        path.join(outputDir, 'domain', 'usecases', 'product'),
      ).create(recursive: true);
      await Directory(
        path.join(outputDir, 'domain', 'repositories'),
      ).create(recursive: true);
      await Directory(
        path.join(outputDir, 'data', 'repositories'),
      ).create(recursive: true);

      // Entity file (so DiscoveryEngine.findFile resolves).
      await File(
        path.join(
          outputDir, 'domain', 'entities', 'product', 'product.dart',
        ),
      ).writeAsString(
        'class Product { final String id; const Product({required this.id}); }',
      );

      // Repository file.
      await File(
        path.join(
          outputDir,
          'domain',
          'repositories',
          'product_repository.dart',
        ),
      ).writeAsString('abstract class ProductRepository {}');

      // UseCase file (required - generateForMethod skips if absent).
      await File(
        path.join(
          outputDir,
          'domain',
          'usecases',
          'product',
          'get_product_usecase.dart',
        ),
      ).writeAsString('class GetProductUseCase {}');

      // Also create update usecase for zuraffa import check.
      await File(
        path.join(
          outputDir,
          'domain',
          'usecases',
          'product',
          'update_product_usecase.dart',
        ),
      ).writeAsString('class UpdateProductUseCase {}');

      // Also create the generic product usecase for custom builder.
      await File(
        path.join(
          outputDir,
          'domain',
          'usecases',
          'product',
          'product_usecase.dart',
        ),
      ).writeAsString('class ProductUseCase {}');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'pure-Dart pubspec generates test + zuraffa imports',
      () async {
        // Write a pure-Dart pubspec.yaml (no flutter SDK dependency).
        await File(
          path.join(projectRoot, 'pubspec.yaml'),
        ).writeAsString('''
name: my_pure_dart_app
environment:
  sdk: ">=3.11.0 <4.0.0"
dependencies:
  zuraffa:
    git:
      url: https://github.com/arrrrny/zuraffa
dev_dependencies:
  test: ^1.25.0
  mocktail: ^1.0.4
''');

        final fs = FileSystem.create(root: projectRoot);
        final builder = TestBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
          fileSystem: fs,
          discovery: DiscoveryEngine(
            projectRoot: projectRoot,
            fileSystem: fs,
          ),
        );

        // Generate a test for get (uses test framework import only).
        final getFile = await builder.generateForMethod(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get'],
            outputDir: outputDir,
          ),
          'get',
        );

        expect(
          getFile.action,
          isNot(equals('skipped')),
          reason: 'get test should be generated, not skipped',
        );
        expect(getFile.content, isNotNull);
        // Must NOT import flutter_test.
        expect(getFile.content!, isNot(contains('flutter_test')));
        // Must NOT import zuraffa_flutter.
        expect(getFile.content!, isNot(contains('zuraffa_flutter')));
        // Must import package:test/test.dart.
        expect(getFile.content!, contains('package:test/test.dart'));
        // Must import mocktail.
        expect(getFile.content!, contains('package:mocktail/mocktail.dart'));

        // Generate a test for update (uses zuraffa core import too).
        final updateFile = await builder.generateForMethod(
          GeneratorConfig(
            name: 'Product',
            methods: const ['update'],
            outputDir: outputDir,
          ),
          'update',
        );

        expect(
          updateFile.action,
          isNot(equals('skipped')),
          reason: 'update test should be generated',
        );
        expect(updateFile.content, isNotNull);
        expect(updateFile.content!, isNot(contains('flutter_test')));
        expect(updateFile.content!, isNot(contains('zuraffa_flutter')));
        expect(updateFile.content!, contains('package:test/test.dart'));
        // update needs zuraffa core import - must be zuraffa, not zuraffa_flutter.
        expect(updateFile.content!, contains('package:zuraffa/zuraffa.dart'));
      },
    );

    test(
      'Flutter pubspec generates flutter_test + zuraffa_flutter imports',
      () async {
        // Write a Flutter pubspec.yaml (has flutter SDK dependency).
        await File(
          path.join(projectRoot, 'pubspec.yaml'),
        ).writeAsString('''
name: my_flutter_app
environment:
  sdk: ">=3.11.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter:
    git:
      url: https://github.com/arrrrny/zuraffa
      path: zuraffa_flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
''');

        final fs = FileSystem.create(root: projectRoot);
        final builder = TestBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
          fileSystem: fs,
          discovery: DiscoveryEngine(
            projectRoot: projectRoot,
            fileSystem: fs,
          ),
        );

        // Generate a test for get.
        final getFile = await builder.generateForMethod(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get'],
            outputDir: outputDir,
          ),
          'get',
        );

        expect(getFile.action, isNot(equals('skipped')));
        expect(getFile.content, isNotNull);
        // Must import flutter_test.
        expect(
          getFile.content!,
          contains('package:flutter_test/flutter_test.dart'),
        );
        // Must import mocktail.
        expect(getFile.content!, contains('package:mocktail/mocktail.dart'));

        // Generate a test for update (needs zuraffa_flutter core import).
        final updateFile = await builder.generateForMethod(
          GeneratorConfig(
            name: 'Product',
            methods: const ['update'],
            outputDir: outputDir,
          ),
          'update',
        );

        expect(updateFile.action, isNot(equals('skipped')));
        expect(updateFile.content, isNotNull);
        expect(
          updateFile.content!,
          contains('package:flutter_test/flutter_test.dart'),
        );
        // update needs zuraffa core import - must be zuraffa_flutter for Flutter.
        expect(
          updateFile.content!,
          contains('package:zuraffa_flutter/zuraffa_flutter.dart'),
        );
      },
    );

    test(
      'missing pubspec.yaml defaults to pure-Dart (test + zuraffa imports)',
      () async {
        // Do NOT write a pubspec.yaml - the builder should fall back to
        // pure-Dart (conservative default matching DependencyWirer).
        final fs = FileSystem.create(root: projectRoot);
        final builder = TestBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
          fileSystem: fs,
          discovery: DiscoveryEngine(
            projectRoot: projectRoot,
            fileSystem: fs,
          ),
        );

        final getFile = await builder.generateForMethod(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get'],
            outputDir: outputDir,
          ),
          'get',
        );

        expect(getFile.action, isNot(equals('skipped')));
        expect(getFile.content, isNotNull);
        expect(getFile.content!, isNot(contains('flutter_test')));
        expect(getFile.content!, contains('package:test/test.dart'));
      },
    );

    test('custom test builder respects pure-Dart imports', () async {
      // Write a pure-Dart pubspec.yaml.
      await File(
        path.join(projectRoot, 'pubspec.yaml'),
      ).writeAsString('''
name: my_pure_dart_app
environment:
  sdk: ">=3.11.0 <4.0.0"
dependencies:
  zuraffa:
    git:
      url: https://github.com/arrrrny/zuraffa
''');

      final fs = FileSystem.create(root: projectRoot);
      final builder = TestBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
        discovery: DiscoveryEngine(
          projectRoot: projectRoot,
          fileSystem: fs,
        ),
      );

      final file = await builder.generateCustom(
        GeneratorConfig(
          name: 'Product',
          methods: const ['custom'],
          outputDir: outputDir,
        ),
      );

      expect(file.content, isNotNull);
      expect(file.content!, isNot(contains('flutter_test')));
      expect(file.content!, isNot(contains('zuraffa_flutter')));
      expect(file.content!, contains('package:test/test.dart'));
      expect(file.content!, contains('package:zuraffa/zuraffa.dart'));
    });

    test('orchestrator test builder respects pure-Dart imports', () async {
      // Write a pure-Dart pubspec.yaml.
      await File(
        path.join(projectRoot, 'pubspec.yaml'),
      ).writeAsString('''
name: my_pure_dart_app
environment:
  sdk: ">=3.11.0 <4.0.0"
dependencies:
  zuraffa:
    git:
      url: https://github.com/arrrrny/zuraffa
''');

      final fs = FileSystem.create(root: projectRoot);
      final builder = TestBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
        discovery: DiscoveryEngine(
          projectRoot: projectRoot,
          fileSystem: fs,
        ),
      );

      final file = await builder.generateOrchestrator(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'update'],
          outputDir: outputDir,
        ),
      );

      expect(file.content, isNotNull);
      expect(file.content!, isNot(contains('flutter_test')));
      expect(file.content!, isNot(contains('zuraffa_flutter')));
      expect(file.content!, contains('package:test/test.dart'));
      expect(file.content!, contains('package:zuraffa/zuraffa.dart'));
    });

    test('polymorphic test builder respects pure-Dart imports', () async {
      // Write a pure-Dart pubspec.yaml.
      await File(
        path.join(projectRoot, 'pubspec.yaml'),
      ).writeAsString('''
name: my_pure_dart_app
environment:
  sdk: ">=3.11.0 <4.0.0"
dependencies:
  zuraffa:
    git:
      url: https://github.com/arrrrny/zuraffa
''');

      final fs = FileSystem.create(root: projectRoot);
      final builder = TestBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
        discovery: DiscoveryEngine(
          projectRoot: projectRoot,
          fileSystem: fs,
        ),
      );

      final files = await builder.generatePolymorphic(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          variants: const ['Get'],
          repo: 'Product',
          outputDir: outputDir,
        ),
      );

      expect(files, isNotEmpty);
      for (final file in files) {
        if (file.content == null) continue;
        expect(
          file.content!,
          isNot(contains('flutter_test')),
          reason:
            'polymorphic test should not import flutter_test in pure-Dart',
        );
        expect(
          file.content!,
          isNot(contains('zuraffa_flutter')),
          reason:
            'polymorphic test should not import zuraffa_flutter in pure-Dart',
        );
        expect(
          file.content!,
          contains('package:test/test.dart'),
          reason:
            'polymorphic test must import package:test/test.dart in pure-Dart',
        );
        expect(
          file.content!,
          contains('package:zuraffa/zuraffa.dart'),
          reason:
            'polymorphic test must import package:zuraffa/zuraffa.dart in pure-Dart',
        );
      }
    });
  });
}
