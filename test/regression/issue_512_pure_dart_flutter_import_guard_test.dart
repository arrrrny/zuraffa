@Tags(['regression', 'slow'])
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/create_command.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';
import 'package:zuraffa/src/plugins/shadcn/builders/shadcn_builder.dart';
import 'package:zuraffa/src/plugins/xray/xray_deck_barrel_writer.dart';

/// #512 regression: several generators emit Flutter-only code
/// (`package:flutter/material.dart`, `package:flutter/widgets.dart`,
/// `package:go_router/go_router.dart`, `package:zuraffa_flutter/...`) into the
/// TARGET project without checking whether that target is a pure-Dart package.
/// When a user creates a pure-Dart project and runs these generators, the
/// generated code cannot resolve Flutter symbols, producing ~2010
/// `dart analyze` errors.
///
/// The fix mirrors the existing #420 pattern (issue #420): each generator
/// detects the target project's flavor from its `pubspec.yaml` (derived from
/// the target dir) and skips Flutter-only generation for a pure-Dart target
/// (a clear warning is printed). A `pubspec.yaml` declaring `flutter:` is
/// treated as Flutter and generates as before; a pubspec without `flutter:`
/// is treated as pure-Dart and skipped; no pubspec found (unknown) keeps the
/// historical Flutter-first generation so existing behavior (and tests that
/// run without a pubspec) is preserved.
void main() {
  group('issue 512 - generators skip pure-Dart packages', () {
    late Directory tempDir;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zuraffa_512_');
      outputDir = Directory(p.join(tempDir.path, 'lib', 'src')).path;
      await Directory(outputDir).create(recursive: true);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// Writes a `pubspec.yaml` into the project root. [flutter] controls
    /// whether the `flutter:` SDK dependency is declared.
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

    group('route', () {
      test('pure-Dart pubspec => no route files emitted', () async {
        await writePubspec(flutter: false);
        final builder = RouteBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
          fileSystem: FileSystem.create(),
        );
        final files = await builder.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList'],
            generateRoute: true,
            outputDir: outputDir,
          ),
        );
        expect(files, isEmpty);
      });

      test('Flutter pubspec => emits route files (go_router)', () async {
        await writePubspec(flutter: true);
        final builder = RouteBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
          fileSystem: FileSystem.create(),
        );
        final files = await builder.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList'],
            generateRoute: true,
            outputDir: outputDir,
          ),
        );
        expect(files, isNotEmpty);
        final content = files.first.content ?? '';
        expect(content, contains('package:go_router/go_router.dart'));
      });
    });

    group('shadcn', () {
      test('pure-Dart pubspec => no shadcn widget emitted', () async {
        await writePubspec(flutter: false);
        final builder = ShadcnBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
          fileSystem: FileSystem.create(),
        );
        final files = await builder.generate(
          GeneratorConfig(name: 'Product', outputDir: outputDir),
          <String, dynamic>{},
        );
        expect(files, isEmpty);
      });

      test('Flutter pubspec => emits Flutter shadcn widget', () async {
        await writePubspec(flutter: true);
        // Provide a minimal entity so the widget builder can resolve fields.
        final entityDir = Directory(
          p.join(outputDir, 'domain', 'entities', 'product'),
        );
        await entityDir.create(recursive: true);
        await File(p.join(entityDir.path, 'product.dart')).writeAsString(
          'class Product { final String id; const Product({required this.id}); }',
        );
        final builder = ShadcnBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
          fileSystem: FileSystem.create(),
        );
        final files = await builder.generate(
          GeneratorConfig(name: 'Product', outputDir: outputDir),
          <String, dynamic>{},
        );
        expect(files, isNotEmpty);
        final content = files.first.content ?? '';
        expect(content, contains('package:flutter/material.dart'));
        expect(content, contains('package:shadcn_ui/shadcn_ui.dart'));
      });
    });

    group('xray deck barrel', () {
      test('pure-Dart pubspec => barrel not created', () async {
        await writePubspec(flutter: false);
        final writer = XRayDeckBarrelWriter(projectRoot: tempDir.path);
        final deckPath = p.join(
          tempDir.path,
          'lib',
          'src',
          'xray',
          'user_xray_deck.dart',
        );
        final result = writer.update(
          entityName: 'User',
          deckFilePath: deckPath,
          registerFunctionName: 'registerUserXRayDeck',
        );
        expect(result.created, isFalse);
        expect(
          File(writer.barrelPath).existsSync(),
          isFalse,
          reason: 'pure-Dart target must not emit the flutter-importing barrel',
        );
      });

      test('Flutter pubspec => barrel created with flutter import', () async {
        await writePubspec(flutter: true);
        final writer = XRayDeckBarrelWriter(projectRoot: tempDir.path);
        final deckPath = p.join(
          tempDir.path,
          'lib',
          'src',
          'xray',
          'user_xray_deck.dart',
        );
        final result = writer.update(
          entityName: 'User',
          deckFilePath: deckPath,
          registerFunctionName: 'registerUserXRayDeck',
        );
        expect(result.created, isTrue);
        final content = File(writer.barrelPath).readAsStringSync();
        expect(content, contains('package:flutter/foundation.dart'));
        expect(content, contains('registerUserXRayDeck();'));
      });
    });

    group('create command (page)', () {
      test('pure-Dart pubspec => no Flutter view file created', () async {
        await writePubspec(flutter: false);
        final command = CreateCommand();
        await command.createPage('user_profile', root: tempDir.path);

        final viewFile = File(
          p.join(
            tempDir.path,
            'lib',
            'src',
            'app',
            'pages',
            'user_profile',
            'user_profile_view.dart',
          ),
        );
        expect(
          viewFile.existsSync(),
          isFalse,
          reason: 'pure-Dart target must not emit a Flutter view',
        );
      });

      test(
        'Flutter pubspec => creates Flutter view/presenter/controller',
        () async {
          await writePubspec(flutter: true);
          // Create only the parent pages dir; createPage itself creates the
          // per-page subdir, so pre-creating the leaf would trip the
          // "page already exists" guard.
          final pagesDir = Directory(
            p.join(tempDir.path, 'lib', 'src', 'app', 'pages'),
          );
          await pagesDir.create(recursive: true);

          final command = CreateCommand();
          await command.createPage('user_profile', root: tempDir.path);

          final pageDir = p.join(pagesDir.path, 'user_profile');
          final viewFile = File(p.join(pageDir, 'user_profile_view.dart'));
          final controllerFile = File(
            p.join(pageDir, 'user_profile_controller.dart'),
          );
          final presenterFile = File(
            p.join(pageDir, 'user_profile_presenter.dart'),
          );
          expect(viewFile.existsSync(), isTrue);
          expect(controllerFile.existsSync(), isTrue);
          expect(presenterFile.existsSync(), isTrue);

          final viewSrc = viewFile.readAsStringSync();
          expect(viewSrc, contains('package:flutter/material.dart'));
          expect(viewSrc, contains('class UserProfileView extends CleanView'));
        },
      );
    });

    group('app shell command (caller-level guard)', () {
      late Directory workspace;

      setUp(() async {
        workspace = await Directory.systemTemp.createTemp('zuraffa_512_shell_');
        // Scaffold the canonical zfa-generated DI + routing barrels so the
        // Flutter path can pass the pre-flight validation and generate.
        final diDir = Directory(p.join(workspace.path, 'lib', 'src', 'di'))
          ..createSync(recursive: true);
        await File(p.join(diDir.path, 'index.dart')).writeAsString('''
// Generated by zfa
import 'package:get_it/get_it.dart';
void setupDependencies(GetIt getIt) {}
''');
        final routingDir = Directory(
          p.join(workspace.path, 'lib', 'src', 'routing'),
        )..createSync(recursive: true);
        await File(p.join(routingDir.path, 'index.dart')).writeAsString('''
// Generated by zfa
import 'package:go_router/go_router.dart';
List<GoRoute> getAllRoutes() => [];
''');
      });

      tearDown(() async {
        if (workspace.existsSync()) {
          await workspace.delete(recursive: true);
        }
      });

      test('pure-Dart pubspec => no app shell (main.dart) generated', () async {
        await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: my_test_app
environment:
  sdk: ^3.11.0
''');
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(['app', 'shell', '--root', workspace.path]);

        expect(
          File(p.join(workspace.path, 'lib', 'main.dart')).existsSync(),
          isFalse,
          reason: 'pure-Dart target must not emit the Flutter app shell',
        );
        expect(
          File(
            p.join(workspace.path, 'lib', 'src', 'app', 'my_app.dart'),
          ).existsSync(),
          isFalse,
        );
      });

      test('Flutter pubspec => generates the Flutter app shell', () async {
        await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: my_test_app
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter:
    git:
      url: https://github.com/arrrrny/zuraffa
      path: zuraffa_flutter
''');
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(['app', 'shell', '--root', workspace.path]);

        final mainFile = File(p.join(workspace.path, 'lib', 'main.dart'));
        expect(mainFile.existsSync(), isTrue);
        final mainSrc = mainFile.readAsStringSync();
        expect(mainSrc, contains('package:flutter/widgets.dart'));

        final myAppFile = File(
          p.join(workspace.path, 'lib', 'src', 'app', 'my_app.dart'),
        );
        expect(myAppFile.existsSync(), isTrue);
        expect(
          myAppFile.readAsStringSync(),
          contains('class MyApp extends StatelessWidget'),
        );
      });
    });
  });
}
