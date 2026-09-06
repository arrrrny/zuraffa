// Spec 077 / issue #1109 — engine check legs (T011, behaviors A7–A10/U9/U10).
//
// `zfa engine check <Entity>` gains two legs beyond the spec-1002 getIt /
// purity / mock-cert checks:
//   (a) static analysis — `dart analyze` scoped to the entity's slice
//       files, findings mapped to EngineCheckFailures with file + message;
//   (b) receipt certification — specs/<feature>/tdd/engine.receipt.json
//       must exist and contain no mock_certified: false.
//
// The analyze runner is injectable (the MockCertifier seam pattern), so
// these behavioral tests run in the fast tier without spawning the real
// analyzer.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/engine/engine_checker.dart';
import 'package:zuraffa/src/engine/engine_receipt_writer.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_engine_check2_');
    EngineChecker.analyzeRunnerOverride = null;
  });

  tearDown(() async {
    EngineChecker.analyzeRunnerOverride = null;
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  Future<void> writeFile(String relPath, String content) async {
    final file = File(p.join(workspace.path, relPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Minimal canonical slice: entity + repository + datasource + mock +
  /// DI wiring + mock data (the checker's getIt/purity/cert legs go green
  /// on it; only the new legs vary per test).
  Future<void> writeCanonicalSlice() async {
    await writeFile('lib/src/domain/entities/login/login.dart', '''
class Login {
  final String id;
  const Login({required this.id});
}
''');
    await writeFile('lib/src/domain/repositories/login_repository.dart', '''
abstract class LoginRepository {}
''');
    await writeFile('lib/src/data/datasources/login/login_datasource.dart', '''
abstract class LoginDataSource {}
''');
    await writeFile(
      'lib/src/data/datasources/login/login_remote_datasource.dart',
      'class LoginRemoteDataSource implements LoginDataSource {}',
    );
    await writeFile(
      'lib/src/data/datasources/login/login_mock_datasource.dart',
      'class LoginMockDataSource implements LoginDataSource {\n'
          '  @override\n'
          '  Future<Login?> get(String id) async => null;\n'
          '}',
    );
    await writeFile('lib/src/data/mock/login_mock_data.dart', '''
class LoginMockData {}
''');
    await writeFile('lib/src/domain/usecases/login/get_login_usecase.dart', '''
class GetLoginUseCase {
  final LoginRepository repo;
  GetLoginUseCase(this.repo);
}
''');
    await writeFile('lib/src/data/repositories/data_login_repository.dart', '''
class DataLoginRepository implements LoginRepository {}
''');
    await writeFile('lib/src/di/usecases/get_login_usecase_di.dart', '''
import 'package:get_it/get_it.dart';

void registerGetLoginUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetLoginUseCase>(
    () => GetLoginUseCase(getIt<LoginRepository>()),
  );
}
''');
    await writeFile('lib/src/di/repositories/login_repository_di.dart', '''
import 'package:get_it/get_it.dart';

void registerLoginRepository(GetIt getIt) {
  getIt.registerLazySingleton<LoginRepository>(
    () => DataLoginRepository(getIt<LoginRemoteDataSource>()),
  );
}
''');
    await writeFile('lib/src/di/index.dart', '''
import 'package:get_it/get_it.dart';

void setupDependencies(GetIt getIt) {
  registerGetLoginUseCase(getIt);
  registerLoginRepository(getIt);
}
''');
  }

  Future<void> writeV2Receipt({
    List<({String name, bool certified, String? mockClass})> methods = const [
      (name: 'get', certified: true, mockClass: 'LoginMockDataSource'),
    ],
    String entity = 'Login',
    String feature = '005-login-engine',
  }) async {
    await const EngineReceiptWriter(projectRoot: '').writeV2(
      projectRoot: workspace.path,
      feature: feature,
      entityName: entity,
      methods: [
        for (final m in methods)
          EngineReceiptMethod(
            name: m.name,
            mockCertified: m.certified,
            mockClass: m.mockClass,
          ),
      ],
      sourceFiles: const ['lib/src/domain/entities/login/login.dart'],
    );
  }

  test(
    'A7 — healthy slice + receipt + clean analyze passes all legs',
    () async {
      await writeCanonicalSlice();
      await writeV2Receipt();
      // Package config present so the analyze leg actually runs.
      await writeFile('.dart_tool/package_config.json', '{}');

      EngineChecker.analyzeRunnerOverride = (files, workingDirectory) async =>
          (exitCode: 0, output: 'No issues found!');

      final result = await EngineChecker.check(
        entity: 'Login',
        projectRoot: workspace.path,
        methods: const ['get'],
        feature: '005-login-engine',
        verifyReceipt: true,
        runStaticAnalysis: true,
      );

      expect(
        result.failures,
        isEmpty,
        reason: 'failures: ${result.failures.map((f) => f.message)}',
      );
      expect(result.passed, isTrue);
      expect(result.analyzedFiles, isNotEmpty);
    },
  );

  test(
    'A8 — a Flutter import fails the check and names the offending file',
    () async {
      await writeCanonicalSlice();
      await writeV2Receipt();
      await writeFile('lib/src/domain/repositories/login_repository.dart', '''
import 'package:flutter/material.dart';

abstract class LoginRepository {}
''');

      final result = await EngineChecker.check(
        entity: 'Login',
        projectRoot: workspace.path,
        methods: const ['get'],
        feature: '005-login-engine',
        verifyReceipt: true,
      );

      expect(result.passed, isFalse);
      final flutter = result.failures
          .where((f) => f.code == EngineFindingCode.flutterImport)
          .toList();
      expect(flutter, isNotEmpty);
      expect(
        flutter.first.file,
        'lib/src/domain/repositories/login_repository.dart',
        reason: 'the failure must name the offending file',
      );
    },
  );

  test(
    'A9 — an uncertified method in the receipt fails naming the method',
    () async {
      await writeCanonicalSlice();
      await writeV2Receipt(
        methods: const [
          (name: 'get', certified: true, mockClass: 'LoginMockDataSource'),
          (name: 'delete', certified: false, mockClass: null),
        ],
      );

      final result = await EngineChecker.check(
        entity: 'Login',
        projectRoot: workspace.path,
        feature: '005-login-engine',
        verifyReceipt: true,
      );

      expect(result.passed, isFalse);
      final uncertified = result.failures
          .where((f) => f.code == EngineFindingCode.receiptUncertified)
          .toList();
      expect(uncertified, hasLength(1));
      expect(uncertified.first.typeName, 'delete');
      expect(
        uncertified.first.message,
        contains('delete'),
        reason: 'the failure must name the uncertified method',
      );
      expect(uncertified.first.message, contains('--> fix:'));
    },
  );

  test(
    'a missing receipt fails with a "run zfa make engine first" fix hint',
    () async {
      await writeCanonicalSlice();

      final result = await EngineChecker.check(
        entity: 'Login',
        projectRoot: workspace.path,
        feature: '005-login-engine',
        verifyReceipt: true,
      );

      expect(result.passed, isFalse);
      final missing = result.failures
          .where((f) => f.code == EngineFindingCode.missingReceipt)
          .toList();
      expect(missing, hasLength(1));
      expect(missing.first.message, contains('zfa make engine'));
      expect(missing.first.message, contains('--> fix:'));
    },
  );

  test(
    'A10 — an analyze-dirty slice fails with the analyzer message and file',
    () async {
      await writeCanonicalSlice();
      await writeV2Receipt();
      await writeFile('.dart_tool/package_config.json', '{}');

      EngineChecker.analyzeRunnerOverride = (files, workingDirectory) async => (
        exitCode: 2,
        output:
            'Analyzing...\n'
            '  error - lib/src/domain/usecases/login/'
            'get_login_usecase.dart:12:9 - The method \'nope\' '
            "isn't defined for the type 'GetLoginUseCase' - "
            'undefined_method\n',
      );

      final result = await EngineChecker.check(
        entity: 'Login',
        projectRoot: workspace.path,
        feature: '005-login-engine',
        verifyReceipt: true,
        runStaticAnalysis: true,
      );

      expect(result.passed, isFalse);
      final analysis = result.failures
          .where((f) => f.code == EngineFindingCode.staticAnalysis)
          .toList();
      expect(analysis, isNotEmpty);
      expect(
        analysis.first.message,
        contains('get_login_usecase.dart'),
        reason: 'the finding must carry the file',
      );
      expect(
        analysis.first.message,
        contains('nope'),
        reason: 'the finding must carry the analyzer message',
      );
      expect(analysis.first.file, contains('get_login_usecase.dart'));
    },
  );

  test('the analyze leg skips (no failure) when the project has no package '
      'config — fresh workspaces cannot resolve imports', () async {
    await writeCanonicalSlice();
    await writeV2Receipt();

    // Default (real) runner would fail: no .dart_tool. The leg must
    // skip instead of failing the check.
    final result = await EngineChecker.check(
      entity: 'Login',
      projectRoot: workspace.path,
      feature: '005-login-engine',
      verifyReceipt: true,
      runStaticAnalysis: true,
    );

    expect(
      result.failures.where((f) => f.code == EngineFindingCode.staticAnalysis),
      isEmpty,
      reason: 'no package config -> analyze leg skipped, not failed',
    );
    expect(result.analyzedFiles, isEmpty);
    expect(result.passed, isTrue, reason: 'healthy slice, receipt ok');
  });

  test('the receipt leg resolves the receipt by entity scan when no feature '
      'is given', () async {
    await writeCanonicalSlice();
    await writeV2Receipt(feature: 'login-engine');

    final result = await EngineChecker.check(
      entity: 'Login',
      projectRoot: workspace.path,
      verifyReceipt: true,
    );

    expect(
      result.failures.where((f) => f.code == EngineFindingCode.missingReceipt),
      isEmpty,
      reason: 'entity scan must find specs/login-engine/tdd receipt',
    );
    // And the scanned method set feeds mock certification.
    expect(result.mockCertification?.methods.keys, contains('get'));
  });
}
