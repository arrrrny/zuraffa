// Spec 1002 — `zfa make engine <Entity>` grammar + plan resolution.
//
// The engine mode token must:
//   1. parse `engine` as the preset keyword, not the entity name;
//   2. resolve the engine plugin chain (usecase..di, no Flutter plugins);
//   3. leave `zfa make <Name> --preset=<other>` untouched (hard constraint);
//   4. keep a PascalCase entity literally named `Engine` on the classic
//      grammar (case guard on the mode token).
//
// Driven through a real subprocess ([runZfaSource]) so the usage-error
// exit codes are real and the process-global `Directory.current` never
// races between parallel test files (issue #506 pattern).

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_make_engine_plan_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: make_engine_plan_test
environment:
  sdk: ^3.11.0
''');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  Future<void> writeEntity(String name) async {
    final snake = name.toLowerCase();
    final dir = Directory(
      p.join(workspace.path, 'lib/src/domain/entities', snake),
    );
    await dir.create(recursive: true);
    await File(p.join(dir.path, '$snake.dart')).writeAsString('''
class $name {
  final String id;
  const $name({required this.id});
}
''');
  }

  Future<Map<String, dynamic>> planFor(List<String> args) async {
    final result = await runZfaSource([
      ...args,
      '--plan',
      '--format=json',
    ], workingDirectory: workspace.path);
    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
    final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    expect(decoded['success'], isTrue);
    return decoded['plan'] as Map<String, dynamic>;
  }

  test('`make engine Login` parses Login as the entity', () async {
    final plan = await planFor(['make', 'engine', 'Login']);

    expect(plan['name'], 'Login', reason: 'entity is the token after engine');
    expect(plan['preset'], 'engine');
    expect(
      (plan['plugin_ids'] as List).cast<String>(),
      containsAll([
        'usecase',
        'service',
        'provider',
        'repository',
        'datasource',
        'mock',
        'di',
      ]),
    );
  });

  test('engine plan carries no Flutter-importing plugins', () async {
    final plan = await planFor(['make', 'engine', 'Login']);

    final pluginIds = (plan['plugin_ids'] as List).cast<String>().toSet();
    expect(pluginIds, isNot(contains('view')));
    expect(pluginIds, isNot(contains('presenter')));
    expect(pluginIds, isNot(contains('controller')));
    expect(pluginIds, isNot(contains('state')));
    expect(pluginIds, isNot(contains('route')));
  });

  test('`make engine` without an entity is a usage error', () async {
    final result = await runZfaSource([
      'make',
      'engine',
    ], workingDirectory: workspace.path);

    expect(result.exitCode, isNot(0), reason: 'missing entity must fail');
    expect(result.stdout as String, contains('Usage'));
  });

  test('non-engine make semantics are unchanged (crud preset)', () async {
    // Hard constraint: existing make semantics for non-engine presets.
    await writeEntity('Product');

    final plan = await planFor(['make', 'Product', '--preset=crud']);

    expect(plan['name'], 'Product');
    expect(plan['preset'], 'crud');
    expect((plan['plugin_ids'] as List).cast<String>(), [
      'usecase',
      'repository',
      'datasource',
      'di',
    ]);
  });

  test(
    'an entity literally named "Engine" still generates (case guard)',
    () async {
      // `zfa make Engine usecase` — the entity name is PascalCase; the mode
      // token is the lowercase `engine`. Only the exact lowercase token (as
      // the FIRST positional) switches to engine mode.
      await writeEntity('Engine');

      final plan = await planFor(['make', 'Engine', 'usecase']);

      expect(plan['name'], 'Engine');
      expect(plan['preset'], isNull);
      expect((plan['plugin_ids'] as List).cast<String>(), contains('usecase'));
    },
  );

  test('--preset=<other> conflicts with the engine mode token', () async {
    final result = await runZfaSource([
      'make',
      'engine',
      'Login',
      '--preset=crud',
    ], workingDirectory: workspace.path);

    expect(result.exitCode, 64, reason: 'conflicting preset is a usage error');
    expect(result.stdout as String, contains('conflicts'));
  });
}
