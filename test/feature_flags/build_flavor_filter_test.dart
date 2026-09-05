@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// A7, A8 — `zfa build --flavor <name>` end-to-end through the real CLI
/// subprocess (precompiled AOT via the shared helper; `--dda-routes-only`
/// keeps each run inside the route stage + registry emission, no
/// build_runner). Distinct flavors must produce distinct feature-sets
/// (SC-004); a disabled feature must leave no trace; an unknown flavor
/// fails naming it.
void main() {
  late Directory workspace;

  setUpAll(initZfaSourceBin);

  String routerPath() =>
      p.join(workspace.path, 'lib', 'src', 'routing', 'zfa_router.g.dart');

  String registryPath() =>
      p.join(workspace.path, 'lib', 'src', 'core', 'feature_flags.g.dart');

  void writeConfig(String json) {
    File(p.join(workspace.path, '.zfa.json')).writeAsStringSync(json);
  }

  void seedProject() {
    File(p.join(workspace.path, 'pubspec.yaml')).writeAsStringSync('''
name: flag_build_app
environment:
  sdk: ^3.11.0
dependencies:
  go_router: ^14.0.0
''');
    final views = Directory(p.join(workspace.path, 'lib', 'views'));
    views.createSync(recursive: true);
    File(p.join(views.path, 'pro_analytics_view.dart')).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

@ZfaRoute(path: '/pro-analytics')
class ProAnalyticsView {}
''');
    File(p.join(views.path, 'home_view.dart')).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

@ZfaRoute(path: '/home')
class HomeView {}
''');
  }

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_flag_build_');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  test(
    'A7: --flavor free emits the free set; --flavor pro emits the full set',
    () async {
      seedProject();
      writeConfig('''
{
  "features": [
    { "name": "pro-analytics", "enabled": true },
    { "name": "notes", "enabled": true }
  ],
  "flavors": {
    "free": { "pro-analytics": false },
    "pro": {}
  }
}
''');

      final free = await runZfaSource([
        'build',
        '--flavor',
        'free',
        '--dda-routes-only',
        '--no-analyze',
      ], workingDirectory: workspace.path);
      expect(
        free.exitCode,
        0,
        reason: 'free build failed:\n${free.stdout}\n${free.stderr}',
      );

      final freeRouter = File(routerPath()).readAsStringSync();
      final freeRegistry = File(registryPath()).readAsStringSync();
      expect(freeRouter, contains("path: '/home'"));
      expect(freeRouter, isNot(contains('/pro-analytics')));
      expect(freeRegistry, contains("'notes'"));
      expect(freeRegistry, isNot(contains('pro-analytics')));

      final pro = await runZfaSource([
        'build',
        '--flavor',
        'pro',
        '--dda-routes-only',
        '--no-analyze',
      ], workingDirectory: workspace.path);
      expect(
        pro.exitCode,
        0,
        reason: 'pro build failed:\n${pro.stdout}\n${pro.stderr}',
      );

      final proRouter = File(routerPath()).readAsStringSync();
      final proRegistry = File(registryPath()).readAsStringSync();
      expect(proRouter, contains('/pro-analytics'));
      expect(proRegistry, contains("'pro-analytics'"));
      expect(proRegistry, contains("'notes'"));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'A8: all-enabled build output matches a no-features-section build',
    () async {
      seedProject();

      // Build 1: no features section at all — no registry, plain router.
      final noFlags = await runZfaSource([
        'build',
        '--dda-routes-only',
        '--no-analyze',
      ], workingDirectory: workspace.path);
      expect(noFlags.exitCode, 0);
      final plainRouter = File(routerPath()).readAsStringSync();
      expect(
        File(registryPath()).existsSync(),
        isFalse,
        reason: 'no features section -> no registry emitted',
      );

      // Build 2: all features enabled — router must be identical.
      writeConfig('''
{
  "features": [
    { "name": "pro-analytics", "enabled": true },
    { "name": "notes", "enabled": true }
  ]
}
''');
      final allEnabled = await runZfaSource([
        'build',
        '--dda-routes-only',
        '--no-analyze',
      ], workingDirectory: workspace.path);
      expect(allEnabled.exitCode, 0);
      final allRouter = File(routerPath()).readAsStringSync();
      expect(allRouter, equals(plainRouter));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('unknown flavor fails naming it', () async {
    seedProject();
    writeConfig('''
{
  "features": [
    { "name": "notes", "enabled": true }
  ]
}
''');
    final result = await runZfaSource([
      'build',
      '--flavor',
      'nightly',
      '--dda-routes-only',
      '--no-analyze',
    ], workingDirectory: workspace.path);
    expect(result.exitCode, isNot(0));
    final combined = '${result.stdout}\n${result.stderr}';
    expect(combined, contains('nightly'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'dry-run route-only build does not write the feature registry',
    () async {
      seedProject();
      writeConfig('''
{
  "features": [
    { "name": "notes", "enabled": true }
  ]
}
''');

      final result = await runZfaSource([
        'build',
        '--dda-routes-only',
        '--dry-run',
        '--no-analyze',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0);
      expect(File(registryPath()).existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('dry-run full build does not write the feature registry', () async {
    seedProject();
    writeConfig('''
{
  "features": [
    { "name": "notes", "enabled": true }
  ]
}
''');

    final result = await runZfaSource([
      'build',
      '--dry-run',
      '--no-analyze',
    ], workingDirectory: workspace.path);

    expect(result.exitCode, 0);
    expect(File(registryPath()).existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
