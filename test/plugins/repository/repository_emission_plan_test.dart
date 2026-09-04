import 'dart:convert';

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/plan/repository_emission_plan.dart';

/// Spec 0973 (issue #973) — `--explain` / `--json` resolved emission plan.
///
/// Kills the flag-maze opacity: the resolved plan states what the
/// repository plugin WILL emit and why (which variant, which flags
/// triggered each decision) — without running generation and without
/// touching PluginManager activation order.
void main() {
  group('RepositoryEmissionPlanner (resolved emission plan)', () {
    test('cache+sync+datasource config — snapshot', () {
      final config = GeneratorConfig(
        name: 'Product',
        methods: ['get', 'update'],
        generateData: true,
        generateDataSource: true,
        enableCache: true,
        enableSync: true,
        outputDir: 'lib/src',
      );

      final plan = const RepositoryEmissionPlanner().resolve(
        config,
        datasourcePluginActive: false,
      );

      // Snapshot: the resolved plan for this flag combination is fully
      // deterministic (output-relative paths, no timestamps).
      expect(
        const JsonEncoder.withIndent('  ').convert(plan.toJson()),
        '''
{
  "plugin": "repository",
  "entity": "Product",
  "valid": false,
  "emissions": [
    {
      "id": "interface",
      "emit": true,
      "path": "domain/repositories/product_repository.dart",
      "class": "ProductRepository",
      "methods": [
        "get",
        "update",
        "syncPending",
        "pullRemote"
      ],
      "triggered_by": [
        "entity-based generation (methods: get, update)",
        "--sync adds syncPending/pullRemote to the interface"
      ]
    },
    {
      "id": "implementation",
      "emit": true,
      "path": "data/repositories/data_product_repository.dart",
      "class": "DataProductRepository",
      "variant": "conflicted",
      "triggered_by": [
        "entity-based generation emits the implementation",
        "--cache and --sync both requested (mutually exclusive: cache is remote-first, sync is local-first)"
      ]
    },
    {
      "id": "datasource_interface",
      "emit": true,
      "path": "data/datasources/product/product_datasource.dart",
      "class": "ProductDataSource",
      "triggered_by": [
        "--datasource requested",
        "emitted by the repository plugin because the datasource plugin is NOT active"
      ]
    }
  ],
  "warnings": [
    "--cache and --sync are mutually exclusive: cache is remote-first, sync is local-first (generation would fail with ArgumentError)"
  ]
}''',
      );
    });

    test('simple variant for a plain entity-based config', () {
      final plan = const RepositoryEmissionPlanner().resolve(
        GeneratorConfig(
          name: 'Order',
          methods: ['get'],
          generateData: true,
          outputDir: 'lib/src',
        ),
        datasourcePluginActive: false,
      );

      final impl = plan.emissions.firstWhere((e) => e.id == 'implementation');
      expect(impl.variant, 'simple');
      expect(impl.emit, isTrue);
      expect(plan.valid, isTrue);
      expect(plan.warnings, isEmpty);
    });

    test('cached variant selected when --cache is set (without sync)', () {
      final plan = const RepositoryEmissionPlanner().resolve(
        GeneratorConfig(
          name: 'Order',
          methods: ['get'],
          generateData: true,
          enableCache: true,
          outputDir: 'lib/src',
        ),
        datasourcePluginActive: false,
      );
      expect(
        plan.emissions.firstWhere((e) => e.id == 'implementation').variant,
        'cached',
      );
    });

    test('datasource interface skipped when the datasource plugin is active',
        () {
      final plan = const RepositoryEmissionPlanner().resolve(
        GeneratorConfig(
          name: 'Order',
          methods: ['get'],
          generateData: true,
          generateDataSource: true,
          outputDir: 'lib/src',
        ),
        datasourcePluginActive: true,
      );

      final ds = plan.emissions.firstWhere((e) => e.id == 'datasource_interface');
      expect(ds.emit, isFalse);
      expect(
        ds.triggeredBy,
        contains('skipped: the datasource plugin is active and emits it itself'),
      );
    });
  });

  group('zfa make --explain / --json (CLI surface)', () {
    late Directory workspace;
    late CliRunner runner;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_explain_');
      await Directory(
        p.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'product'),
      ).create(recursive: true);
      await File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'product',
          'product.dart',
        ),
      ).writeAsString('''
class Product {
  final String id;
  const Product({required this.id});
}
''');
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_explain_test
environment:
  sdk: ^3.11.0
''');
      runner = CliRunner(exitOnCompletion: false);
    });

    tearDown(() {
      exitCode = 0;
      if (workspace.existsSync()) {
        workspace.deleteSync(recursive: true);
      }
    });

    test('--explain --json prints the resolved emission plan object', () async {
      // NOTE: `--sync` reaches the repository plugin through the sync
      // plugin's ACTIVATION (positional `sync` → PluginManager activation
      // sync writes data['sync'] = true) — the same way generation sees
      // it. The explain surface deliberately mirrors that wiring instead
      // of reinterpreting flags (spec constraint: do not reorder
      // PluginManager activation).
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'make',
        'Product',
        'repository',
        'sync',
        '--methods=get,update',
        '--cache',
        '--datasource',
        '--explain',
        '--json',
      ]);

      final jsonLine = output
          .split('\n')
          .map((l) => l.trim())
          .firstWhere(
            (l) => l.startsWith('{') && l.contains('"emission"'),
            orElse: () => fail('no resolved-plan JSON line in:\n$output'),
          );

      final decoded = jsonDecode(jsonLine) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      final emission = decoded['emission'] as Map<String, dynamic>;
      expect(emission['plugin'], 'repository');
      expect(emission['entity'], 'Product');
      // The resolved plan surfaces the cache+sync conflict instead of
      // silently picking a variant.
      expect(emission['valid'], isFalse);
      expect(
        (emission['emissions'] as List)
            .whereType<Map>()
            .map((e) => e['id'])
            .toSet(),
        containsAll(['interface', 'implementation', 'datasource_interface']),
      );
      // And it matches what the planner resolves for the same config —
      // the CLI surface is a thin view over the planner, not a re-implementation.
      final fromPlanner = const RepositoryEmissionPlanner().resolve(
        GeneratorConfig(
          name: 'Product',
          methods: ['get', 'update'],
          generateData: true,
          generateDataSource: true,
          enableCache: true,
          enableSync: true,
          outputDir: 'lib/src',
        ),
        datasourcePluginActive: true,
      );
      expect(emission, fromPlanner.toJson());
    });

    test('--explain (text) renders the emission plan for humans', () async {
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'make',
        'Product',
        'repository',
        '--methods=get,update',
        '--explain',
      ]);

      expect(output, contains('Emission plan (repository):'));
      expect(output, contains('interface'));
      expect(output, contains('implementation'));
      expect(output, contains('variant: simple'));
    });
  });
}
