@Tags(['slow'])
library;

// Spec 1002 — `zfa make engine Login` end-to-end (slow tier, real CLI
// subprocess per issue #506 pattern).
//
// Exit criteria under test (issue #1002):
//   1. `zfa make engine Login` produces a runnable engine slice in a
//      single command (entity auto-created, no transaction conflict on
//      di/index.dart — the di+mock ordering fix).
//   2. `zfa engine check Login` exits 0.
//   3. The engine slice's test tree contains zero package:flutter
//      references (and neither does the lib tree).
//   4. engine.receipt.json lists all methods with mock_certified: true.
//   5. `zfa mock create Login --certify` certifies per-method.

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
    workspace = await Directory.systemTemp.createTemp('zfa_make_engine_e2e_');
    // Entity creation requires the zorphy annotation dependency in the
    // target project's pubspec (the entity imports it).
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: make_engine_e2e_test
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

  test(
    '`zfa make engine Login` generates + checks + receipts in one shot',
    timeout: const Timeout(Duration(minutes: 4)),
    () async {
      final result = await runZfaSource(
        ['make', 'engine', 'Login'],
        workingDirectory: workspace.path,
        timeout: const Duration(minutes: 3),
      );

      // 1. The run completes without the di+mock transaction conflict.
      expect(
        result.stdout as String,
        isNot(contains('Transaction failed')),
        reason:
            'di/index.dart must be written exactly once '
            '(di runs after mock; mock skips the redundant main-index sync)',
      );
      expect(
        result.stdout as String,
        isNot(contains('Generation failed')),
        reason: 'stdout: ${result.stdout}',
      );
      expect(result.exitCode, 0, reason: 'stdout: ${result.stdout}');

      // 2. Entity auto-created in the same command (with an id identity).
      final entityFile = File(
        p.join(workspace.path, 'lib/src/domain/entities/login/login.dart'),
      );
      expect(
        entityFile.existsSync(),
        isTrue,
        reason: 'entity create step runs inside make engine',
      );
      expect(entityFile.readAsStringSync(), contains('id'));

      // 3. The engine slice: per-method usecases, repository, datasource,
      //    mock, DI. (The service/provider chain steps generate nothing for
      //    a bare entity — they activate when a service is named; the
      //    engine preset keeps them in the plan per the spec chain.)
      final slice = <String>[
        'lib/src/domain/usecases/login/get_login_usecase.dart',
        'lib/src/domain/usecases/login/get_login_list_usecase.dart',
        'lib/src/domain/usecases/login/create_login_usecase.dart',
        'lib/src/domain/usecases/login/update_login_usecase.dart',
        'lib/src/domain/usecases/login/delete_login_usecase.dart',
        'lib/src/domain/repositories/login_repository.dart',
        'lib/src/data/datasources/login/login_datasource.dart',
        'lib/src/data/datasources/login/login_remote_datasource.dart',
        'lib/src/data/datasources/login/login_mock_datasource.dart',
        'lib/src/data/mock/login_mock_data.dart',
        'lib/src/di/usecases/get_login_usecase_di.dart',
        'lib/src/di/repositories/login_repository_di.dart',
        'lib/src/di/simulation/login_simulation_datasource_di.dart',
        'lib/src/di/index.dart',
      ];
      for (final rel in slice) {
        expect(
          File(p.join(workspace.path, rel)).existsSync(),
          isTrue,
          reason: 'missing engine slice file: $rel',
        );
      }

      // 4. Zero package:flutter references under lib/ and test/.
      for (final root in ['lib', 'test']) {
        final dir = Directory(p.join(workspace.path, root));
        if (!dir.existsSync()) continue;
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final content = file.readAsStringSync();
          expect(
            content,
            isNot(contains('package:flutter')),
            reason:
                '${p.relative(file.path, from: workspace.path)} imports '
                'Flutter — the engine slice must stay pure Dart',
          );
        }
      }

      // 5. Receipt: all methods certified.
      final receiptFile = File(
        p.join(workspace.path, '.zfa', 'engine.receipt.json'),
      );
      expect(receiptFile.existsSync(), isTrue, reason: 'auto-receipt written');
      final receipt =
          jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
      expect(receipt['schema'], 'engine.v1');
      expect(receipt['command'], 'zfa make engine Login');
      expect(receipt['target'], 'Login');
      final methods = (receipt['methods'] as List).cast<Map<String, dynamic>>();
      expect(methods.map((m) => m['method']).toSet(), {
        'get',
        'getList',
        'create',
        'update',
        'delete',
      });
      for (final method in methods) {
        expect(
          method['mock_certified'],
          isTrue,
          reason: 'method ${method["method"]} must be mock-certified',
        );
      }
      expect((receipt['entity'] as Map<String, dynamic>)['digest'], isNotNull);
      expect(
        (receipt['di_wired'] as Map<String, dynamic>)['di_files'],
        isNotEmpty,
      );
      expect(
        (receipt['di_wired'] as Map<String, dynamic>)['getit_types'],
        contains('LoginRepository'),
      );
      expect(
        (receipt['engine_check'] as Map<String, dynamic>)['passed'],
        isTrue,
      );

      // 6. The standalone verb exits 0 against the generated tree.
      final check = await runZfaSource([
        'engine',
        'check',
        'Login',
      ], workingDirectory: workspace.path);
      expect(
        check.exitCode,
        0,
        reason: 'zfa engine check Login exits 0; stdout: ${check.stdout}',
      );
    },
  );

  test(
    '`zfa engine check` fails on a dangling getIt reference after '
    'deleting a generated datasource class',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      await runZfaSource(
        ['make', 'engine', 'Login', '--methods=get'],
        workingDirectory: workspace.path,
        timeout: const Duration(minutes: 2),
      );

      final remote = File(
        p.join(
          workspace.path,
          'lib/src/data/datasources/login/login_remote_datasource.dart',
        ),
      );
      expect(remote.existsSync(), isTrue);
      await remote.delete();

      final check = await runZfaSource([
        'engine',
        'check',
        'Login',
      ], workingDirectory: workspace.path);

      expect(check.exitCode, 1);
      expect(check.stdout as String, contains('LoginRemoteDataSource'));
      expect(check.stdout as String, contains('--> fix:'));
    },
  );

  test(
    'mock create --certify certifies per-method and exits 0',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      // Generate the engine slice first (mock included).
      await runZfaSource(
        ['make', 'engine', 'Login', '--methods=get,update'],
        workingDirectory: workspace.path,
        timeout: const Duration(minutes: 2),
      );

      // Re-run the mock create capability with --certify.
      final result = await runZfaSource([
        'mock',
        'create',
        'Login',
        '--methods=get,update',
        '--certify',
      ], workingDirectory: workspace.path);

      expect(
        result.stdout as String,
        contains('certified'),
        reason: 'stdout: ${result.stdout}',
      );
      expect(result.exitCode, 0, reason: 'certified mocks exit 0');
    },
  );

  test(
    'acceptance: generated tree analyzes clean (dart analyze)',
    timeout: const Timeout(Duration(minutes: 8)),
    () async {
      // The acceptance criterion: `dart analyze lib/src/domain/ lib/src/data/
      // lib/src/services/` exits 0 in the generated tree. Services live
      // under lib/src/domain/services in the zuraffa layout, and the
      // entity's concrete part classes come from `zfa build` (canonical v5
      // workflow), so the full acceptance sequence is:
      // make engine → zfa build → dart analyze.
      final projectRoot = await findProjectRoot();
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: make_engine_analyze_test
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

      final make = await runZfaSource(
        ['make', 'engine', 'Login', '--methods=get,update'],
        workingDirectory: workspace.path,
        timeout: const Duration(minutes: 2),
      );
      expect(make.exitCode, 0, reason: 'stdout: ${make.stdout}');

      final build = await runZfaSource(
        ['build', '--no-analyze'],
        workingDirectory: workspace.path,
        timeout: const Duration(minutes: 4),
      );
      expect(
        build.exitCode,
        0,
        reason: 'zfa build failed; stdout: ${build.stdout}',
      );

      final analyze = await Process.run('dart', [
        'analyze',
        '--no-fatal-warnings',
        'lib/src/domain',
        'lib/src/data',
        'lib/src/di',
      ], workingDirectory: workspace.path);
      expect(
        analyze.exitCode,
        0,
        reason: 'stdout: ${analyze.stdout}\nstderr: ${analyze.stderr}',
      );
    },
  );
}
