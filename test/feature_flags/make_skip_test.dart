import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// A5, A6, U6 — a disabled feature's slice is skipped before planning:
/// zero files written, skip reason printed; an enabled feature proceeds.
/// Driven through the real CLI subprocess (precompiled AOT via the shared
/// helper) with an explicit workingDirectory — the repo's race-free test
/// pattern (`Directory.current` is process-global and would be contended
/// by concurrently-running in-process CLI tests).
void main() {
  late Directory workspace;

  setUpAll(initZfaSourceBin);

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_flag_make_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: flag_make_app
environment:
  sdk: ^3.11.0
''');
    final entityDir = Directory(
      p.join(workspace.path, 'lib', 'src', 'domain', 'entities'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'pro_analytics.dart')).writeAsString('''
class ProAnalytics {
  final String id;

  const ProAnalytics({required this.id});
}
''');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  int fileCount() {
    final lib = Directory(p.join(workspace.path, 'lib'));
    if (!lib.existsSync()) return 0;
    return lib.listSync(recursive: true).whereType<File>().length;
  }

  test('A6/U6: disabled feature slice generates zero files', () async {
    File(p.join(workspace.path, '.zfa.json')).writeAsStringSync('''
{
  "features": [
    { "name": "pro-analytics", "enabled": false }
  ]
}
''');
    final before = fileCount();
    final result = await runZfaSource([
      'make',
      'ProAnalytics',
      'di',
      '--no-entity',
    ], workingDirectory: workspace.path);
    final after = fileCount();

    expect(after, before, reason: 'disabled feature must write zero files');
    expect(
      '${result.stdout}${result.stderr}'.toLowerCase(),
      contains('skipped'),
      reason: 'the skip reason must be printed',
    );
  });

  test('A5/U6: enabled feature slice proceeds past the flag gate', () async {
    File(p.join(workspace.path, '.zfa.json')).writeAsStringSync('''
{
  "features": [
    { "name": "pro-analytics", "enabled": true }
  ]
}
''');
    // --plan: resolve the plan and print it, without writing files. The
    // point is the flag gate lets an enabled slice through to planning.
    final result = await runZfaSource([
      'make',
      'ProAnalytics',
      'di',
      '--plan',
    ], workingDirectory: workspace.path);
    expect(
      '${result.stdout}${result.stderr}'.toLowerCase(),
      isNot(contains('skipped')),
      reason: 'enabled feature must not be flag-skipped',
    );
  });

  test(
    'disabled gate blocks the entity-file guard too (skip before planning)',
    () async {
      // No entity file exists for GhostFeature at all — if the flag gate
      // works, the run never reaches the entity-exists guard.
      File(p.join(workspace.path, '.zfa.json')).writeAsStringSync('''
{
  "features": [
    { "name": "ghost-feature", "enabled": false }
  ]
}
''');
      final result = await runZfaSource([
        'make',
        'GhostFeature',
        'di',
      ], workingDirectory: workspace.path);
      expect(
        '${result.stdout}${result.stderr}'.toLowerCase(),
        contains('skipped'),
      );
    },
  );
}
