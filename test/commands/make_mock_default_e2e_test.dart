@Tags(['slow'])
library;

// Spec 1194 — `[MOCK-FIRST] generated apps boot in simulation mode by
// default — make-default emits the mocked tier`
// https://github.com/arrrrny/zuraffa/issues/1194 (part of #908 P0
// "make-default→mock + mocked tier").
//
// Exit criteria under test (issue #1194 acceptance):
//   1. A fresh `zfa make Product --preset=crud` slice is demo-green on
//      first run: certified mock datasource behind the real interface
//      (simulation-mode binding), mock data seeds, and
//      `registerSimulationBindings(getIt)` wired into di/index.dart —
//      zero hand wiring.
//   2. The generation receipt records MOCKED as the tier (the receipt/
//      ladder vocabulary; swapping to REAL is `zfa tdd realize`'s job —
//      companion issue).
//   3. The emitted mock is certified by default (structural certification
//      receipt under .zfa/receipts/mock-<entity>.json).
//   4. `--compile-only` opts out: no mocked tier emitted, receipt records
//      COMPILE-ONLY.
//   5. Boot proof: `setupDependencies` + `getIt<ProductDataSource>()` under
//      `--dart-define=SIMULATION=true` resolves the certified mock and
//      serves seeded data (the app runs in simulation mode).
//
// Slow tier, real CLI subprocess per issue #506 pattern.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart';
import '../helpers/run_zfa_source.dart';

