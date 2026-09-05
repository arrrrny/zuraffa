// Spec 0971 / T005 — `--> fix:` lines on every error path; the
// pure-Dart skip becomes a structured verdict in the JSON envelope
// (issue #971 order 5).
//
// The agent contract (order 5): an error message that says WHAT failed
// and `--> fix:` that says the next command to run. The pure-Dart skip
// used to be a printed warning whose failure semantics lived in a
// distant shared guard (#769) — now the skip reason rides IN the JSON
// envelope (verdict=skip + skip.reason), machine-consumable.
//
// Style: bug_912_route_dry_run_route_table_test.dart (failing-first).
//
// Driver note: commands driven via CommandRunner + explicit projectRoot
// (no process-global CWD swap — see the T002 file's note); the --help
// surfaces use CliRunner WITHOUT -C, which never touches CWD.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/commands/route_verify_command.dart';
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

Map<String, dynamic>? envelopeFrom(String output) {
  for (final line in output.split('\n').reversed) {
    final trimmed = line.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
  }
  return null;
}

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('spec971_t005_');
    projectRoot = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  /// Runs `zfa route <args...>` in the temp project, capturing output.
  Future<String> route(List<String> args) async {
    exitCode = 0;
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
    return capturePrints(() => runner.run(['route', ...args]));
  }

  /// `zfa --help`-level surface WITHOUT -C (never swaps the process CWD).
  Future<String> cliHelp(List<String> args) async {
    exitCode = 0;
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(args);
  }

  group('spec 0971 T005: fix lines + structured skip verdicts', () {
    test('route create with no entity: error + fix line + exit 64', () async {
      // A Flutter-flavored project so the failure is the missing entity,
      // not the flavor guard.
      await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: route_app
dependencies:
  flutter:
    sdk: flutter
''');

      final out = await route(['create']);

      expect(out, contains('--> fix:'));
      expect(out, contains('zfa route create'));
      expect(
        exitCode,
        64,
        reason: 'a usage error must stay a usage error (exit 64 family)',
      );
    });

    test('pure-Dart skip: --json emits a structured skip verdict '
        '(reason in the envelope)', () async {
      // A pure-Dart pubspec triggers the flavor guard.
      await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: pure_dart_app
environment:
  sdk: ^3.0.0
''');

      final out = await route(['create', 'Product', '--json']);
      final envelope = envelopeFrom(out);

      expect(
        envelope,
        isNotNull,
        reason: 'the skip must be a JSON envelope, not a bare warning:\n$out',
      );
      expect(envelope!['schema'], equals(1));
      expect(
        envelope['verdict'],
        equals('skip'),
        reason: 'order 5: the skip is a structured verdict',
      );
      expect(envelope['skip'], isA<Map>());
      expect(
        (envelope['skip'] as Map)['reason'],
        isA<String>(),
        reason: 'the skip reason rides in the envelope',
      );
      expect((envelope['skip'] as Map)['reason'], contains('pure-Dart'));
      // The five contract keys stay present even on skip.
      expect(envelope['routes'], isA<List>());
      expect(envelope['deepLinks'], isA<List>());
      expect(envelope['schemeRegistrations'], isA<List>());
      expect(
        exitCode,
        1,
        reason: '#769 discipline: a declined generation is not a win',
      );
    });

    test('pure-Dart skip: text mode prints the reason + a fix line', () async {
      await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: pure_dart_app
environment:
  sdk: ^3.0.0
''');

      final out = await route(['create', 'Product', '--plain']);

      expect(out, contains('pure-Dart'));
      expect(out, contains('--> fix:'));
      expect(exitCode, 1);
    });

    test('invalid --scheme: error + fix line, nothing written', () async {
      await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: route_app
dependencies:
  flutter:
    sdk: flutter
''');

      final out = await route([
        'create',
        'Product',
        '--scheme',
        'NOT A SCHEME',
        '--json',
      ]);

      final envelope = envelopeFrom(out);
      expect(envelope, isNotNull);
      expect(envelope!['verdict'], equals('fail'));
      expect(
        (envelope['error'] as Map)['fix'],
        isA<String>(),
        reason: 'the failure envelope must carry the fix',
      );
      expect(exitCode, 1);
      // Validation fired before any write.
      expect(
        Directory(p.join(projectRoot, 'lib', 'src', 'routing')).existsSync(),
        isFalse,
        reason: 'scheme validation must precede any file write',
      );
    });

    test('corrupt routes receipt: verify fails with a fix line', () async {
      await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: route_app
dependencies:
  flutter:
    sdk: flutter
''');
      final receipts = Directory(p.join(projectRoot, '.zfa', 'receipts'))
        ..createSync(recursive: true);
      await File(
        p.join(receipts.path, 'routes-Product.json'),
      ).writeAsString('{not json');

      exitCode = 0;
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(
          RouteVerifyCommand(
            projectRoot: projectRoot,
            testRunner: (testPath, cwd) async => (exitCode: 0, output: 'ok'),
          ),
        );
      final out = await capturePrints(() => runner.run(['verify', 'Product']));

      expect(out, contains('not parseable'));
      expect(out, contains('--> fix:'));
      expect(exitCode, 1);
    });

    test('route create --help documents the --json verdict flag', () async {
      final out = await cliHelp(['route', 'create', '--help']);
      expect(out, contains('--json'));
      // The generic input-args JSON option is gone from this subcommand.
      expect(out, isNot(contains('Pass arguments as JSON string')));
    });

    test('route verify --help documents the entity positional', () async {
      final out = await cliHelp(['route', 'verify', '--help']);
      expect(
        out,
        contains('<Entity>'),
        reason: 'the verify grammar must advertise the entity argument',
      );
    });

    test(
      'dry-run discipline: --dry-run writes no receipt and no files',
      () async {
        await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: route_app
dependencies:
  flutter:
    sdk: flutter
''');

        final out = await route(['create', 'Product', '--dry-run']);

        expect(
          File(
            p.join(projectRoot, '.zfa', 'receipts', 'routes-Product.json'),
          ).existsSync(),
          isFalse,
          reason:
              'a dry run must not persist a proof artifact for bytes that '
              'never landed on disk',
        );
        expect(
          Directory(p.join(projectRoot, 'lib', 'src', 'routing')).existsSync(),
          isFalse,
          reason: 'a dry run writes nothing',
        );
        expect(out, isNotEmpty, reason: 'sanity: the dry run completed');
      },
    );
  });
}
