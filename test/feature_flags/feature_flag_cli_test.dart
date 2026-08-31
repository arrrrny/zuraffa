import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// A1, A2, A3, U3 — `zfa feature list/enable/disable` over a real temp
/// project, driven through the real CLI subprocess (precompiled AOT via
/// the shared helper). Subprocesses with an explicit workingDirectory are
/// the repo's race-free pattern: `Directory.current` is process-global and
/// would be contended by concurrently-running in-process CLI tests.
void main() {
  late Directory workspace;

  String configPath() => p.join(workspace.path, '.zfa.json');

  Map<String, dynamic> readConfig() =>
      jsonDecode(File(configPath()).readAsStringSync()) as Map<String, dynamic>;

  void writeConfig(Map<String, dynamic> json) {
    File(
      configPath(),
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  }

  setUpAll(initZfaSourceBin);

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_feature_flags_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: feature_flag_app
environment:
  sdk: ^3.11.0
''');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  group('zfa feature list', () {
    test(
      'A1: no features section lists no features (empty but valid)',
      () async {
        final result = await runZfaSource([
          'feature',
          'list',
        ], workingDirectory: workspace.path);
        expect(
          result.exitCode,
          0,
          reason: 'empty config is valid, not an error',
        );
        expect(result.stdout, contains('No features declared'));
        expect(result.stdout, isNot(contains('pro-analytics')));
      },
    );

    test('A2: lists all declared features with their enabled status', () async {
      writeConfig({
        'features': [
          {'name': 'pro-analytics', 'enabled': true},
          {'name': 'beta-scheduler', 'enabled': false},
          {'name': 'notes', 'enabled': true},
        ],
      });
      final result = await runZfaSource([
        'feature',
        'list',
      ], workingDirectory: workspace.path);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('pro-analytics'));
      expect(result.stdout, contains('beta-scheduler'));
      expect(result.stdout, contains('notes'));
      final stdoutText = result.stdout as String;
      final betaLine = stdoutText
          .split('\n')
          .firstWhere((l) => l.contains('beta-scheduler'));
      expect(betaLine, contains('disabled'));
    });

    test('supports --format=json machine-readable output', () async {
      writeConfig({
        'features': [
          {'name': 'pro-analytics', 'enabled': true},
        ],
      });
      final result = await runZfaSource([
        'feature',
        'list',
        '--format=json',
      ], workingDirectory: workspace.path);
      expect(result.exitCode, 0);
      final json = jsonDecode(result.stdout) as List<dynamic>;
      expect(json, hasLength(1));
      expect(json.first['name'], 'pro-analytics');
      expect(json.first['enabled'], isTrue);
    });
  });

  group('zfa feature enable/disable', () {
    test('A3: disable updates .zfa.json and the list reflects it', () async {
      writeConfig({
        'features': [
          {'name': 'beta-scheduler', 'enabled': true},
        ],
      });
      final result = await runZfaSource([
        'feature',
        'disable',
        'beta-scheduler',
      ], workingDirectory: workspace.path);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('beta-scheduler'));

      final features = readConfig()['features'] as List<dynamic>;
      expect(
        (features.single as Map)['enabled'],
        isFalse,
        reason: 'disable must persist enabled:false to .zfa.json',
      );

      final listResult = await runZfaSource([
        'feature',
        'list',
      ], workingDirectory: workspace.path);
      final listText = listResult.stdout as String;
      expect(
        listText.split('\n').firstWhere((l) => l.contains('beta-scheduler')),
        contains('disabled'),
      );
    });

    test('enable re-enables a disabled feature', () async {
      writeConfig({
        'features': [
          {'name': 'beta-scheduler', 'enabled': false},
        ],
      });
      final result = await runZfaSource([
        'feature',
        'enable',
        'beta-scheduler',
      ], workingDirectory: workspace.path);
      expect(result.exitCode, 0);
      final features = readConfig()['features'] as List<dynamic>;
      expect((features.single as Map)['enabled'], isTrue);
    });

    test('disable of an undeclared feature fails naming it', () async {
      final result = await runZfaSource([
        'feature',
        'disable',
        'ghost',
      ], workingDirectory: workspace.path);
      expect(result.exitCode, isNot(0), reason: 'undeclared feature must fail');
      expect('${result.stdout}${result.stderr}', contains('ghost'));
    });
  });

  group('scaffold dispatch preserved (U3)', () {
    test('non-flag tokens keep the scaffold/generator behavior', () async {
      final result = await runZfaSource([
        'feature',
      ], workingDirectory: workspace.path);
      expect(result.exitCode, 0);
      final output = '${result.stdout}${result.stderr}'.toLowerCase();
      // scaffold usage path, NOT a feature-flag listing
      expect(output, anyOf(contains('usage'), contains('zfa')));
      expect(output, isNot(contains('no features declared')));
    });
  });
}