void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_make_tier_e2e_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: make_tier_e2e_test
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: ^2.3.0
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

  test(
    '`zfa make Product --preset=crud` emits the mocked tier + records '
    'MOCKED in the receipt + certifies the mock by default',
    timeout: const Timeout(Duration(minutes: 4)),
    () async {
      await writeEntity('Product');

      final result = await runZfaSource(
        ['make', 'Product', '--preset=crud', '--force'],
        workingDirectory: workspace.path,
        timeout: const Duration(minutes: 3),
      );
      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );

      // 1. The mocked tier files: certified mock datasource, mock data
      //    seeds, simulation-mode binding, simulation index.
      final mockedTierFiles = <String>[
        'lib/src/data/datasources/product/product_mock_datasource.dart',
        'lib/src/data/mock/product_mock_data.dart',
        'lib/src/di/simulation/product_simulation_datasource_di.dart',
        'lib/src/di/simulation/index.dart',
      ];
      for (final rel in mockedTierFiles) {
        expect(
          File(p.join(workspace.path, rel)).existsSync(),
          isTrue,
          reason: 'missing mocked-tier file: $rel',
        );
      }

      // 2. The simulation binding registers the certified mock behind the
      //    real interface, guarded by the single SIMULATION flavor define.
      final binding = File(
        p.join(
          workspace.path,
          'lib/src/di/simulation/product_simulation_datasource_di.dart',
        ),
      ).readAsStringSync();
      expect(binding, contains('if (!kSimulationMode) return;'));
      expect(
        binding,
        contains('registerLazySingleton<ProductDataSource>('),
        reason: 'the mock must bind behind the REAL interface',
      );
      expect(binding, contains('ProductMockDataSource()'));

      // 3. The composition root wires registerSimulationBindings — zero
      //    hand wiring: the app boots from the mock tier on first run.
      final diIndex = File(
        p.join(workspace.path, 'lib/src/di/index.dart'),
      ).readAsStringSync();
      expect(
        diIndex,
        contains('registerSimulationBindings(getIt);'),
        reason: 'di/index.dart must wire the simulation bindings',
      );

      // 4. Mock data seeds exist and are deterministic.
      final mockData = File(
        p.join(workspace.path, 'lib/src/data/mock/product_mock_data.dart'),
      ).readAsStringSync();
      expect(mockData, contains('class ProductMockData'));
      expect(mockData, contains("Product(id: 'id 1')"));

      // 5. The receipt records MOCKED as the tier (issue #1194: the
      //    receipt/ladder records MOCKED; REAL is `zfa tdd realize`'s job).
      final receipt = _latestMakeReceipt(workspace, 'Product');
      expect(receipt, isNotNull, reason: 'proof.v1 make receipt written');
      expect(receipt!['schema'], 'proof.v1');
      final input = receipt['input'] as Map<String, dynamic>?;
      expect(
        input?['tier'],
        'MOCKED',
        reason:
            'the generation receipt must record the tier as MOCKED; '
            'input keys: ${input?.keys.toList()}',
      );
      // The receipt binds the mocked-tier artifacts by digest.
      final receiptFiles = (receipt['files'] as List)
          .cast<Map<String, dynamic>>()
          .map((f) => f['path'] as String)
          .toList();
      expect(
        receiptFiles,
        containsAll([
          'lib/src/data/datasources/product/product_mock_datasource.dart',
          'lib/src/data/mock/product_mock_data.dart',
          'lib/src/di/simulation/product_simulation_datasource_di.dart',
        ]),
        reason: 'receipt files: $receiptFiles',
      );

      // 6. Certified mocks by default: the structural certification
      //    receipt ships with the run (mock-cert:<entity>@<digest8>).
      final certReceipt = File(
        p.join(workspace.path, '.zfa', 'receipts', 'mock-product.json'),
      );
      expect(
        certReceipt.existsSync(),
        isTrue,
        reason: 'the make run certifies the emitted mock by default',
      );
      final cert =
          jsonDecode(certReceipt.readAsStringSync()) as Map<String, dynamic>;
      expect(cert['schema'], 'proof.v1');
      final certInput = cert['input'] as Map<String, dynamic>?;
      final certification =
          certInput?['certification'] as Map<String, dynamic>?;
      expect(
        certification?['registry_id'],
        startsWith('mock-cert:product@'),
        reason: 'certification: $certification',
      );

      // 7. The run output names the tier so the developer knows which
      //    tier they're on and how to swap it.
      expect(
        result.stdout as String,
        allOf(contains('MOCKED'), contains('SIMULATION=true')),
        reason: 'stdout: ${result.stdout}',
      );
    },
  );

  test(
    '`--compile-only` opts out: compile-only slice, no mocked tier, '
    'COMPILE-ONLY receipt',
    timeout: const Timeout(Duration(minutes: 4)),
    () async {
      await writeEntity('Item');

      final result = await runZfaSource(
        ['make', 'Item', '--preset=crud', '--compile-only', '--force'],
        workingDirectory: workspace.path,
        timeout: const Duration(minutes: 3),
      );
      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );

      // No mocked tier emitted — the pre-#1194 compile-only shape.
      for (final rel in [
        'lib/src/data/datasources/item/item_mock_datasource.dart',
        'lib/src/data/mock/item_mock_data.dart',
        'lib/src/di/simulation/item_simulation_datasource_di.dart',
        'lib/src/di/simulation/index.dart',
      ]) {
        expect(
          File(p.join(workspace.path, rel)).existsSync(),
          isFalse,
          reason: 'compile-only slice must not emit $rel',
        );
      }
      // The rest of the data tier is intact (compile-green).
      for (final rel in [
        'lib/src/data/datasources/item/item_datasource.dart',
        'lib/src/di/datasources/item_remote_datasource_di.dart',
        'lib/src/di/index.dart',
      ]) {
        expect(
          File(p.join(workspace.path, rel)).existsSync(),
          isTrue,
          reason: 'compile-only slice keeps the data tier: $rel',
        );
      }
      final diIndex = File(
        p.join(workspace.path, 'lib/src/di/index.dart'),
      ).readAsStringSync();
      expect(
        diIndex,
        isNot(contains('registerSimulationBindings')),
        reason: 'no simulation wiring for a compile-only slice',
      );

      // The receipt records the honest tier.
      final receipt = _latestMakeReceipt(workspace, 'Item');
      expect(receipt, isNotNull);
      final input = receipt!['input'] as Map<String, dynamic>?;
      expect(input?['tier'], 'COMPILE-ONLY', reason: 'input: $input');
    },
  );

  test(
    'boot proof: fresh crud slice runs in simulation mode — getIt resolves '
    'the certified mock and serves seeded data (no hand wiring)',
    timeout: const Timeout(Duration(minutes: 10)),
    () async {
      // The canonical day-zero sequence: deps → entity → make (mocked
      // tier) → build (zorphy parts) → boot under SIMULATION=true.
      final projectRoot = await findProjectRoot();
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: make_tier_boot_test
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: ${jsonEncode(projectRoot)}
  zorphy_annotation: ^2.3.0
dev_dependencies:
  build_runner: ^2.15.2
''');

      final pubGet = await Process.run('dart', [
        'pub',
        'get',
      ], workingDirectory: workspace.path);
      expect(
        pubGet.exitCode,
        0,
        reason: 'stdout: ${pubGet.stdout}\nstderr: ${pubGet.stderr}',
      );

      final snake = 'inventory';
      final entityDir = Directory(
        p.join(workspace.path, 'lib/src/domain/entities', snake),
      );
      await entityDir.create(recursive: true);
      await File(p.join(entityDir.path, '$snake.dart')).writeAsString('''
import 'package:zorphy_annotation/zorphy_annotation.dart';

part '$snake.zorphy.dart';
part '$snake.g.dart';

/// Inventory entity
@Zorphy(generateJson: true, generateCompareTo: true)
abstract class \$Inventory {
  String get id;
}
''');

      final make = await runZfaSource(
        ['make', 'Inventory', '--preset=crud', '--force'],
        workingDirectory: workspace.path,
        timeout: const Duration(minutes: 3),
      );
      expect(
        make.exitCode,
        0,
        reason: 'stdout: ${make.stdout}\nstderr: ${make.stderr}',
      );
      expect(
        File(
          p.join(
            workspace.path,
            'lib/src/di/simulation/inventory_simulation_datasource_di.dart',
          ),
        ).existsSync(),
        isTrue,
        reason: 'simulation binding emitted by the default make run',
      );

      final build = await runZfaSource(
        ['build', '--no-analyze'],
        workingDirectory: workspace.path,
        timeout: const Duration(minutes: 5),
      );
      expect(
        build.exitCode,
        0,
        reason: 'zfa build failed; stdout: ${build.stdout}',
      );

      // The boot driver: exactly what an app's main() does —
      // setupDependencies, then resolve the interface and read data.
      // Under --dart-define=SIMULATION=true the certified mock serves.
      final toolDir = Directory(p.join(workspace.path, 'tool'));
      await toolDir.create(recursive: true);
      await File(p.join(toolDir.path, 'boot_check.dart')).writeAsString('''
import 'dart:io';

import 'package:make_tier_boot_test/src/data/datasources/inventory/inventory_datasource.dart';
import 'package:make_tier_boot_test/src/data/datasources/inventory/inventory_mock_datasource.dart';
import 'package:make_tier_boot_test/src/domain/entities/inventory/inventory.dart';
import 'package:make_tier_boot_test/src/di/index.dart';
import 'package:zuraffa/zuraffa.dart';

Future<void> main() async {
  final getIt = GetIt.instance;
  setupDependencies(getIt);

  final ds = getIt<InventoryDataSource>();
  if (ds is! InventoryMockDataSource) {
    stderr.writeln('BOOT-FAIL: InventoryDataSource resolved to \${ds.runtimeType}');
    exit(1);
  }
  final record = await ds.get(const QueryParams<Inventory>());
  stderr.writeln('BOOT-OK: \${ds.runtimeType} served \${record.id}');
}
''');

      final boot = await Process.run('dart', [
        'run',
        // VM define syntax for `dart run` (the flavor switch the
        // simulation binding is generated behind):
        // --dart-define=SIMULATION=true for compiled/flutter entrypoints.
        '-DSIMULATION=true',
        'tool/boot_check.dart',
      ], workingDirectory: workspace.path);
      expect(
        boot.exitCode,
        0,
        reason:
            'the slice must run in simulation mode; '
            'stdout: ${boot.stdout}\nstderr: ${boot.stderr}',
      );
      expect(boot.stderr as String, contains('BOOT-OK'));
      expect(boot.stderr as String, contains('InventoryMockDataSource'));
    },
  );
}

/// Loads the newest proof.v1 make receipt for [entity] under
/// `.zfa/receipts/`, or null when none exists.
Map<String, dynamic>? _latestMakeReceipt(Directory workspace, String entity) {
  final dir = Directory(p.join(workspace.path, '.zfa', 'receipts'));
  if (!dir.existsSync()) return null;
  final candidates =
      dir.listSync().whereType<File>().where((f) {
          final name = p.basename(f.path);
          return name.endsWith('.json') &&
              name.contains('-make-') &&
              name.endsWith('-make-$entity.json');
        }).toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
  for (final file in candidates.reversed) {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, dynamic>) return decoded;
  }
  return null;
}
