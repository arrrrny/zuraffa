// Spec 0971 / T002 — `zfa route create --json` emits a machine verdict
// envelope: `{routes[], deepLinks, schemeRegistrations, routeTableTestPath,
// schema:1}` (issue #971 order 2).
//
// The route plugin is the strongest generator after tdd but its agent
// contract is 3/5: no --json verdict. This pins the envelope schema an
// agent (or the #963 route-coverage ledger) can consume without parsing
// emoji prose.
//
// Style: bug_912_route_dry_run_route_table_test.dart (failing-first,
// real plugin generation into a temp Flutter-flavored project).
//
// Driver note: the command is driven through CommandRunner with an
// EXPLICIT projectRoot and absolute outputDir (the bug_912 convention),
// not `CliRunner -C <dir>` — the -C machinery swaps the process-global
// CWD, which races other concurrent test isolates (see
// cli_runner_cwd_hardening_test.dart; dart_test.yaml caps concurrency
// at 2 precisely because suites share the process). The -C wiring
// itself is pinned by the cwd-hardening suite.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

Future<String> capturePrints(Future<void> Function() body) async {
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
  late CommandRunner<void> runner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('spec971_t002_');
    projectRoot = tempDir.path;
    // A Flutter-flavored pubspec so route generation is not skipped by
    // the pure-Dart guard (Constitution VII).
    await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: route_app
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
  go_router: ^14.0.0
''');
    runner = CommandRunner<void>('zfa', 'test')
      ..addCommand(
        RouteCommand(
          RoutePlugin(
            outputDir: '$projectRoot/lib/src',
            projectRoot: projectRoot,
          ),
          projectRoot: projectRoot,
        ),
      );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  /// Runs `zfa route create Product --json`; returns captured output.
  Future<String> createJson() =>
      capturePrints(() => runner.run(['route', 'create', 'Product', '--json']));

  /// Extracts the JSON verdict envelope from captured command output: the
  /// single line that decodes to a JSON object.
  Map<String, dynamic> envelopeFrom(String output) {
    for (final line in output.split('\n').reversed) {
      final trimmed = line.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {
          // Not the envelope line — keep scanning.
        }
      }
    }
    fail('no JSON envelope found in CLI output:\n$output');
  }

  group('spec 0971 T002: route create --json envelope schema', () {
    test('emits {routes[], deepLinks, schemeRegistrations, '
        'routeTableTestPath, schema:1}', () async {
      final out = await createJson();
      final envelope = envelopeFrom(out);

      // The five contract keys of issue #971 order 2.
      expect(
        envelope['schema'],
        equals(1),
        reason: 'the envelope must pin schema version 1',
      );
      expect(
        envelope['routes'],
        isA<List>(),
        reason: 'routes[] must be present',
      );
      expect(
        envelope['deepLinks'],
        isA<List>(),
        reason: 'deepLinks must be present',
      );
      expect(
        envelope['schemeRegistrations'],
        isA<List>(),
        reason: 'schemeRegistrations must be present',
      );
      expect(
        envelope['routeTableTestPath'],
        isA<String>(),
        reason: 'routeTableTestPath must be present',
      );
      expect(exitCode, 0, reason: 'a successful create exits 0');
    });

    test('routes[] carries the declared table (get+update defaults)', () async {
      final out = await createJson();
      final envelope = envelopeFrom(out);
      final routes = (envelope['routes'] as List).cast<Map<String, dynamic>>();

      expect(routes, isNotEmpty);
      final paths = routes.map((r) => r['path']).toList();
      expect(paths, contains('/product'));
      expect(paths, contains('/product/:id'));
      expect(paths, contains('/product/:id/edit'));
      // Every entry carries the declaring route module owner.
      for (final route in routes) {
        expect(route['owner'], isA<String>());
      }
    });

    test('deepLinks carries the typed-param patterns', () async {
      final out = await createJson();
      final envelope = envelopeFrom(out);
      final deepLinks = (envelope['deepLinks'] as List)
          .cast<Map<String, dynamic>>();

      expect(deepLinks, isNotEmpty);
      final patterns = deepLinks.map((d) => d['pattern']).toList();
      expect(patterns, contains('/product/:id'));
      final detail = deepLinks.firstWhere(
        (d) => d['pattern'] == '/product/:id',
      );
      expect(detail['params'], equals(['id']));
    });

    test(
      'routeTableTestPath points at the generated route-table test',
      () async {
        final out = await createJson();
        final envelope = envelopeFrom(out);
        final testPath = envelope['routeTableTestPath'] as String;

        expect(
          p.posix.normalize(testPath),
          equals('test/routing/route_table_test.dart'),
        );
        // The table the envelope claims is the table on disk.
        expect(
          File(p.join(projectRoot, testPath)).existsSync(),
          isTrue,
          reason: 'routeTableTestPath must reference a real artifact',
        );
      },
    );

    test('schemeRegistrations stays empty without --scheme', () async {
      final out = await createJson();
      final envelope = envelopeFrom(out);
      expect(envelope['schemeRegistrations'], isEmpty);
    });

    test('the run still generated the route modules on disk', () async {
      await createJson();
      expect(
        File(
          p.join(projectRoot, 'lib/src/routing/product_routes.dart'),
        ).existsSync(),
        isTrue,
      );
    });
  });
}
