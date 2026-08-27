import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';
import 'package:zuraffa/src/plugins/state/builders/state_builder.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

/// #420 regression: the presentation-layer generators (controller / presenter /
/// view) must not emit Flutter-dependent code (`package:zuraffa_flutter/...`,
/// `package:flutter/material.dart`, `Controller`/`Presenter` base classes) into a
/// pure-Dart target package. Those symbols only exist in the Flutter package and
/// break `dart analyze` (Constitution VII: Engine Purity).
///
/// The generators detect the target project's flavor from its `pubspec.yaml`
/// (derived from `outputDir`). A pubspec that declares `flutter:` is treated as
/// Flutter and generates as before; a pubspec without `flutter:` is treated as
/// pure-Dart and the Flutter-only generation is skipped with a warning.
void main() {
  group('issue 420 - presentation generators skip pure-Dart packages', () {
    late Directory tempDir;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zuraffa_420_');
      outputDir = Directory(p.join(tempDir.path, 'lib', 'src')).path;
      await Directory(outputDir).create(recursive: true);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> writePubspec({required bool flutter}) async {
      final deps = flutter
          ? 'dependencies:\n  flutter:\n    sdk: flutter\n'
          : 'dependencies:\n  zuraffa:\n    git:\n'
                '      url: https://github.com/arrrrny/zuraffa\n';
      await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: demo
environment:
  sdk: ">=3.11.0 <4.0.0"
$deps''');
    }

    group('controller', () {
      test(
        'pure-Dart pubspec => skipped (no zuraffa_flutter emitted)',
        () async {
          await writePubspec(flutter: false);
          final plugin = ControllerPlugin(
            outputDir: outputDir,
            options: const GeneratorOptions(force: true),
          );
          final files = await plugin.generate(
            GeneratorConfig(
              name: 'Product',
              methods: const ['get', 'update'],
              generateController: true,
              outputDir: outputDir,
            ),
          );
          expect(files, isEmpty);
        },
      );

      test('Flutter pubspec => generates Flutter controller', () async {
        await writePubspec(flutter: true);
        final plugin = ControllerPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
        );
        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'update'],
            generateController: true,
            outputDir: outputDir,
          ),
        );
        expect(files, isNotEmpty);
        final content = files.first.content ?? '';
        expect(content, contains('class ProductController extends Controller'));
        expect(
          content,
          contains('package:zuraffa_flutter/zuraffa_flutter.dart'),
        );
      });
    });

    group('presenter', () {
      test(
        'pure-Dart pubspec => skipped (no zuraffa_flutter emitted)',
        () async {
          await writePubspec(flutter: false);
          final plugin = PresenterPlugin(
            outputDir: outputDir,
            options: const GeneratorOptions(force: true),
          );
          final files = await plugin.generate(
            GeneratorConfig(
              name: 'Product',
              methods: const ['get', 'getList'],
              generatePresenter: true,
              outputDir: outputDir,
            ),
          );
          expect(files, isEmpty);
        },
      );

      test('Flutter pubspec => generates Flutter presenter', () async {
        await writePubspec(flutter: true);
        final plugin = PresenterPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
        );
        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList'],
            generatePresenter: true,
            outputDir: outputDir,
          ),
        );
        expect(files, isNotEmpty);
        final content = files.first.content ?? '';
        expect(content, contains('class ProductPresenter extends Presenter'));
        expect(
          content,
          contains('package:zuraffa_flutter/zuraffa_flutter.dart'),
        );
      });
    });

    group('view', () {
      test(
        'pure-Dart pubspec => skipped (no flutter/material emitted)',
        () async {
          await writePubspec(flutter: false);
          final plugin = ViewPlugin(
            outputDir: outputDir,
            options: const GeneratorOptions(force: true),
          );
          final files = await plugin.generate(
            GeneratorConfig(
              name: 'Product',
              methods: const ['get', 'update'],
              generateDi: true,
              generateView: true,
              outputDir: outputDir,
            ),
          );
          expect(files, isEmpty);
        },
      );

      test('Flutter pubspec => generates Flutter view', () async {
        await writePubspec(flutter: true);
        final plugin = ViewPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
        );
        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'update'],
            generateDi: true,
            generateView: true,
            outputDir: outputDir,
          ),
        );
        expect(files, isNotEmpty);
        final content = files.first.content ?? '';
        expect(content, contains('package:flutter/material.dart'));
      });
    });

    // #512: the state generator must follow the target flavor. A pure-Dart
    // target (no `flutter:` SDK) must import zuraffa *core* (AppFailure lives
    // there) so generated pure-Dart code compiles; a Flutter target keeps the
    // historical zuraffa_flutter import.
    group('state', () {
      test(
        'pure-Dart pubspec => imports package:zuraffa (not zuraffa_flutter)',
        () async {
          await writePubspec(flutter: false);
          final builder = StateBuilder(
            outputDir: outputDir,
            options: const GeneratorOptions(force: true),
          );
          final file = await builder.generate(
            GeneratorConfig(
              name: 'Product',
              methods: const ['get', 'getList', 'update'],
              generateState: true,
              outputDir: outputDir,
            ),
          );
          final content = file.content ?? '';
          expect(content, contains('package:zuraffa/zuraffa.dart'));
          expect(content, isNot(contains('package:zuraffa_flutter/')));
        },
      );

      test('Flutter pubspec => imports package:zuraffa_flutter', () async {
        await writePubspec(flutter: true);
        final builder = StateBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
        );
        final file = await builder.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList', 'update'],
            generateState: true,
            outputDir: outputDir,
          ),
        );
        final content = file.content ?? '';
        expect(
          content,
          contains('package:zuraffa_flutter/zuraffa_flutter.dart'),
        );
      });
    });
  });
}
