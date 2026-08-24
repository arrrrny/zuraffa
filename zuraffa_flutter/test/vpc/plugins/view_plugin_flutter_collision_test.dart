import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/vpc_test_utils.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_view_337_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    // Declare a Flutter pubspec so the VPC generators run on their
    // intended target instead of relying on the no-pubspec
    // (unknown flavour) fallback — issues #431 / #435.
    await writeFlutterPubspecAt(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Regression test for #337: an entity named after a Flutter material
  // symbol (`Feedback`) must not produce an ambiguous_import between
  // package:flutter/material.dart and the entity import. The generator must
  // hide the colliding symbol from the material import.
  group('#337 entity named after Flutter symbol', () {
    test('hides colliding Flutter symbol from material import', () async {
      final plugin = ViewPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Feedback',
        methods: const ['get', 'update'],
        generateDi: true,
        generateView: true,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      final content =
          files
              .firstWhere((f) => f.path.contains('feedback_view.dart'))
              .content ??
          '';

      // The entity symbol must resolve to the entity, never be ambiguous.
      expect(
        content.contains(
          "import 'package:flutter/material.dart' hide Feedback;",
        ),
        isTrue,
        reason: 'material import must hide the colliding entity symbol',
      );
      expect(
        content.contains("import 'package:flutter/material.dart';"),
        isFalse,
        reason: 'the plain material import must be replaced by the hidden one',
      );
      // The entity import must still be present unqualified.
      expect(
        content.contains('domain/entities/feedback/feedback.dart'),
        isTrue,
      );
      // The view must still reference the entity type.
      expect(content.contains('final Feedback? feedback;'), isTrue);
      expect(content.contains('class FeedbackView'), isTrue);
    });

    test('hides colliding symbol on detail views too', () async {
      final plugin = ViewPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Feedback',
        methods: const ['get', 'getList'],
        generateDi: true,
        generateView: true,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      final detail =
          files
              .firstWhere((f) => f.path.contains('feedback_detail_view.dart'))
              .content ??
          '';
      expect(
        detail.contains(
          "import 'package:flutter/material.dart' hide Feedback;",
        ),
        isTrue,
      );
    });

    test('does not hide symbols for non-colliding entities', () async {
      final plugin = ViewPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateDi: true,
        generateView: true,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      final content =
          files
              .firstWhere((f) => f.path.contains('product_view.dart'))
              .content ??
          '';
      expect(
        content.contains("import 'package:flutter/material.dart';"),
        isTrue,
      );
      expect(content.contains(' hide '), isFalse);
    });

    test('generated view is valid Dart', () async {
      final plugin = ViewPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Feedback',
        methods: const ['get', 'update'],
        generateDi: true,
        generateView: true,
        outputDir: outputDir,
      );
      await plugin.generate(config);
      final viewFile = File(
        '$outputDir/presentation/pages/feedback/feedback_view.dart',
      );
      expect(viewFile.existsSync(), isTrue);

      final result = await Process.run('dart', [
        'format',
        '--output=none',
        viewFile.path,
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
  });
}
