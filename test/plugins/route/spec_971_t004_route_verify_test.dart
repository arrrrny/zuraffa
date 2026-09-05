// Spec 0971 / T004 — `zfa route verify <Entity>` runs the generated
// route-table test headlessly, emits a verdict receipt (declared vs
// resolved routes, deep-link patterns parsed), exits 0/1 and prints
// `--> fix:` lines on mismatch (issue #971 order 4).
//
// The verify command resolves the entity's routes receipt
// (.zfa/receipts/routes-<Entity>.json, written by route create — order 3)
// as the declared table, then proves the CURRENT tree against it:
//   * the route-table test artifact exists and still hashes to the
//     recorded digest,
//   * every declared route in the receipt is still declared on disk (and
//     nothing new appeared),
//   * every GoRoute in the routing modules carries a builder/pageBuilder/
//     redirect (the route-table test's own first assertion, mirrored
//     statically so the verdict is computable without a Flutter binding),
//   * deep-link patterns still parse with the same typed params,
//   * and the generated route-table test itself runs headlessly (the
//     runner is injectable — the tdd realize suite-runner pattern).
//
// Style: bug_912_route_dry_run_route_table_test.dart (failing-first).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/commands/route_verify_command.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

/// The injectable headless route-table-test runner (tdd realize
/// suite-runner pattern): real `dart test`/`flutter test` in production,
/// faked here so both exit paths are deterministic.
typedef FakeRunner =
    Future<({int exitCode, String output})> Function(
      String testPath,
      String workingDirectory,
    );

Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('spec971_t004_');
    projectRoot = tempDir.path;
    await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: route_app
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
  go_router: ^14.0.0
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  /// Generates Product routes + the routes receipt, the way the CLI does.
  Future<void> createProductRoutes() async {
    final runner = CommandRunner<void>('zfa', 'test')
      ..addCommand(
        RouteCommand(
          RoutePlugin(
            outputDir: '$projectRoot/lib/src',
            projectRoot: projectRoot,
          ),
          projectRoot: projectRoot,
        ),
      );
    await captureOutput(() => runner.run(['route', 'create', 'Product']));
    expect(
      File(
        p.join(projectRoot, '.zfa', 'receipts', 'routes-Product.json'),
      ).existsSync(),
      isTrue,
      reason: 'fixture: route create must leave the routes receipt behind',
    );
  }

  /// Runs `zfa route verify <Entity>` with an injected headless test
  /// runner; returns (output, exitCode).
  Future<(String, int)> verifyEntity(
    String entity, {
    FakeRunner? runner,
    List<String> extraArgs = const [],
  }) async {
    exitCode = 0;
    final commandRunner = CommandRunner<void>('zfa', 'test')
      ..addCommand(
        RouteVerifyCommand(projectRoot: projectRoot, testRunner: runner),
      );
    final output = await captureOutput(
      () => commandRunner.run(['verify', entity, ...extraArgs]),
    );
    return (output, exitCode);
  }

  group('spec 0971 T004: zfa route verify <Entity>', () {
    test('healthy table + passing test run exits 0 and writes the verdict '
        'receipt', () async {
      await createProductRoutes();

      final (output, code) = await verifyEntity(
        'Product',
        runner: (testPath, cwd) async => (exitCode: 0, output: 'all passed'),
      );

      expect(code, 0, reason: 'acceptance: healthy table exits 0\n$output');
      final verdictReceipt = File(
        p.join(projectRoot, '.zfa', 'receipts', 'routes-Product-verify.json'),
      );
      expect(
        verdictReceipt.existsSync(),
        isTrue,
        reason: 'order 4: verify emits a verdict receipt',
      );
      final doc =
          jsonDecode(verdictReceipt.readAsStringSync()) as Map<String, dynamic>;
      expect(doc['command'], equals('zfa route verify'));
      expect(doc['target'], equals('Product'));
    });

    test('healthy table with an unavailable test runner still exits 0 '
        '(static verdict decides)', () async {
      await createProductRoutes();

      final (output, code) = await verifyEntity(
        'Product',
        runner: (testPath, cwd) async => throw ProcessException('flutter', [
          'test',
        ], 'flutter not installed'),
      );

      expect(
        code,
        0,
        reason:
            'an environment without a test runner must not fail a '
            'statically-healthy table\n$output',
      );
    });

    test('a route whose builder is missing exits 1 with a fix line', () async {
      await createProductRoutes();

      // Hand-edit: strip the builder from the first GoRoute.
      final module = File(
        p.join(projectRoot, 'lib', 'src', 'routing', 'product_routes.dart'),
      );
      module.writeAsStringSync(
        module.readAsStringSync().replaceFirst('builder:', 'orphaned:'),
      );

      final (output, code) = await verifyEntity(
        'Product',
        runner: (testPath, cwd) async => (exitCode: 0, output: 'all passed'),
      );

      expect(code, 1, reason: 'acceptance: missing builder = exit 1\n$output');
      expect(output, contains('--> fix:'));
      expect(output, contains('builder'));
    });

    test(
      'a missing routes receipt exits 1 and points at route create',
      () async {
        final (output, code) = await verifyEntity(
          'Order',
          runner: (testPath, cwd) async => (exitCode: 0, output: 'all passed'),
        );

        expect(code, 1);
        expect(output, contains('--> fix:'));
        expect(
          output,
          contains('zfa route create Order'),
          reason: 'the fix line must name the reproduction command',
        );
      },
    );

    test('a failing headless test run exits 1 with a fix line', () async {
      await createProductRoutes();

      final (output, code) = await verifyEntity(
        'Product',
        runner: (testPath, cwd) async =>
            (exitCode: 1, output: '00:01 +0 -1: route table (#842) [E]'),
      );

      expect(code, 1, reason: 'a red route-table test must fail verify');
      expect(output, contains('--> fix:'));
      expect(
        output,
        contains('route_table_test.dart'),
        reason: 'the fix line must point at the failing test',
      );
    });

    test('a declared route that vanished from disk exits 1', () async {
      await createProductRoutes();

      final module = File(
        p.join(projectRoot, 'lib', 'src', 'routing', 'product_routes.dart'),
      );
      final lines = module
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.contains("productDetail = '/product/:id'"))
          .join('\n');
      module.writeAsStringSync(lines);

      final (output, code) = await verifyEntity(
        'Product',
        runner: (testPath, cwd) async => (exitCode: 0, output: 'all passed'),
      );

      expect(code, 1);
      expect(
        output,
        contains('/product/:id'),
        reason: 'the finding must name the drifted declared route',
      );
      expect(output, contains('--> fix:'));
    });

    test('a hand-edited route-table test (hash drift) exits 1', () async {
      await createProductRoutes();

      final testFile = File(
        p.join(projectRoot, 'test', 'routing', 'route_table_test.dart'),
      );
      testFile.writeAsStringSync(
        '${testFile.readAsStringSync()}\n// hand edit\n',
      );

      final (output, code) = await verifyEntity(
        'Product',
        runner: (testPath, cwd) async => (exitCode: 0, output: 'all passed'),
      );

      expect(code, 1);
      expect(output, contains('--> fix:'));
      expect(
        output,
        contains('regenerate'),
        reason: 'hash drift on the proof artifact must demand regeneration',
      );
    });

    test('--json emits the verdict envelope (schema 1)', () async {
      await createProductRoutes();

      exitCode = 0;
      final commandRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(
          RouteVerifyCommand(
            projectRoot: projectRoot,
            testRunner: (testPath, cwd) async =>
                (exitCode: 0, output: 'all passed'),
          ),
        );
      final output = await captureOutput(
        () => commandRunner.run(['verify', 'Product', '--json']),
      );

      Map<String, dynamic>? envelope;
      for (final line in output.split('\n').reversed) {
        final trimmed = line.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map<String, dynamic>) envelope = decoded;
          } catch (_) {}
        }
      }
      expect(
        envelope,
        isNotNull,
        reason:
            'verify --json must print one '
            'parseable verdict object:\n$output',
      );
      expect(envelope!['schema'], equals(1));
      expect(envelope['verdict'], equals('pass'));
      expect(envelope['entity'], equals('Product'));
      expect(envelope['routes'], isA<List>());
      expect(envelope['deepLinks'], isA<List>());
      expect(
        envelope['routeTableTestPath'],
        equals('test/routing/route_table_test.dart'),
      );
      expect(envelope['testRun'], isA<Map>());
    });
  });
}
