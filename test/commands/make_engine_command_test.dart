@Tags(['slow'])
library;

// Spec 1002 — `zfa make engine Login` end-to-end (slow tier, real CLI
// subprocess per issue #506 pattern).
//
// Exit criteria under test (issue #1002 + spec 1110's cert-gate):
//   1. `zfa make engine Login` produces a runnable engine slice in a
//      single command (entity auto-created, no transaction conflict on
//      di/index.dart — the di+mock ordering fix).
//   2. `zfa engine check Login` exits 0 — AFTER `zfa mock create Login
//      --certify` (spec 1110: the cert-gate refuses an uncertified CORE
//      entity first, then the certify receipt unblocks it).
//   3. The engine slice's test tree contains zero package:flutter
//      references (and neither does the lib tree).
//   4. engine.receipt.json lists all methods with mock_certified: true
//      (structural) and records failure_mode.
//   5. `zfa mock create Login --certify` certifies per-method (exit 0
//      with the mock-cert.Login.json receipt).

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
    '`zfa make engine Login` generates the slice; the cert-gate refuses '
    'the uncertified CORE entity (spec 1110)',
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
      // Spec 1110: the engine pipeline REFUSES to proceed on an
      // uncertified CORE entity — the tail check fails with the
      // refusal receipt naming the fix. The slice itself is generated.
      expect(
        result.exitCode,
        1,
        reason:
            'the cert-gate must fail the make-engine tail check '
            '(exit 1, refusal receipt); stdout: ${result.stdout}',
      );
      expect(
        result.stdout as String,
        allOf(
          contains('--> fix:'),
          contains('zfa mock create Login --certify'),
        ),
        reason:
            'the refusal names the exact cert command; '
            'stdout: ${result.stdout}',
      );

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
      //    mock, DI, test scaffold. (The service/provider chain steps
      //    generate nothing for a bare entity — they activate when a
      //    service is named; the engine preset keeps them in the plan per
      //    the spec chain.)
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

      // 3b. Test scaffold (issue #1109 FR-001: the chain ends with the
      // test plugin; the engine lane forces the pure-Dart `package:test`
      // framework import even in Flutter projects — zero flutter_test in
      // the engine test tree).
      final testScaffold = <String>[
        'test/domain/usecases/login/get_login_usecase_test.dart',
        'test/domain/usecases/login/create_login_usecase_test.dart',
      ];
      for (final rel in testScaffold) {
        expect(
          File(p.join(workspace.path, rel)).existsSync(),
          isTrue,
          reason: 'missing engine test scaffold file: $rel',
        );
      }
      for (final rel in testScaffold) {
        expect(
          File(p.join(workspace.path, rel)).readAsStringSync(),
          isNot(contains('package:flutter_test')),
          reason: '$rel must import package:test (engine lane purity)',
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

      // 5. Receipt: all methods structurally certified; the gate's
      //    failure is recorded; failure_mode defaults to succeeding.
      final receiptFile = File(
        p.join(workspace.path, '.zfa', 'engine.receipt.json'),
      );
      expect(receiptFile.existsSync(), isTrue, reason: 'auto-receipt written');
      final receipt =
          jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
      expect(receipt['schema'], 'engine.v1');
      expect(receipt['command'], 'zfa make engine Login');
      expect(receipt['target'], 'Login');
      // Spec 1110: which mock double the cycle targets.
      expect(receipt['failure_mode'], 'succeeding');
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
      // Spec 1110: the tail check REFUSED — the receipt records the
      // gate failure honestly, with the cert fix.
      expect(
        (receipt['engine_check'] as Map<String, dynamic>)['passed'],
        isFalse,
      );
      final receiptFailures =
          ((receipt['engine_check'] as Map<String, dynamic>)['failures']
                  as List)
              .cast<Map<String, dynamic>>();
      expect(
        receiptFailures.map((f) => f['code']),
        contains('uncertifiedCoreEntity'),
      );

      // 5b. Receipt v2 (issue #1109): specs/<feature>/tdd/engine.receipt.json
      // with the CERT-GATE shape — methods[].{name, mock_certified,
      // mock_class} + sorted source_files. Fresh project, no pinned
      // feature: the entity-derived fallback dir (specs/login/tdd/).
      final v2ReceiptFile = File(
        p.join(workspace.path, 'specs', 'login', 'tdd', 'engine.receipt.json'),
      );
      expect(
        v2ReceiptFile.existsSync(),
        isTrue,
        reason: 'v2 receipt written under specs/<feature>/tdd/',
      );
      final v2Receipt =
          jsonDecode(v2ReceiptFile.readAsStringSync()) as Map<String, dynamic>;
      expect(v2Receipt['schema'], 'engine.receipt.v2');
      expect(v2Receipt['entity'], 'Login');
      final v2Methods = (v2Receipt['methods'] as List)
          .cast<Map<String, dynamic>>();
      expect(v2Methods.map((m) => m['name']).toSet(), {
        'get',
        'getList',
        'create',
        'update',
        'delete',
      });
      for (final method in v2Methods) {
        expect(
          method['mock_certified'],
          isTrue,
          reason: 'v2: method ${method["name"]} must be certified',
        );
        expect(
          method['mock_class'],
          isNotNull,
          reason: 'v2: method ${method["name"]} must carry its mock class',
        );
      }
      final v2Sources = (v2Receipt['source_files'] as List).cast<String>();
      expect(v2Sources, isNotEmpty);
      expect(v2Sources, equals([...v2Sources]..sort()));
      expect(v2Sources, contains('lib/src/domain/entities/login/login.dart'));

      // 6. Spec 1110 success criterion 1: the standalone verb exits
      //    NON-ZERO against the generated tree — the cert gate blocks
      //    the uncertified CORE entity even though the structural
      //    certification (5b) is green.
      final check = await runZfaSource([
        'engine',
        'check',
        'Login',
      ], workingDirectory: workspace.path);
      expect(
        check.exitCode,
        1,
        reason:
            'uncertified CORE entity must fail the engine check; '
            'stdout: ${check.stdout}',
      );
      expect(check.stdout as String, contains('Uncertified CORE entity'));
      expect(
        check.stdout as String,
        contains('zfa mock create Login --certify'),
      );
      expect(
        check.stdout as String,
        contains('engine.gate.Login.refused.json'),
        reason: 'the refusal receipt path is surfaced',
      );
      final refused = File(
        p.join(workspace.path, '.zfa', 'engine.gate.Login.refused.json'),
      );
      expect(refused.existsSync(), isTrue);
      final refusal =
          jsonDecode(refused.readAsStringSync()) as Map<String, dynamic>;
      expect(refusal['entity'], 'Login');
      expect(refusal['fix'], 'zfa mock create Login --certify');
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
    'spec 1110 criterion 2: mock create --certify unblocks engine check '
    '(build → certify → check exits 0)',
    timeout: const Timeout(Duration(minutes: 12)),
    () async {
      // The canonical #1109 acceptance sequence: make engine → build
      // (the entity's zorphy parts) → certify → engine check. The
      // certification sandbox compiles the subject tree, so the entity
      // part files must exist first.
      final projectRoot = await findProjectRoot();
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: make_engine_cert_test
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
      // The slice generates; the cert-gate refuses (exit 1) — the
      // criterion-1 contract, proven above in detail.
      expect(
        make.stdout as String,
        contains('zfa mock create Login --certify'),
        reason: 'the refusal names the fix; stdout: ${make.stdout}',
      );

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

      // The fix: certify (exit 0, receipt written).
      final result = await runZfaSource([
        'mock',
        'create',
        'Login',
        '--methods=get,update',
        '--certify',
        '--force',
      ], workingDirectory: workspace.path);
      expect(
        result.exitCode,
        0,
        reason: 'certify must exit 0; stdout: ${result.stdout}',
      );
      final receipt = File(
        p.join(workspace.path, 'test', 'mock', 'login', 'mock-cert.Login.json'),
      );
      expect(receipt.existsSync(), isTrue, reason: 'the cert receipt exists');

      // The gate heals: engine check exits 0.
      final check = await runZfaSource([
        'engine',
        'check',
        'Login',
      ], workingDirectory: workspace.path);
      expect(
        check.exitCode,
        0,
        reason:
            'zfa engine check Login exits 0 after --certify; '
            'stdout: ${check.stdout}',
      );
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
      // Spec 1110: the cert-gate refuses the tail check (exit 1 — the
      // refusal receipt names the fix); the acceptance under test here
      // is the generated tree's analyze-cleanliness, not the gate.
      expect(
        make.exitCode,
        1,
        reason:
            'the cert-gate fails the tail check on the uncertified '
            'mock; stdout: ${make.stdout}',
      );

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
