// Spec 1194 — make-default emits the mocked tier: plan resolution.
// https://github.com/arrrrny/zuraffa/issues/1194 (part of #908 P0
// "make-default→mock + mocked tier").
//
// The default data presets (`crud`, `read-only`) must resolve the `mock`
// plugin so a fresh `zfa make <Entity> --preset=crud` slice lands in the
// MOCKED tier: certified mock datasource behind the real interface
// (simulation-mode binding) + mock data seeds, with `di` wiring
// `registerSimulationBindings` — the slice is demo-green on first run,
// before any real adapter is written.
//
// The `--compile-only` flag is the opt-out for teams who want the old
// compile-only slices (no mocked tier emitted).
//
// Driven through a real subprocess ([runZfaSource]) so plan output is the
// real CLI's (issue #506 pattern); `--plan` writes nothing, so these are
// fast-tier.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_make_tier_plan_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: make_tier_plan_test
environment:
  sdk: ^3.11.0
''');
    await _writeEntity(workspace, 'Product');
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
    // EPIC 1150: the envelope wraps the plan payload inside `data`.
    expect(decoded['schema'], 'zuraffa.verdict.v1');
    final payload = decoded['data'] as Map<String, dynamic>;
    expect(payload['success'], isTrue);
    return payload['plan'] as Map<String, dynamic>;
  }

  test(
    'crud preset resolves the mocked tier (mock plugin in the plan)',
    () async {
      final plan = await planFor(['make', 'Product', '--preset=crud']);

      expect(plan['preset'], 'crud');
      final pluginIds = (plan['plugin_ids'] as List).cast<String>();
      // The data-tier chain is unchanged...
      expect(
        pluginIds,
        containsAll(['usecase', 'repository', 'datasource', 'di']),
      );
      // ...and the mocked tier is now part of the default: the slice boots
      // on certified mocks (issue #1194).
      expect(
        pluginIds,
        contains('mock'),
        reason:
            'the crud preset must include the mock plugin so a fresh slice '
            'lands in the MOCKED tier (issue #1194); resolved: $pluginIds',
      );
    },
  );

  test(
    'read-only preset resolves the mocked tier (parity with crud)',
    () async {
      final plan = await planFor(['make', 'Product', '--preset=read-only']);

      final pluginIds = (plan['plugin_ids'] as List).cast<String>();
      expect(
        pluginIds,
        contains('mock'),
        reason:
            'read-only is crud\'s sibling data preset — it must emit the '
            'mocked tier too (issue #1194); resolved: $pluginIds',
      );
    },
  );

  test(
    '--compile-only opts out of the mocked tier (issue #1194 opt-out flag)',
    () async {
      final plan = await planFor([
        'make',
        'Product',
        '--preset=crud',
        '--compile-only',
      ]);

      final pluginIds = (plan['plugin_ids'] as List).cast<String>();
      expect(
        pluginIds,
        isNot(contains('mock')),
        reason:
            '--compile-only must drop the mock plugin: compile-only slice, '
            'not demo-green (issue #1194); resolved: $pluginIds',
      );
      // The compile-only slice keeps the rest of the data tier.
      expect(
        pluginIds,
        containsAll(['usecase', 'repository', 'datasource', 'di']),
      );
    },
  );

  test('--compile-only wins over an explicit --mock', () async {
    final result = await runZfaSource([
      'make',
      'Product',
      '--preset=crud',
      '--mock',
      '--compile-only',
      '--plan',
      '--format=json',
    ], workingDirectory: workspace.path);
    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
    final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    // EPIC 1150: the envelope wraps the plan payload inside `data`.
    final plan =
        (decoded['data'] as Map<String, dynamic>)['plan']
            as Map<String, dynamic>;
    final pluginIds = (plan['plugin_ids'] as List).cast<String>();
    expect(
      pluginIds,
      isNot(contains('mock')),
      reason:
          'the opt-out is explicit intent — it must win over the preset and '
          'over --mock; resolved: $pluginIds',
    );
  });

  test('--without=mock still excludes the mocked tier', () async {
    final plan = await planFor([
      'make',
      'Product',
      '--preset=crud',
      '--without=mock',
    ]);

    final pluginIds = (plan['plugin_ids'] as List).cast<String>();
    expect(
      pluginIds,
      isNot(contains('mock')),
      reason: '--without=mock remains the generic per-plugin exclusion',
    );
  });

  test('engine preset keeps its mocked tier (already mock-first)', () async {
    await _writeEntity(workspace, 'Login');

    final plan = await planFor(['make', 'engine', 'Login']);

    expect(plan['preset'], 'engine');
    final pluginIds = (plan['plugin_ids'] as List).cast<String>();
    expect(pluginIds, contains('mock'));
  });

  test(
    '--compile-only on the engine token still drops the mock plugin',
    () async {
      await _writeEntity(workspace, 'Login');

      final plan = await planFor(['make', 'engine', 'Login', '--compile-only']);

      final pluginIds = (plan['plugin_ids'] as List).cast<String>();
      expect(
        pluginIds,
        isNot(contains('mock')),
        reason:
            'the opt-out applies uniformly to every preset path '
            '(issue #1194); resolved: $pluginIds',
      );
    },
  );
}

Future<void> _writeEntity(Directory workspace, String name) async {
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
