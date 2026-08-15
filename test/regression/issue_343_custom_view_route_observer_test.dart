// Regression test for issue #343:
// https://github.com/arrrrny/zuraffa/issues/343
//
// `zfa view custom` generated views whose constructor forwarded
// `super.routeObserver` — copied unconditionally from the entity-backed
// CleanView template. But custom views extend plain StatefulWidget (or
// StatelessWidget with --stateless), whose constructors have NO
// `routeObserver` parameter. Every generated custom view then failed with
//   super_formal_parameter_without_associated_named
// (4 custom views in apps/zikzak_demo: Splash/Login/Profile/GroceryHome).
//
// Fix: the custom view templates (stateful + stateless variants in
// view_class_builder.dart) emit `const <Name>View({super.key})` only.
// The entity-backed CleanView templates keep `super.routeObserver` —
// CleanView's constructor legitimately accepts it.
//
// This test:
//   1. generates a custom view through the real `zfa view custom` CLI,
//   2. generates the stateless variant through the custom capability,
//   3. compiles both with `dart analyze` against a minimal stub of
//      `package:flutter/material.dart` (the zuraffa root package is pure
//      Dart, so CI's `dart test` job has no Flutter SDK — the stub defines
//      StatelessWidget/StatefulWidget with ONLY a `key` named param, so a
//      regressed `super.routeObserver` would surface as exactly
//      super_formal_parameter_without_associated_named),
//   4. guards the entity-backed CleanView template: it must KEEP
//      super.routeObserver.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/view/capabilities/custom_view_capability.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

/// Resolve package root at discovery time, before any test changes CWD.
final _zfaRoot = Directory.current.path;

/// Minimal stand-in for `package:flutter/material.dart`. Only the symbols
/// the custom view template references are defined. Crucially,
/// [StatelessWidget] and [StatefulWidget] declare ONLY a `key` constructor
/// parameter — no `routeObserver` — mirroring the real Flutter classes, so
/// a super-forward of `routeObserver` is a compile error here.
const _stubMaterialSource = '''
class Key {
  const Key([String? value]);
}

class BuildContext {
  const BuildContext();
}

abstract class Widget {
  const Widget({Key? key});
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});

  Widget build(BuildContext context);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});

  State<dynamic> createState();
}

abstract class State<W extends StatefulWidget> {
  Widget build(BuildContext context);
}

class Scaffold extends Widget {
  const Scaffold({super.key, this.appBar, this.body});
  final Widget? appBar;
  final Widget? body;
}

class AppBar extends Widget {
  const AppBar({super.key, this.title});
  final Widget? title;
}

class Text extends Widget {
  const Text(this.data, {super.key});
  final String data;
}

class Center extends Widget {
  const Center({super.key, this.child});
  final Widget? child;
}
''';

