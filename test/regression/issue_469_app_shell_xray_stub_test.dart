@Tags(['regression', 'slow'])

// Regression test for issue #469: `zfa app shell --xray` must emit the
// web-safe bridge launcher stub so the generated lib/main.dart compiles.
//
// Before the fix, main.dart unconditionally imported
// `xray_bridge_launcher_stub.dart` (the default branch of its conditional
// import) but no zfa command ever wrote that file — the analyzer failed
// with "Target of URI doesn't exist" on every platform.
//
// This test runs the real command against a minimal project fixture
// (pubspec + DI barrel + routing barrel) and asserts:
// - lib/xray_bridge_launcher_stub.dart is written, defining a no-op
//   XRayBridgeServer with the real server's start() shape.
// - lib/main.dart keeps the conditional import and now resolves on both
//   branches (stub file sits beside it under lib/).
// - Re-running the command preserves an existing stub (idempotent leaf).
// - Running WITHOUT --xray writes no stub.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_469_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedProject() async {
    await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: stub_app
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter:
    git:
      url: https://github.com/arrrrny/zuraffa
      path: zuraffa_flutter
''');
    final diDir = Directory(p.join(tempDir.path, 'lib', 'src', 'di'));
    await diDir.create(recursive: true);
    await File(p.join(diDir.path, 'index.dart')).writeAsString('''
import 'package:get_it/get_it.dart';

void setupDependencies(GetIt getIt) {}
''');
    final routingDir = Directory(p.join(tempDir.path, 'lib', 'src', 'routing'));
    await routingDir.create(recursive: true);
    await File(p.join(routingDir.path, 'index.dart')).writeAsString('''
import 'package:go_router/go_router.dart';

List<RouteBase> getAllRoutes() => [];
''');
  }

  test('app shell --xray writes the web-safe bridge launcher stub', () async {
    await seedProject();
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing([
      'app',
      'shell',
      '--xray',
      '--root',
      tempDir.path,
    ]);

    final stubPath = p.join(
      tempDir.path,
      'lib',
      'xray_bridge_launcher_stub.dart',
    );
    final stubFile = File(stubPath);
    expect(stubFile.existsSync(), isTrue, reason: 'the stub must be written');

    final stub = stubFile.readAsStringSync();
    expect(stub, contains('class XRayBridgeServer'));
    expect(
      stub,
      contains('Future<int> start()'),
      reason:
          'the stub must mirror the real server\'s start() shape so '
          'the conditional import type-checks on both branches',
    );

    // main.dart's conditional import now resolves on both branches: the
    // stub sits beside it under lib/, and the io branch points at the real
    // zuraffa_flutter server.
    final mainContent = await File(
      p.join(tempDir.path, 'lib', 'main.dart'),
    ).readAsString();
    expect(mainContent, contains('xray_bridge_launcher_stub.dart'));
    expect(mainContent, contains('if (dart.library.io)'));

    // Follow-up regression: `flutter analyze` on a freshly generated
    // --xray app must exit clean. my_app.dart never references a
    // go_router symbol (MaterialApp.router comes from material.dart,
    // appRouter via the routing glue), so a direct go_router import is
    // an unused_import — previously the ONLY analyzer complaint left on
    // generated output, fatal for `flutter analyze` (warnings exit 1).
    final myAppContent = await File(
      p.join(tempDir.path, 'lib', 'src', 'app', 'my_app.dart'),
    ).readAsString();
    expect(
      myAppContent,
      isNot(contains("import 'package:go_router/go_router.dart';")),
      reason:
          'my_app.dart must not import go_router directly — it is '
          'unused there and makes generated apps fail flutter analyze',
    );
    expect(
      myAppContent,
      contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart';"),
      reason:
          'xray mode wraps MaterialApp.router in XRayScope, which '
          'comes from the zuraffa_flutter barrel',
    );
  });

  test('re-running app shell --xray preserves an existing stub', () async {
    await seedProject();
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing([
      'app',
      'shell',
      '--xray',
      '--root',
      tempDir.path,
    ]);

    final stubPath = p.join(
      tempDir.path,
      'lib',
      'xray_bridge_launcher_stub.dart',
    );
    final customized =
        '// my customized stub\n'
        'class XRayBridgeServer {\n'
        '  Future<int> start() async => 0;\n'
        '}\n';
    await File(stubPath).writeAsString(customized);

    await runner.runCapturing([
      'app',
      'shell',
      '--xray',
      '--force',
      '--root',
      tempDir.path,
    ]);

    expect(
      File(stubPath).readAsStringSync(),
      customized,
      reason:
          'the stub is an idempotent leaf file — --force regenerates '
          'main.dart but must not clobber the stub',
    );
  });

  test('app shell without --xray writes no stub', () async {
    await seedProject();
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing(['app', 'shell', '--root', tempDir.path]);

    expect(
      File(
        p.join(tempDir.path, 'lib', 'xray_bridge_launcher_stub.dart'),
      ).existsSync(),
      isFalse,
    );
  });
}