void main() {
  late Directory workspace;
  late String libSrc;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zuraffa_issue343_');
    libSrc = p.join(workspace.path, 'lib', 'src');

    // A pure-Dart package whose only dependency is the stub flutter
    // package, so `dart analyze` resolves `package:flutter/material.dart`
    // without a Flutter SDK install (CI's dart_core job has none).
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_343_test_app
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    path: stub_flutter
''');
    final stubLib = Directory(
      p.join(workspace.path, 'stub_flutter', 'lib'),
    );
    await stubLib.create(recursive: true);
    await File(
      p.join(workspace.path, 'stub_flutter', 'pubspec.yaml'),
    ).writeAsString('''
name: flutter
version: 0.0.0
environment:
  sdk: '>=3.0.0 <4.0.0'
''');
    await File(
      p.join(stubLib.path, 'material.dart'),
    ).writeAsString(_stubMaterialSource);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  group('issue #343 — custom view constructor must not forward routeObserver', () {
    test(
      '`zfa view custom` (stateful) generates a compiling view',
      timeout: const Timeout(Duration(minutes: 3)),
      () async {
        final result = await Process.run(
          'dart',
          [p.join(_zfaRoot, 'bin', 'zfa.dart'), 'view', 'custom', 'Splash'],
          workingDirectory: workspace.path,
        );
        expect(
          result.exitCode,
          equals(0),
          reason:
              'zfa view custom must succeed:\n'
              '${result.stdout}\n${result.stderr}',
        );

        final viewFile = File(
          p.join(libSrc, 'presentation', 'pages', 'general', 'splash_view.dart'),
        );
        expect(viewFile.existsSync(), isTrue);
        final content = viewFile.readAsStringSync();

        // The exact #343 symptom: super.routeObserver forwarded to plain
        // StatefulWidget → super_formal_parameter_without_associated_named.
        expect(
          content,
          isNot(contains('super.routeObserver')),
          reason:
              'custom views extend plain StatefulWidget, whose constructor '
              'has no routeObserver parameter — forwarding it produced '
              'super_formal_parameter_without_associated_named (#343).',
        );
        // The expected constructor shape from the issue.
        expect(content, contains('const SplashView({super.key})'));
        expect(content, contains('extends StatefulWidget'));

        // Compile check: dart analyze against the stub material library.
        await _assertAnalyzesClean(workspace);
      },
    );

    test(
      'custom capability with stateless:true generates a compiling '
      'StatelessWidget view',
      timeout: const Timeout(Duration(minutes: 3)),
      () async {
        final plugin = ViewPlugin(
          outputDir: libSrc,
          options: const GeneratorOptions(force: true),
        );
        final capability = CustomViewCapability(plugin);
        final result = await capability.execute({
          'name': 'Login',
          'domain': 'general',
          'stateless': true,
        });
        expect(result.success, isTrue);

        final viewFile = File(
          p.join(libSrc, 'presentation', 'pages', 'general', 'login_view.dart'),
        );
        expect(viewFile.existsSync(), isTrue);
        final content = viewFile.readAsStringSync();

        expect(
          content,
          isNot(contains('super.routeObserver')),
          reason:
              'stateless custom views extend plain StatelessWidget, whose '
              'constructor has no routeObserver parameter (#343).',
        );
        expect(content, contains('const LoginView({super.key})'));
        expect(content, contains('extends StatelessWidget'));

        await _assertAnalyzesClean(workspace);
      },
    );

    test(
      'entity-backed CleanView templates KEEP super.routeObserver',
      () async {
        final plugin = ViewPlugin(
          outputDir: libSrc,
          options: const GeneratorOptions(force: true),
        );

        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'update'],
            generateView: true,
            outputDir: libSrc,
          ),
        );
        expect(files, isNotEmpty);
        final content = files.first.content ?? '';
        expect(content, contains('extends CleanView'));
        expect(
          content,
          contains('super.routeObserver'),
          reason:
              'entity-backed views extend CleanView, whose constructor '
              'legitimately accepts routeObserver — the #343 fix must NOT '
              'touch the CleanView template.',
        );
      },
    );
  });
}

/// Runs `dart pub get` + `dart analyze` in [workspace] and asserts the
/// compile is clean — in particular that no
/// super_formal_parameter_without_associated_named error appears.
Future<void> _assertAnalyzesClean(Directory workspace) async {
  final pubGet = await Process.run(
    'dart',
    ['pub', 'get'],
    workingDirectory: workspace.path,
  );
  expect(
    pubGet.exitCode,
    equals(0),
    reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
  );

  final analyze = await Process.run(
    'dart',
    ['analyze'],
    workingDirectory: workspace.path,
  );
  final output = analyze.stdout.toString() + analyze.stderr.toString();

  expect(
    output,
    isNot(contains('super_formal_parameter_without_associated_named')),
    reason:
        'the #343 symptom reappeared: a generated view forwards '
        'super.routeObserver to a base class that does not declare it.',
  );
  expect(
    analyze.exitCode,
    equals(0),
    reason: 'dart analyze reported issues:\n$output',
  );
}
